defmodule Jake.String do
  @strlen_min 1

  @strlen_max 100

  def gen_string(map), do: stringer(map, map["enum"], map["pattern"])

  def find_min_max(map) do
    min = Map.get(map, "minLength", @strlen_min)
    max = Map.get(map, "maxLength", @strlen_max)
    {min, max}
  end

  def stringer(map, enum, pattern) when is_nil(enum) and is_nil(pattern) do
    {min, max} = find_min_max(map)
    re = Randex.stream(~r/[a-zA-Z0-9\_]{#{min},#{max}}/)

    if min <= max do
      StreamData.bind_filter(StreamData.string(:alphanumeric), fn
        x when byte_size(x) in min..max ->
          {:cont, StreamData.constant(x)}

        x when true ->
          {:cont, Enum.take(re, 1) |> StreamData.member_of()}
      end)
    end

    # StreamData.string(:alphanumeric, [{:max_length, max},{:min_length, min}])
  end

  def stringer(map, enum, pattern) when is_list(enum) do
    Jake.gen_enum(map["enum"], "string")
  end

  def stringer(map, enum, pattern) when is_binary(pattern) do
    {min, max} = find_min_max(map)
    pat = Randex.stream(~r/#{pattern}/, mod: Randex.Generator.StreamData)

    if min <= max do
      StreamData.bind_filter(pat, fn
        x when byte_size(x) in min..max -> {:cont, StreamData.constant(x)}
        x when true -> :skip
      end)
    end
  end
end
