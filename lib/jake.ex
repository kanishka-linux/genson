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
    map = jschema |> Poison.decode!()
    gen_init(map, map)
  end

  def gen_init(map, omap) do
    map = Jake.Ref.expand_ref(map["$ref"], map, omap)

    if map["allOf"] || map["oneOf"] || map["anyOf"] || map["not"] do
      Jake.Mixed.gen_mixed(map, omap)
    else
      gen_all(map, map["enum"], map["type"], omap)
    end
  end

  def gen_all(map, enum, _type, _omap) when enum != nil, do: gen_enum(map, enum)

  def gen_all(map, _enum, type, omap) when is_list(type) do
    list = for n <- type, do: %{"type" => n}
    nmap = Map.drop(map, ["type"])

    for(n <- list, is_map(n), do: Map.merge(n, nmap) |> Jake.gen_init(omap))
    |> StreamData.one_of()
  end

  def gen_all(map, _enum, type, omap) when type in @types, do: gen_type(type, map, omap)

  def gen_all(map, _enum, type, omap) when type == nil do
    Jake.Notype.gen_notype(map, type, omap)
  end

  def gen_type(type, map, omap) when type == "string" do
    Jake.String.gen_string(map, map["pattern"])
  end

  def gen_type(type, map, omap) when type in ["integer", "number"] do
    Jake.Number.gen_number(map, type, omap)
  end

  def gen_type(type, _map, _omap) when type == "boolean" do
    StreamData.boolean()
  end

  def gen_type(type, _map, _omap) when type == "null" do
    StreamData.constant(nil)
  end

  def gen_type(type, map, omap) when type == "array" do
    Jake.Array.gen_array(map, omap)
  end

  def gen_type(type, map, omap) when type == "object" do
    Jake.Object.gen_object(map, map["properties"], omap)
  end

  def gen_enum(map, list) do
    Enum.filter(list, fn x -> ExJsonSchema.Validator.valid?(map, x) end)
    |> StreamData.member_of()
  end
end
