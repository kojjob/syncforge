defmodule Syncforge.RoomsDashboardTest do
  use Syncforge.DataCase, async: true

  alias Syncforge.Rooms

  import Syncforge.AccountsFixtures

  describe "list_rooms_for_organization/1" do
    test "returns rooms belonging to the organization" do
      owner = user_fixture()

      {:ok, org, _} =
        Syncforge.Organizations.create_organization(owner, %{name: "Room Org"})

      {:ok, room1} = Rooms.create_room(%{name: "Room A", organization_id: org.id})
      {:ok, room2} = Rooms.create_room(%{name: "Room B", organization_id: org.id})
      {:ok, _other} = Rooms.create_room(%{name: "Other Room"})

      rooms = Rooms.list_rooms_for_organization(org.id)

      ids = Enum.map(rooms, & &1.id) |> MapSet.new()
      assert MapSet.member?(ids, room1.id)
      assert MapSet.member?(ids, room2.id)
      assert length(rooms) == 2
    end

    test "returns empty list for org with no rooms" do
      assert Rooms.list_rooms_for_organization(Ecto.UUID.generate()) == []
    end
  end

  describe "count_rooms_for_organization/1" do
    test "counts rooms in an organization" do
      owner = user_fixture()

      {:ok, org, _} =
        Syncforge.Organizations.create_organization(owner, %{name: "Count Room Org"})

      {:ok, _} = Rooms.create_room(%{name: "R1", organization_id: org.id})
      {:ok, _} = Rooms.create_room(%{name: "R2", organization_id: org.id})
      {:ok, _} = Rooms.create_room(%{name: "R3", organization_id: org.id})

      assert Rooms.count_rooms_for_organization(org.id) == 3
    end

    test "returns 0 for org with no rooms" do
      assert Rooms.count_rooms_for_organization(Ecto.UUID.generate()) == 0
    end
  end
end
