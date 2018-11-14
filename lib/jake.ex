defmodule Jake do
  @types [
    "array",
    "boolean",
    "integer",
    "null",
    "number",
    "object",
    "string"
  ]

  def generator(jschema) do
    IO.puts(jschema)
    jschema |> Poison.decode!() |> gen_init()
  end

  def gen_init(%{"anyOf" => options} = map) when is_list(options) do
    nmap = Map.drop(map, ["anyOf"])

    for(n <- options, is_map(n), do: Jake.gen_init(Map.merge(nmap, n)))
    |> StreamData.one_of()
  end

  def gen_init(%{"allOf" => options} = map) when is_list(options) do
    nmap = Map.drop(map, ["allOf"])

    Enum.reduce(options, %{}, fn x, acc -> Jake.MapUtil.deep_merge(acc, x) end)
    |> Map.merge(nmap)
    |> Jake.gen_init()
  end

  def gen_init(map) do
    gen_all(map, map["enum"], map["type"])
  end

  def gen_all(map, enum, type) when is_list(type) do
    list = for n <- type, do: %{"type" => n}
    nmap = Map.drop(map, ["type"])
    for(n <- list, is_map(n), do: Map.merge(n, nmap) |> Jake.gen_init()) |> StreamData.one_of()
  end

  def gen_all(map, enum, type) when type in @types, do: gen_type(type, map)

  def gen_all(map, enum, type) when enum != nil, do: gen_enum(enum, type)

  def gen_all(map, enum, type) when type == nil do
    Jake.Notype.gen_notype(map, type)
  end

  def gen_type(type, map) when type == "string" do
    Jake.String.gen_string(map)
  end

  def gen_type(type, map) when type in ["integer", "number"] do
    Jake.Number.gen_number(map, type)
  end

  def gen_type(type, map) when type == "boolean" do
    StreamData.boolean()
  end

  def gen_type(type, map) when type == "null" do
    StreamData.constant(nil)
  end

  def gen_type(type, map) when type == "array" do
    Jake.Array.gen_array(map, type)
  end

  def gen_type(type, map) when type == "object" do
    Jake.Object.gen_object(map, type)
  end

  def gen_enum(list, type) do
    nlist =
      case type do
        x when x == "integer" ->
          nlist = for n <- list, is_integer(n), do: n

        x when x == "number" ->
          for n <- list, is_number(n), do: n

        x when x == "string" ->
          for n <- list, is_binary(n), do: n

        x when x == "array" ->
          for n <- list, is_list(n), do: n

        x when x == "object" ->
          for n <- list, is_map(n), do: n

        _ ->
          list
      end

    StreamData.member_of(nlist)
  end
end
