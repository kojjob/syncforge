defmodule SyncforgeWeb.OrganizationJSON do
  alias Syncforge.Accounts.{Organization, Membership, ApiKey}

  def render("organization.json", %{organization: org}) do
    %{organization: organization_data(org)}
  end

  def render("organizations.json", %{organizations: orgs}) do
    %{organizations: Enum.map(orgs, &organization_data/1)}
  end

  def render("membership.json", %{membership: membership}) do
    %{membership: membership_data(membership)}
  end

  def render("api_key.json", %{api_key: api_key, raw_key: raw_key}) do
    %{api_key: api_key_data(api_key) |> Map.put(:raw_key, raw_key)}
  end

  def render("api_key.json", %{api_key: api_key}) do
    %{api_key: api_key_data(api_key)}
  end

  def render("api_keys.json", %{api_keys: api_keys}) do
    %{api_keys: Enum.map(api_keys, &api_key_data/1)}
  end

  def render("message.json", %{message: message}) do
    %{message: message}
  end

  def render("error.json", %{changeset: changeset}) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
          opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
        end)
      end)

    %{errors: errors}
  end

  defp organization_data(%Organization{} = org) do
    %{
      id: org.id,
      name: org.name,
      slug: org.slug,
      logo_url: org.logo_url,
      plan_type: org.plan_type,
      max_rooms: org.max_rooms,
      max_monthly_connections: org.max_monthly_connections,
      settings: org.settings,
      inserted_at: org.inserted_at
    }
  end

  defp membership_data(%Membership{} = m) do
    %{
      id: m.id,
      user_id: m.user_id,
      organization_id: m.organization_id,
      role: m.role,
      status: m.status,
      inserted_at: m.inserted_at
    }
  end

  defp api_key_data(%ApiKey{} = k) do
    %{
      id: k.id,
      label: k.label,
      key_prefix: k.key_prefix,
      type: k.type,
      status: k.status,
      scopes: k.scopes,
      rate_limit: k.rate_limit,
      organization_id: k.organization_id,
      inserted_at: k.inserted_at
    }
  end
end
