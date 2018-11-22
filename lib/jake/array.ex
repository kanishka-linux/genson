defmodule Jake.Array do
  @type_list [
    %{"type" => "integer"},
    %{"type" => "number"},
    %{"type" => "boolean"},
    %{"type" => "string"},
    %{"type" => "null"},
    nil
  ]

  @min_items 0

  @max_items 1000

  def gen_array(%{"items" => items} = map, omap) do
    case items do
      item when is_map(item) ->
        gen_list(map, item, omap)

      item when is_list(item) ->
        gen_tuple(map, item, omap)

      _ ->
        raise "Invalid items in array"
    end
  end

  def gen_array(map, omap), do: arraytype(map, map["items"], omap)

  def arraytype(map, items, omap) when is_nil(items) do
    item = get_one_of(omap)
    {min, max} = get_min_max(map)
    decide_min_max(map, item, min, max)
  end

  def gen_tuple(map, items, omap) do
    list = for n <- items, is_map(n), do: Jake.gen_init(n, omap)

    {min, max} = get_min_max(map)

    case map["additionalItems"] do
      x when is_map(x) ->
        add_additional_items(list, Jake.gen_init(x, omap), max, min)

      x when (is_boolean(x) and x) or is_nil(x) ->
        add_additional_items(list, get_one_of(omap), max, min)

      x when is_boolean(x) and not x and length(list) in min..max ->
        StreamData.fixed_list(list)

      _ ->
        raise "Invalid items or length of list exceeds specified bounds"
    end
  end

  def gen_list(map, items, omap) do
    {min, max} = get_min_max(map)
    item = Jake.gen_init(items, omap)
    decide_min_max(map, item, min, max)
  end

  def get_min_max(map) do
    min = Map.get(map, "minItems", @min_items)
    max = Map.get(map, "maxItems", @max_items)
    {min, max}
  end

  def decide_min_max(map, item, min, max)
      when is_integer(min) and is_integer(max) and min < max do
    if map["uniqueItems"] do
      StreamData.uniq_list_of(item, min_length: min, max_length: max)
    else
      StreamData.list_of(item, min_length: min, max_length: max)
    end
  end

  def decide_min_max(map, item, min, max) do
    raise "Bounds of items not well defined"
  end

  def get_one_of(omap) do
    for(n <- @type_list, is_map(n), do: Jake.gen_init(n, omap)) |> StreamData.one_of()
  end

  def add_additional_items(olist, additional, max, min) do
    StreamData.bind(StreamData.fixed_list(olist), fn list ->
      StreamData.bind_filter(
        StreamData.list_of(additional),
        fn
          nlist
          when (length(list) + length(nlist)) in min..max ->
            {:cont, StreamData.constant(list ++ nlist)}

          nlist
          when length(list) in min..max ->
            {:cont, StreamData.constant(list)}

          _ ->
            :skip
        end
      )
    end)
  end
end
