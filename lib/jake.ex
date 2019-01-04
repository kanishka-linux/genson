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
    StreamData.sized(fn size -> gen_init(map, map, 2 * size) end)
  end

  def gen_init(map, omap, size) do
    StreamData.bind(
      get_lazy_streamkey(map, omap, size),
      fn {nmap, nsize} ->
        if nmap["allOf"] || nmap["oneOf"] || nmap["anyOf"] || nmap["not"] do
          Jake.Mixed.gen_mixed(nmap, omap, nsize)
        else
          gen_all(nmap, nmap["enum"], nmap["type"], omap, nsize)
        end
        |> StreamData.resize(nsize)
      end
    )
  end

  def get_lazy_streamkey(map, omap, size) do
    if size == 0 do
      map = Jake.Ref.expand_ref(map["$ref"], map, omap, true)
      {map, 0}
    else
      map = Jake.Ref.expand_ref(map["$ref"], map, omap, false)
      {map, trunc(size / 2)}
    end
    |> StreamData.constant()
  end

  def gen_all(map, enum, _type, _omap, _size) when enum != nil, do: gen_enum(map, enum)

  def gen_all(map, _enum, type, omap, size) when is_list(type) do
    list = for n <- type, do: %{"type" => n}
    nmap = Map.drop(map, ["type"])

    for(n <- list, is_map(n), do: Map.merge(n, nmap) |> Jake.gen_init(omap, size))
    |> StreamData.one_of()
  end

  def gen_all(map, _enum, type, omap, size) when type in @types,
    do: gen_type(type, map, omap, size)

  def gen_all(map, _enum, type, omap, size) when type == nil do
    Jake.Notype.gen_notype(map, type, omap, size)
  end

  def gen_type(type, map, omap, size) when type == "string" do
    Jake.String.gen_string(map, map["pattern"], size)
  end

  def gen_type(type, map, omap, size) when type in ["integer", "number"] do
    Jake.Number.gen_number(map, type, omap, size)
  end

  def gen_type(type, _map, _omap, _size) when type == "boolean" do
    StreamData.boolean()
  end

  def gen_type(type, _map, _omap, _size) when type == "null" do
    StreamData.constant(nil)
  end

  def gen_type(type, map, omap, size) when type == "array" do
    Jake.Array.gen_array(map, omap, size)
  end

  def gen_type(type, map, omap, size) when type == "object" do
    Jake.Object.gen_object(map, map["properties"], omap, size)
  end

  def gen_enum(map, list) do
    Enum.filter(list, fn x -> ExJsonSchema.Validator.valid?(map, x) end)
    |> StreamData.member_of()
  end
end
