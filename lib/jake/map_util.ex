# Ref: https://stackoverflow.com/questions/38864001/elixir-how-to-deep-merge-maps
# Ref: https://github.com/activesphere/jake/blob/master/lib/jake/map_util.ex

defmodule Jake.MapUtil do
  def deep_merge(left, right) do
    Map.merge(left, right, &deep_resolve/3)
  end

  defp deep_resolve(_key, left, nil) do
    left
  end

  defp deep_resolve(_key, nil, right) do
    right
  end

  defp deep_resolve(key, left, right) when key == "type" do
    case {is_list(left), is_list(right)} do
      {x, y} when x and y -> left ++ right
      {x, y} when x and not y -> left ++ [right]
      {x, y} when not x and y -> [left] ++ right
      {x, y} when not x and not y -> [left, right]
    end
  end

  defp deep_resolve(_key, left, right) when is_map(left) do
    Map.merge(left, right)
  end

  defp deep_resolve(_key, left, right) when is_list(left) do
    left ++ right
  end
end
