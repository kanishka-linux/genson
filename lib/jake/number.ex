defmodule Jake.Number do
  @num_min -9_007_199_254_740_991

  @num_max 9_007_199_254_740_991

  @max_mult 100

  def get_min_max(map) do
    min = Map.get(map, "minimum", @num_min)
    max = Map.get(map, "maximum", @num_max)
    {min, max}
  end

  def gen_number(map, type) do
    {min_i, max_i} = get_min_max(map)
    {step_left, step_right} = find_step(map, min_i, max_i)
    min = findmin(map, @num_min, step_left, type)
    max = findmax(map, @num_max, step_right, type)
    random_number_gen(map["multipleOf"], type, min, max)
  end

  def find_step(map, low, high) when is_number(low) and is_number(high) and low <= high do
    mult = map["multipleOf"]

    if is_number(mult) do
      step_left = mult * (trunc(low / mult) + 1) - low
      step_right = high - mult * trunc(high / mult)

      case {step_left, step_right} do
        {x, y} when x == 0 and y == 0 ->
          {(mult * (low / mult + 1) - low) / 2, (high - mult * (high / mult - 1)) / 2}

        {x, y} when x == 0 ->
          {(mult * (low / mult + 1) - low) / 2, y}

        {x, y} when y == 0 ->
          {x, (high - mult * (high / mult - 1)) / 2}

        _ ->
          {step_left, step_right}
      end
    else
      {(high - low) / 1000, (high - low) / 1000}
    end
  end

  def find_step(map, low, high) when true, do: {0.001, 0.001}

  def random_number_gen(mult, type, min, max) when type == "integer" do
    new_min =
      case min do
        x when is_float(x) ->
          new_min = trunc(min) + 1

        x when is_integer(x) ->
          new_min = min
      end

    new_max =
      case max do
        x when is_float(x) ->
          new_max = trunc(x)

        x when is_integer(x) ->
          new_max = max
      end

    random_number_int(mult, new_min, new_max)
  end

  def random_number_gen(mult, type, min, max) when type == "number" do
    case {mult, min, max} do
      {m, x, y} when is_integer(x) and is_integer(y) ->
        random_number_int(m, x, y)

      {m, x, y} when is_number(m) ->
        random_number_float(m * 1.0, x, y)

      _ ->
        random_number_float(mult, min, max)
    end
  end

  def random_number_int(mult, min, max) when is_number(mult) and round(mult) == mult do
    getmultipleof(round(mult), min, max)
  end

  def random_number_int(mult, min, max) when is_number(mult) and round(mult) != mult do
    getmultipleof(mult, min, max)
  end

  def random_number_int(mult, min, max) when is_nil(mult) do
    StreamData.integer(min..max)
  end

  def random_number_float(mult, min, max) when is_float(mult) do
    getmultipleof(mult, min, max)
  end

  def random_number_float(mult, min, max) when mult == nil do
    StreamData.float([{:min, min}, {:max, max}])
  end

  def findmax(map, max, _, type) when type == "integer" do
    case {map["maximum"], map["exclusiveMaximum"]} do
      {x, y} when is_integer(x) and y -> x - 1
      {x, y} when is_float(x) and y -> trunc(x)
      {x, _} when is_number(x) -> x
      _ -> max
    end
  end

  def findmax(map, max, step_right, type) when type == "number" do
    case {map["maximum"], map["exclusiveMaximum"]} do
      {x, y} when is_number(x) and y -> x - step_right
      {x, _} when is_number(x) -> x
      _ -> max
    end
  end

  def findmin(map, min, _, type) when type == "integer" do
    case {map["minimum"], map["exclusiveMinimum"]} do
      {x, y} when is_integer(x) and y -> x + 1
      {x, y} when is_float(x) and y -> trunc(x)
      {x, _} when is_number(x) -> x
      _ -> min
    end
  end

  def findmin(map, min, step_left, type) when type == "number" do
    case {map["minimum"], map["exclusiveMinimum"]} do
      {x, y} when is_number(x) and y -> x + step_left
      {x, _} when is_number(x) -> x
      _ -> min
    end
  end

  def getmultipleof(mult, min, max) when is_integer(mult) do
    fn_mod = fn x -> rem(x, mult) == 0 end
    StreamData.filter(StreamData.integer(min..max), fn_mod, 100)
  end

  def getmultipleof(mult, min, max) when is_float(mult) do
    fn_check = fn x, y -> x * y >= min and x * y <= max end
    lo = trunc(min / mult)
    for(n <- lo..(lo + @max_mult), fn_check.(n, mult), do: n * mult) |> StreamData.member_of()
  end
end
