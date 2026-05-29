defmodule ReportForge do
  @moduledoc """
  Shared helpers for ID generation, hashing, and serialization.
  """

  def generate_id(prefix) when is_binary(prefix) do
    entropy =
      :crypto.strong_rand_bytes(8)
      |> Base.encode16(case: :lower)

    "#{prefix}_#{entropy}"
  end

  def utc_now do
    DateTime.utc_now() |> DateTime.truncate(:microsecond)
  end

  def to_iso8601(nil), do: nil
  def to_iso8601(%DateTime{} = value), do: DateTime.to_iso8601(value)

  def sha256(value) when is_binary(value) do
    :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
  end

  def sha256(value) do
    value |> stable_json() |> sha256()
  end

  def stable_json(value) do
    value |> normalize_term() |> Jason.encode!()
  end

  def normalize_term(%{} = value) do
    value
    |> Enum.map(fn {key, nested} -> {to_string(key), normalize_term(nested)} end)
    |> Enum.sort_by(fn {key, _value} -> key end)
    |> Enum.into(%{})
  end

  def normalize_term(list) when is_list(list), do: Enum.map(list, &normalize_term/1)
  def normalize_term(value), do: value
end
