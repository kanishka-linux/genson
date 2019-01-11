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

    StreamData.sized(fn size ->
      Map.put(%{}, "map", map) |> Map.put("omap", map) |> Map.put("size", 2 * size) |> gen_init()
    end)
  end

  def gen_init(schema) do
    StreamData.bind(
      get_lazy_streamkey(schema),
      fn {nmap, nsize} ->
        nschema = Map.put(schema, "map", nmap) |> Map.put("size", nsize)

        if nmap["allOf"] || nmap["oneOf"] || nmap["anyOf"] || nmap["not"] do
          Jake.Mixed.gen_mixed(nmap, nschema)
        else
          gen_all(nschema, nmap["enum"], nmap["type"])
        end
        |> StreamData.resize(nsize)
      end
    )
  end

  def get_lazy_streamkey(schema) do
    {map, _} =
      get_in(schema, ["map", "$ref"]) |> Jake.Ref.expand_ref(schema["map"], schema["omap"])

    StreamData.constant({map, trunc(schema["size"] / 2)})
  end

  def gen_all(schema, enum, _type) when enum != nil, do: gen_enum(schema["map"], enum)

  def gen_all(schema, _enum, type) when is_list(type) do
    list = for n <- type, do: %{"type" => n}
    nmap = schema["map"] |> Map.drop(["type"])

    for(n <- list, is_map(n), do: Map.put(schema, "map", Map.merge(n, nmap)) |> Jake.gen_init())
    |> StreamData.one_of()
  end

  def gen_all(schema, _enum, type) when type in @types,
    do: gen_type(type, schema)

  def gen_all(schema, _enum, type) when type == nil do
    Jake.Notype.gen_notype(type, schema)
  end

  def gen_type(type, schema) when type == "string" do
    map = schema["map"]
    Jake.String.gen_string(map, map["pattern"])
  end

  def gen_type(type, schema) when type in ["integer", "number"] do
    Jake.Number.gen_number(schema["map"], type)
  end

  def gen_type(type, schema) when type == "boolean" do
    StreamData.boolean()
  end

  def gen_type(type, schema) when type == "null" do
    StreamData.constant(nil)
  end

  def gen_type(type, schema) when type == "array" do
    Jake.Array.gen_array(schema["map"], schema)
  end

  def gen_type(type, schema) when type == "object" do
    map = schema["map"]
    Jake.Object.gen_object(map, map["properties"], schema)
  end

  def gen_enum(map, list) do
    Enum.filter(list, fn x -> ExJsonSchema.Validator.valid?(map, x) end)
    |> StreamData.member_of()
  end
end
