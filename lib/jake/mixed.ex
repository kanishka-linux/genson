defmodule Jake.Mixed do
  @types [
    "array",
    "boolean",
    "integer",
    "null",
    "number",
    "object",
    "string"
  ]

  def gen_mixed(%{"anyOf" => options} = map, omap, size) when is_list(options) do
    nmap = Map.drop(map, ["anyOf"])

    for(n <- options, is_map(n), do: Jake.gen_init(Map.merge(nmap, n), omap, size))
    |> StreamData.one_of()
  end

  def gen_mixed(%{"oneOf" => options} = map, omap, size) when is_list(options) do
    nmap = Map.drop(map, ["oneOf"])

    tail_schema = fn tail ->
      Enum.reduce(tail, %{}, fn x, acc -> Jake.MapUtil.deep_merge(acc, x) end)
    end

    nlist =
      for {n, counter} <- Enum.with_index(options) do
        hd = Map.merge(nmap, n) |> Jake.gen_init(omap, size)
        tail = List.delete_at(options, counter) |> tail_schema.()
        {hd, tail}
      end

    try_one_of(nlist, 0, size)
  end

  def gen_mixed(%{"allOf" => options} = map, omap, size) when is_list(options) do
    nmap = Map.drop(map, ["allOf"])

    Enum.reduce(options, %{}, fn x, acc -> Jake.MapUtil.deep_merge(acc, x) end)
    |> Jake.MapUtil.deep_merge(nmap)
    |> Jake.gen_init(omap, size)
  end

  def gen_mixed(%{"not" => not_schema} = map, omap, size) when is_map(not_schema) do
    nmap = Map.drop(map, ["not"])
    nmap_type = nmap["type"]
    type_val =
      if not_schema["type"] do
        not_schema["type"]
      else
        Jake.Notype.gen_notype(not_schema, "return type", omap, size)
      end

    type = if type_val == nil, do: "null", else: type_val
    nlist = if is_list(type), do: @types -- type, else: @types -- [type]
    data = 
    if nmap_type || (is_map(nmap) && map_size(nmap) > 0) do
        Jake.gen_init(nmap, omap, size)
    else
        for(n <- nlist, do: Jake.gen_init(%{"type" => n}, omap, size)) |> StreamData.one_of()
    end

    StreamData.filter(data,
      fn x -> 
        if type == "null" do
            true
        else
            not ExJsonSchema.Validator.valid?(not_schema, x)
        end
    end)
  end

  def try_one_of(nlist, index, _size) do
    data = filter_mutually_exclusive(nlist, index)

    try do
      Enum.take(data, 25)
      data
    rescue
      _ -> filter_mutually_exclusive(nlist, index + 1)
    end
  end

  def filter_mutually_exclusive(nlist, index) do
    if index < length(nlist) do
      {head, tail_schema} = Enum.at(nlist, index)
      StreamData.filter(head, fn hd -> not ExJsonSchema.Validator.valid?(tail_schema, hd) end)
    else
      raise "oneOf combination not possible"
    end
  end
end
