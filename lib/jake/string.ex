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
    StreamData.string(:alphanumeric, [{:max_length, max}, {:min_length, min}])
  end

  def stringer(map, enum, pattern) when is_list(enum) do
    Jake.gen_enum(map["enum"], "string")
  end

  def stringer(map, enum, pattern) when is_binary(pattern) do
    {min, max} = find_min_max(map)
    pat = Randex.stream(~r/#{pattern}/, mod: Randex.Generator.StreamData)

    if min <= max do
      StreamData.filter(pat, fn x -> String.length(x) in min..max end)
    end
  end
end
