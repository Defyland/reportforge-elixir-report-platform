defmodule ReportForge.Identity.ApiKey do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias ReportForge
  alias ReportForge.Identity.Organization

  @primary_key {:id, :string, autogenerate: false}
  @foreign_key_type :string

  schema "api_keys" do
    field(:name, :string)
    field(:key_prefix, :string)
    field(:hashed_secret, :string)
    field(:token_hint, :string)
    field(:last_used_at, :utc_datetime_usec)
    field(:revoked_at, :utc_datetime_usec)

    belongs_to(:organization, Organization)

    timestamps(type: :utc_datetime_usec)
  end

  def issue(organization_id, name) do
    key_prefix =
      :crypto.strong_rand_bytes(4)
      |> Base.encode16(case: :lower)

    secret =
      :crypto.strong_rand_bytes(18)
      |> Base.url_encode64(padding: false)

    token = "rfk_#{key_prefix}.#{secret}"
    now = ReportForge.utc_now()

    api_key = %__MODULE__{
      id: ReportForge.generate_id("key"),
      organization_id: organization_id,
      name: name,
      key_prefix: key_prefix,
      hashed_secret: ReportForge.sha256(secret),
      token_hint: String.slice(secret, -4, 4),
      inserted_at: now,
      updated_at: now
    }

    {api_key, token}
  end

  def changeset(api_key, attrs) do
    api_key
    |> cast(attrs, [
      :id,
      :organization_id,
      :name,
      :key_prefix,
      :hashed_secret,
      :token_hint,
      :last_used_at,
      :revoked_at
    ])
    |> validate_required([:id, :organization_id, :name, :key_prefix, :hashed_secret, :token_hint])
    |> validate_length(:name, min: 3)
    |> unique_constraint(:key_prefix)
    |> foreign_key_constraint(:organization_id)
  end

  def parse_token("rfk_" <> remainder) do
    case String.split(remainder, ".", parts: 2) do
      [key_prefix, secret] when byte_size(secret) >= 16 ->
        {:ok, %{key_prefix: key_prefix, secret: secret}}

      _other ->
        {:error, :invalid_api_key}
    end
  end

  def parse_token(_token), do: {:error, :invalid_api_key}
end
