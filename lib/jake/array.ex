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

  def gen_array(map, type), do: arraytype(map, map["enum"], map["items"])

  def arraytype(map, enum, items) when enum != nil, do: Jake.gen_enum(enum, "array")

  def arraytype(map, enum, items) when is_list(items) or is_map(items) do
    list =
      if is_list(items) do
        for n <- items, is_map(n), do: Jake.gen_init(n)
      else
        [Jake.gen_init(items)]
      end

    {min, max} = get_min_max(map)

    case map["additionalItems"] do
      x when (is_boolean(x) and x) or is_nil(x) ->
        add_additional_items(list, true, max, min)

      x when is_map(x) ->
        add_additional_items(list, x, max, min)

      _ ->
        add_additional_items(list, false, max, min)
    end
  end

  def get_min_max(map) do
    min = Map.get(map, "minItems", @min_items)
    max = Map.get(map, "maxItems", @max_items)
    {min, max}
  end

  def arraytype(map, enum, items) when is_nil(items) and is_nil(enum) do
    item = get_one_of()
    {min, max} = get_min_max(map)
    decide_min_max(map, item, min, max)
  end

  def decide_min_max(map, item, min, max)
      when is_integer(min) and is_integer(max) and min < max do
    if map["uniqueItems"] do
      StreamData.uniq_list_of(item, min_length: min, max_length: max)
    else
      StreamData.list_of(item, min_length: min, max_length: max)
    end
  end

  def get_one_of() do
    for(n <- @type_list, is_map(n), do: Jake.gen_init(n)) |> StreamData.one_of()
  end

  def add_additional_items(list, bool, max, min) when is_boolean(bool) and bool do
    generate_list(list, get_one_of(), max, min)
  end

  def add_additional_items(list, bool, max, min) when is_boolean(bool) and not bool do
    if length(list) in min..max do
      StreamData.fixed_list(list)
    end
  end

  def add_additional_items(list, map, max, min) when is_map(map) do
    generate_list(list, Jake.gen_init(map), max, min)
  end

  def generate_list(olist, additional, max, min) do
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

          nlist when true ->
            :skip
        end
      )
    end)
  end
end
