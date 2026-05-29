defmodule ReportForge.Identity do
  @moduledoc false

  import Ecto.Query

  alias Ecto.Changeset
  alias Plug.Crypto
  alias ReportForge
  alias ReportForge.Audit
  alias ReportForge.Identity.{ApiKey, Organization}
  alias ReportForge.Observability
  alias ReportForge.Persistence
  alias ReportForge.Repo

  def register_organization(attrs) do
    with {:ok, normalized} <- normalize_organization_attrs(attrs) do
      organization_id = ReportForge.generate_id("org")
      {api_key, token} = ApiKey.issue(organization_id, "bootstrap")

      case Persistence.register_organization_with_bootstrap_key(
             Map.merge(normalized, %{
               id: organization_id,
               api_key: %{
                 id: api_key.id,
                 name: api_key.name,
                 key_prefix: api_key.key_prefix,
                 hashed_secret: api_key.hashed_secret,
                 token_hint: api_key.token_hint,
                 last_used_at: api_key.last_used_at,
                 revoked_at: api_key.revoked_at
               }
             })
           ) do
        {:ok, %{organization: organization, api_key: persisted_api_key}} ->
          Audit.record_best_effort(%{
            actor_type: "self_service",
            actor_id: "anonymous",
            organization_id: organization.id,
            action: "organization.registered",
            resource_type: "organization",
            resource_id: organization.id,
            metadata: %{"organization_slug" => organization.slug}
          })

          Observability.log(:info, "organization_registered", %{
            organization_id: organization.id,
            organization_slug: organization.slug,
            actor: "self_service"
          })

          {:ok,
           %{
             organization: organization,
             api_key: persisted_api_key,
             bootstrap_api_key: token
           }}

        {:error, %Changeset{} = changeset} ->
          translate_registration_error(changeset)
      end
    end
  end

  def authenticate_api_key(token) when is_binary(token) do
    with {:ok, parsed} <- ApiKey.parse_token(token),
         {:ok, api_key, organization} <- lookup_api_key(parsed),
         true <- Crypto.secure_compare(ReportForge.sha256(parsed.secret), api_key.hashed_secret),
         {:ok, touched_key} <- touch_api_key(api_key) do
      {:ok, organization, touched_key}
    else
      false -> {:error, :unauthorized}
      {:error, _reason} -> {:error, :unauthorized}
      _other -> {:error, :unauthorized}
    end
  end

  def list_api_keys(%Organization{id: organization_id}) do
    Repo.all(
      from(api_key in ApiKey,
        where: api_key.organization_id == ^organization_id,
        order_by: [desc: api_key.inserted_at]
      )
    )
  end

  def issue_api_key(%Organization{id: organization_id}, attrs) do
    with {:ok, name} <- normalize_api_key_name(attrs) do
      {api_key, token} = ApiKey.issue(organization_id, name)

      case Repo.insert(api_key) do
        {:ok, persisted_key} ->
          Audit.record_best_effort(%{
            organization_id: organization_id,
            action: "api_key.issued",
            resource_type: "api_key",
            resource_id: persisted_key.id,
            metadata: %{
              "api_key_name" => persisted_key.name,
              "key_prefix" => persisted_key.key_prefix
            }
          })

          Observability.log(:info, "api_key_issued", %{
            organization_id: organization_id,
            api_key_id: persisted_key.id,
            api_key_name: persisted_key.name
          })

          {:ok, %{api_key: persisted_key, token: token}}

        {:error, %Changeset{} = changeset} ->
          {:error, {:validation_failed, translate_changeset_errors(changeset)}}
      end
    end
  end

  def revoke_api_key(%Organization{id: organization_id}, api_key_id) do
    case Repo.get_by(ApiKey, id: api_key_id, organization_id: organization_id) do
      nil ->
        {:error, :not_found}

      %ApiKey{} = api_key ->
        now = ReportForge.utc_now()

        case api_key |> Changeset.change(revoked_at: now, updated_at: now) |> Repo.update() do
          {:ok, revoked_key} ->
            Audit.record_best_effort(%{
              organization_id: organization_id,
              action: "api_key.revoked",
              resource_type: "api_key",
              resource_id: revoked_key.id,
              metadata: %{"api_key_name" => revoked_key.name}
            })

            Observability.log(:warning, "api_key_revoked", %{
              organization_id: organization_id,
              api_key_id: revoked_key.id,
              api_key_name: revoked_key.name
            })

            {:ok, revoked_key}

          {:error, _changeset} ->
            {:error, :not_found}
        end
    end
  end

  defp lookup_api_key(parsed) do
    case Repo.one(
           from(api_key in ApiKey,
             join: organization in assoc(api_key, :organization),
             where: api_key.key_prefix == ^parsed.key_prefix and is_nil(api_key.revoked_at),
             preload: [organization: organization],
             limit: 1
           )
         ) do
      %ApiKey{organization: %Organization{} = organization} = api_key ->
        {:ok, api_key, organization}

      _other ->
        {:error, :unauthorized}
    end
  end

  defp touch_api_key(api_key) do
    now = ReportForge.utc_now()
    api_key |> Changeset.change(last_used_at: now, updated_at: now) |> Repo.update()
  end

  defp translate_registration_error(%Changeset{} = changeset) do
    if unique_error?(changeset, :slug) do
      {:error, {:conflict, "organization slug already exists"}}
    else
      {:error, {:validation_failed, translate_changeset_errors(changeset)}}
    end
  end

  defp unique_error?(%Changeset{errors: errors}, field) do
    Enum.any?(errors, fn
      {^field, {"has already been taken", _opts}} -> true
      _other -> false
    end)
  end

  defp translate_changeset_errors(changeset) do
    Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.flat_map(fn {field, messages} ->
      Enum.map(messages, fn message ->
        %{field: to_string(field), issue: message}
      end)
    end)
  end

  defp normalize_organization_attrs(attrs) when is_map(attrs) do
    name = read_string(attrs, "name")
    slug = read_string(attrs, "slug")
    retention_days = read_integer(attrs, "retention_days", 30)

    details =
      []
      |> maybe_add_error(
        is_nil(name) or byte_size(name) < 3,
        "name",
        "must contain at least 3 characters"
      )
      |> maybe_add_error(
        is_nil(slug) or not Regex.match?(~r/^[a-z0-9-]+$/, slug || ""),
        "slug",
        "must contain lowercase letters, numbers, and hyphens only"
      )
      |> maybe_add_error(
        retention_days < 1 or retention_days > 365,
        "retention_days",
        "must be between 1 and 365 days"
      )

    if details == [] do
      {:ok, %{name: name, slug: slug, retention_days: retention_days}}
    else
      {:error, {:validation_failed, details}}
    end
  end

  defp normalize_organization_attrs(_attrs),
    do: {:error, {:validation_failed, [%{field: "organization", issue: "must be an object"}]}}

  defp normalize_api_key_name(attrs) when is_map(attrs) do
    name = read_string(attrs, "name")

    if is_binary(name) and byte_size(name) >= 3 do
      {:ok, name}
    else
      {:error,
       {:validation_failed, [%{field: "name", issue: "must contain at least 3 characters"}]}}
    end
  end

  defp normalize_api_key_name(_attrs) do
    {:error, {:validation_failed, [%{field: "api_key", issue: "must be an object"}]}}
  end

  defp read_string(attrs, key) do
    case read_value(attrs, key) do
      value when is_binary(value) ->
        value
        |> String.trim()
        |> case do
          "" -> nil
          trimmed -> trimmed
        end

      _other ->
        nil
    end
  end

  defp read_integer(attrs, key, default) do
    case read_value(attrs, key) do
      value when is_integer(value) ->
        value

      value when is_binary(value) ->
        case Integer.parse(value) do
          {parsed, ""} -> parsed
          _other -> default
        end

      nil ->
        default

      _other ->
        default
    end
  end

  defp read_value(attrs, "name"), do: Map.get(attrs, "name") || Map.get(attrs, :name)
  defp read_value(attrs, "slug"), do: Map.get(attrs, "slug") || Map.get(attrs, :slug)

  defp read_value(attrs, "retention_days"),
    do: Map.get(attrs, "retention_days") || Map.get(attrs, :retention_days)

  defp read_value(_attrs, _key), do: nil

  defp maybe_add_error(details, false, _field, _issue), do: details

  defp maybe_add_error(details, true, field, issue),
    do: details ++ [%{field: field, issue: issue}]
end
