defmodule ReportForge.OpenApiContract do
  @moduledoc false

  import ExUnit.Assertions

  @repo_root Path.expand("../..", __DIR__)

  def assert_response!(conn, method, path_template) do
    contract = contract()
    schema = response_schema!(contract, method, path_template, conn.status)
    payload = Jason.decode!(conn.resp_body)
    errors = validate(schema, payload, contract, "$")

    assert errors == [],
           "response for #{method} #{path_template} #{conn.status} violates OpenAPI schema:\n" <>
             Enum.join(errors, "\n")
  end

  def assert_operation_has_4xx!(method, path_template) do
    responses =
      contract()
      |> get_in(["paths", path_template, method, "responses"])

    assert is_map(responses), "missing OpenAPI responses for #{method} #{path_template}"

    assert Enum.any?(Map.keys(responses), &String.starts_with?(&1, "4")),
           "operation #{method} #{path_template} must declare at least one 4XX response"
  end

  defp contract do
    @repo_root
    |> Path.join("openapi.yaml")
    |> String.to_charlist()
    |> :yamerl_constr.file()
    |> hd()
    |> normalize_yaml()
  end

  defp response_schema!(contract, method, path_template, status) do
    response =
      contract
      |> get_in(["paths", path_template, method, "responses", Integer.to_string(status)])
      |> resolve_ref(contract)

    assert is_map(response), "missing OpenAPI response for #{method} #{path_template} #{status}"

    response
    |> get_in(["content", "application/json", "schema"])
    |> then(fn schema ->
      assert is_map(schema),
             "missing application/json schema for #{method} #{path_template} #{status}"

      schema
    end)
  end

  defp validate(%{"$ref" => _ref} = schema, value, contract, path) do
    schema |> resolve_ref(contract) |> validate(value, contract, path)
  end

  defp validate(%{"nullable" => true}, nil, _contract, _path), do: []

  defp validate(%{"enum" => values} = schema, value, contract, path) do
    enum_errors =
      if value in values do
        []
      else
        ["#{path} expected one of #{inspect(values)}, got #{inspect(value)}"]
      end

    enum_errors ++ validate(Map.delete(schema, "enum"), value, contract, path)
  end

  defp validate(%{"type" => "object"} = schema, value, contract, path) when is_map(value) do
    required_errors =
      schema
      |> Map.get("required", [])
      |> Enum.reject(&Map.has_key?(value, &1))
      |> Enum.map(&"#{path} missing required property #{&1}")

    property_errors =
      schema
      |> Map.get("properties", %{})
      |> Enum.flat_map(fn {property, property_schema} ->
        if Map.has_key?(value, property) do
          validate(property_schema, Map.fetch!(value, property), contract, "#{path}.#{property}")
        else
          []
        end
      end)

    required_errors ++
      property_errors ++ validate_additional_properties(schema, value, contract, path)
  end

  defp validate(%{"type" => "object"}, value, _contract, path) do
    ["#{path} expected object, got #{type_name(value)}"]
  end

  defp validate(%{"type" => "array", "items" => item_schema}, value, contract, path)
       when is_list(value) do
    value
    |> Enum.with_index()
    |> Enum.flat_map(fn {item, index} ->
      validate(item_schema, item, contract, "#{path}[#{index}]")
    end)
  end

  defp validate(%{"type" => "array"}, value, _contract, path) do
    ["#{path} expected array, got #{type_name(value)}"]
  end

  defp validate(%{"type" => "string"}, value, _contract, _path) when is_binary(value), do: []
  defp validate(%{"type" => "integer"}, value, _contract, _path) when is_integer(value), do: []
  defp validate(%{"type" => "boolean"}, value, _contract, _path) when is_boolean(value), do: []
  defp validate(%{"type" => "number"}, value, _contract, _path) when is_number(value), do: []

  defp validate(%{"type" => type}, value, _contract, path) do
    ["#{path} expected #{type}, got #{type_name(value)}"]
  end

  defp validate(%{"properties" => _properties} = schema, value, contract, path) do
    validate(Map.put(schema, "type", "object"), value, contract, path)
  end

  defp validate(_schema, _value, _contract, _path), do: []

  defp validate_additional_properties(
         %{"additionalProperties" => additional_schema, "properties" => properties},
         value,
         contract,
         path
       )
       when is_map(additional_schema) do
    value
    |> Map.drop(Map.keys(properties))
    |> Enum.flat_map(fn {property, property_value} ->
      validate(additional_schema, property_value, contract, "#{path}.#{property}")
    end)
  end

  defp validate_additional_properties(
         %{"additionalProperties" => false, "properties" => properties},
         value,
         _contract,
         path
       ) do
    value
    |> Map.drop(Map.keys(properties))
    |> Map.keys()
    |> Enum.map(&"#{path} includes unexpected property #{&1}")
  end

  defp validate_additional_properties(_schema, _value, _contract, _path), do: []

  defp resolve_ref(%{"$ref" => "#/" <> path}, contract) do
    path
    |> String.split("/")
    |> Enum.reduce(contract, fn segment, current -> Map.fetch!(current, segment) end)
    |> resolve_ref(contract)
  end

  defp resolve_ref(value, _contract), do: value

  defp normalize_yaml(value) when is_list(value) do
    cond do
      charlist?(value) ->
        to_string(value)

      Enum.all?(value, &yaml_pair?/1) ->
        Map.new(value, fn {key, item} -> {normalize_yaml(key), normalize_yaml(item)} end)

      true ->
        Enum.map(value, &normalize_yaml/1)
    end
  end

  defp normalize_yaml(value), do: value

  defp charlist?([]), do: false
  defp charlist?(value), do: Enum.all?(value, &is_integer/1)
  defp yaml_pair?({_key, _value}), do: true
  defp yaml_pair?(_value), do: false

  defp type_name(value) when is_binary(value), do: "string"
  defp type_name(value) when is_integer(value), do: "integer"
  defp type_name(value) when is_float(value), do: "number"
  defp type_name(value) when is_boolean(value), do: "boolean"
  defp type_name(value) when is_list(value), do: "array"
  defp type_name(value) when is_map(value), do: "object"
  defp type_name(nil), do: "null"
end
