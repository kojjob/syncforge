defmodule SyncforgeWeb.OrganizationController do
  use SyncforgeWeb, :controller

  alias Syncforge.Organizations

  # --- Organization CRUD ---

  def create(conn, %{"organization" => org_params}) do
    user = conn.assigns.current_user

    case Organizations.create_organization(user, org_params) do
      {:ok, org, _membership} ->
        conn
        |> put_status(:created)
        |> put_view(SyncforgeWeb.OrganizationJSON)
        |> render("organization.json", organization: org)

      {:error, :organization, changeset, _} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(SyncforgeWeb.OrganizationJSON)
        |> render("error.json", changeset: changeset)
    end
  end

  def index(conn, _params) do
    user = conn.assigns.current_user
    orgs = Organizations.list_user_organizations(user.id)

    conn
    |> put_view(SyncforgeWeb.OrganizationJSON)
    |> render("organizations.json", organizations: orgs)
  end

  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with org when not is_nil(org) <- Organizations.get_organization(id),
         true <- Organizations.user_has_role?(id, user.id, ["owner", "admin", "member", "viewer"]) do
      conn
      |> put_view(SyncforgeWeb.OrganizationJSON)
      |> render("organization.json", organization: org)
    else
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Organization not found"})

      false ->
        conn |> put_status(:forbidden) |> json(%{error: "Not a member of this organization"})
    end
  end

  def update(conn, %{"id" => id, "organization" => org_params}) do
    user = conn.assigns.current_user

    with org when not is_nil(org) <- Organizations.get_organization(id),
         true <- Organizations.user_has_role?(id, user.id, ["owner", "admin"]) do
      case Organizations.update_organization(org, org_params) do
        {:ok, updated} ->
          conn
          |> put_view(SyncforgeWeb.OrganizationJSON)
          |> render("organization.json", organization: updated)

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> put_view(SyncforgeWeb.OrganizationJSON)
          |> render("error.json", changeset: changeset)
      end
    else
      nil -> conn |> put_status(:not_found) |> json(%{error: "Organization not found"})
      false -> conn |> put_status(:forbidden) |> json(%{error: "Insufficient permissions"})
    end
  end

  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with org when not is_nil(org) <- Organizations.get_organization(id),
         true <- Organizations.user_has_role?(id, user.id, ["owner"]) do
      {:ok, _} = Organizations.delete_organization(org)
      send_resp(conn, :no_content, "")
    else
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Organization not found"})

      false ->
        conn |> put_status(:forbidden) |> json(%{error: "Only owners can delete organizations"})
    end
  end

  # --- Membership Management ---

  def add_member(conn, %{"organization_id" => org_id, "user_id" => user_id, "role" => role}) do
    current_user = conn.assigns.current_user

    with org when not is_nil(org) <- Organizations.get_organization(org_id),
         true <- Organizations.user_has_role?(org_id, current_user.id, ["owner", "admin"]) do
      case Organizations.add_member(org, user_id, role) do
        {:ok, membership} ->
          conn
          |> put_status(:created)
          |> put_view(SyncforgeWeb.OrganizationJSON)
          |> render("membership.json", membership: membership)

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> put_view(SyncforgeWeb.OrganizationJSON)
          |> render("error.json", changeset: changeset)
      end
    else
      nil -> conn |> put_status(:not_found) |> json(%{error: "Organization not found"})
      false -> conn |> put_status(:forbidden) |> json(%{error: "Insufficient permissions"})
    end
  end

  def remove_member(conn, %{"organization_id" => org_id, "user_id" => user_id}) do
    current_user = conn.assigns.current_user

    with org when not is_nil(org) <- Organizations.get_organization(org_id),
         true <- Organizations.user_has_role?(org_id, current_user.id, ["owner", "admin"]) do
      case Organizations.remove_member(org, user_id) do
        {:ok, _} ->
          send_resp(conn, :no_content, "")

        {:error, :not_found} ->
          conn |> put_status(:not_found) |> json(%{error: "Member not found"})

        {:error, :last_owner} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "Cannot remove the last owner"})
      end
    else
      nil -> conn |> put_status(:not_found) |> json(%{error: "Organization not found"})
      false -> conn |> put_status(:forbidden) |> json(%{error: "Insufficient permissions"})
    end
  end

  def update_member_role(conn, %{
        "organization_id" => org_id,
        "user_id" => user_id,
        "role" => role
      }) do
    current_user = conn.assigns.current_user

    with org when not is_nil(org) <- Organizations.get_organization(org_id),
         true <- Organizations.user_has_role?(org_id, current_user.id, ["owner", "admin"]) do
      case Organizations.update_member_role(org, user_id, role) do
        {:ok, membership} ->
          conn
          |> put_view(SyncforgeWeb.OrganizationJSON)
          |> render("membership.json", membership: membership)

        {:error, :not_found} ->
          conn |> put_status(:not_found) |> json(%{error: "Member not found"})

        {:error, :last_owner} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "Cannot demote the last owner"})

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> put_view(SyncforgeWeb.OrganizationJSON)
          |> render("error.json", changeset: changeset)
      end
    else
      nil -> conn |> put_status(:not_found) |> json(%{error: "Organization not found"})
      false -> conn |> put_status(:forbidden) |> json(%{error: "Insufficient permissions"})
    end
  end

  # --- API Key Management ---

  def create_api_key(conn, %{"organization_id" => org_id} = params) do
    current_user = conn.assigns.current_user

    with org when not is_nil(org) <- Organizations.get_organization(org_id),
         true <- Organizations.user_has_role?(org_id, current_user.id, ["owner", "admin"]) do
      key_attrs =
        params
        |> Map.take(["label", "type", "scopes", "rate_limit", "allowed_origins"])
        |> Map.new(fn {k, v} -> {String.to_existing_atom(k), v} end)

      case Organizations.create_api_key(org, key_attrs) do
        {:ok, api_key, raw_key} ->
          conn
          |> put_status(:created)
          |> put_view(SyncforgeWeb.OrganizationJSON)
          |> render("api_key.json", api_key: api_key, raw_key: raw_key)

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> put_view(SyncforgeWeb.OrganizationJSON)
          |> render("error.json", changeset: changeset)
      end
    else
      nil -> conn |> put_status(:not_found) |> json(%{error: "Organization not found"})
      false -> conn |> put_status(:forbidden) |> json(%{error: "Insufficient permissions"})
    end
  end

  def list_api_keys(conn, %{"organization_id" => org_id}) do
    current_user = conn.assigns.current_user

    with org when not is_nil(org) <- Organizations.get_organization(org_id),
         true <-
           Organizations.user_has_role?(org_id, current_user.id, [
             "owner",
             "admin",
             "member",
             "viewer"
           ]) do
      keys = Organizations.list_api_keys(org.id)

      conn
      |> put_view(SyncforgeWeb.OrganizationJSON)
      |> render("api_keys.json", api_keys: keys)
    else
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Organization not found"})

      false ->
        conn |> put_status(:forbidden) |> json(%{error: "Not a member of this organization"})
    end
  end

  def rotate_api_key(conn, %{"organization_id" => org_id, "id" => key_id}) do
    current_user = conn.assigns.current_user

    with org when not is_nil(org) <- Organizations.get_organization(org_id),
         true <- Organizations.user_has_role?(org_id, current_user.id, ["owner", "admin"]) do
      case Organizations.rotate_api_key(org, key_id) do
        {:ok, new_key, raw_key, _rotated_old} ->
          conn
          |> put_view(SyncforgeWeb.OrganizationJSON)
          |> render("api_key.json", api_key: new_key, raw_key: raw_key)

        {:error, :key_not_found} ->
          conn |> put_status(:not_found) |> json(%{error: "API key not found"})

        {:error, :key_not_active} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "Only active keys can be rotated (key is not active)"})

        {:error, _other} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "Failed to rotate API key"})
      end
    else
      nil -> conn |> put_status(:not_found) |> json(%{error: "Organization not found"})
      false -> conn |> put_status(:forbidden) |> json(%{error: "Insufficient permissions"})
    end
  end

  def revoke_api_key(conn, %{"organization_id" => org_id, "id" => key_id}) do
    current_user = conn.assigns.current_user

    with org when not is_nil(org) <- Organizations.get_organization(org_id),
         true <- Organizations.user_has_role?(org_id, current_user.id, ["owner", "admin"]) do
      api_key = Syncforge.Repo.get(Syncforge.Accounts.ApiKey, key_id)

      cond do
        is_nil(api_key) ->
          conn |> put_status(:not_found) |> json(%{error: "API key not found"})

        api_key.organization_id != org.id ->
          conn |> put_status(:not_found) |> json(%{error: "API key not found"})

        true ->
          {:ok, revoked} = Organizations.revoke_api_key(api_key)

          conn
          |> put_view(SyncforgeWeb.OrganizationJSON)
          |> render("api_key.json", api_key: revoked)
      end
    else
      nil -> conn |> put_status(:not_found) |> json(%{error: "Organization not found"})
      false -> conn |> put_status(:forbidden) |> json(%{error: "Insufficient permissions"})
    end
  end
end
