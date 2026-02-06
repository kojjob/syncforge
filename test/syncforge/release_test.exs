defmodule Syncforge.ReleaseTest do
  use ExUnit.Case, async: true

  alias Syncforge.Release

  setup_all do
    Code.ensure_loaded!(Release)
    :ok
  end

  describe "migrate/0" do
    test "migrate function is defined and callable" do
      # We can't actually run migrate in tests (it would re-migrate the test DB),
      # but we verify the function exists and accepts no args.
      assert function_exported?(Release, :migrate, 0)
    end
  end

  describe "rollback/2" do
    test "rollback function is defined and callable" do
      assert function_exported?(Release, :rollback, 2)
    end
  end
end
