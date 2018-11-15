defmodule Jake.Object do
  @type_list [
    %{"type" => "integer"},
    %{"type" => "number"},
    %{"type" => "boolean"},
    %{"type" => "string"},
    %{"type" => "null"},
    nil
  ]

  @min_properties 0

  @max_properties 1000

  def get_min_max(map) do
    min = Map.get(map, "minProperties", @min_properties)
    max = Map.get(map, "maxProperties", @max_properties)
    {min, max}
  end

  def gen_object(map, type), do: objectype(map, map["enum"], map["properties"])

  def objectype(map, enum, properties) when enum != nil, do: Jake.gen_enum(enum, "object")

  def objectype(map, enum, properties) when is_nil(properties) and is_nil(enum) do
    {min, max} = get_min_max(map)
    decide_min_max(map, Jake.gen_init(%{"type" => "string"}), StreamData.term(), min, max)
  end

  def objectype(map, enum, properties) when is_map(properties) do
    nproperties = check_pattern_properties(map, properties, map["patternProperties"])

    pmap =
      if nproperties != nil and is_list(nproperties) do
        nlist = for n <- nproperties, length(n) > 0, do: Enum.fetch!(n, 0)
        Enum.reduce(nlist, %{}, fn x, acc -> Map.merge(x, acc) end)
      else
        properties
      end

    map = Map.put(map, "properties", pmap)
    new_prop = for {k, v} <- pmap, into: %{}, do: {k, Jake.gen_init(v)}

    req =
      if map["required"] do
        for n <- map["required"], into: %{}, do: {n, Map.get(new_prop, n)}
      end

    non_req =
      if is_map(req) and map_size(req) > 0 do
        for {k, v} <- new_prop, req[k] == nil, into: %{}, do: {k, v}
      end

    if is_nil(req) or map_size(req) == 0 do
      check_additional_properties(map, 0, req, non_req, new_prop)
    else
      check_additional_properties(map, Map.size(req), req, non_req, new_prop)
    end
  end

  def check_pattern_properties(map, properties, pprop) do
    if pprop do
      for {k, v} <- properties do
        for {key, value} <- pprop,
            Regex.match?(~r/#{key}/, k),
            do: Map.put(properties, k, Map.merge(v, value))
      end
    else
      properties
    end
  end

  def bind_function(new_prop, additional, y, z) do
    StreamData.bind(StreamData.optional_map(new_prop), fn mapn ->
      StreamData.bind_filter(
        additional,
        fn
          nmap
          when (map_size(mapn) + map_size(nmap)) in y..z ->
            {:cont, StreamData.constant(Map.merge(mapn, nmap))}

          nmap when map_size(mapn) in y..z ->
            {:cont, StreamData.constant(mapn)}

          nmap when is_map(nmap) ->
            :skip
        end
      )
    end)
  end

  def bind_function_req(req, non_req, y, z) when is_map(non_req) or is_nil(non_req) do
    StreamData.bind_filter(
      StreamData.fixed_map(req),
      fn
        mapn when is_map(non_req) ->
          {:cont,
           StreamData.bind_filter(StreamData.optional_map(non_req), fn
             nmap
             when (map_size(mapn) + map_size(nmap)) in y..z ->
               {:cont, StreamData.constant(Map.merge(mapn, nmap))}

             nmap
             when map_size(mapn) in y..z ->
               {:cont, StreamData.constant(mapn)}

             nmap when true ->
               :skip
           end)}

        mapn
        when is_nil(non_req) and map_size(mapn) in y..z ->
          {:cont, StreamData.constant(mapn)}

        mapn when is_nil(non_req) ->
          :skip
      end
    )
  end

  def bind_function_req(req, non_req, y, z, add) when not is_nil(non_req) do
    StreamData.bind(
      StreamData.fixed_map(req),
      fn
        mapn when is_map(non_req) ->
          StreamData.bind_filter(non_req, fn
            nmap
            when (map_size(mapn) + map_size(nmap)) in y..z ->
              {:cont, StreamData.constant(Map.merge(mapn, nmap))}

            nmap
            when map_size(mapn) in y..z ->
              {:cont, StreamData.constant(mapn)}

            nmap when true ->
              :skip
          end)
      end
    )
  end

  def check_additional_properties(map, req_size, req, non_req, new_prop)
      when is_nil(req) or req_size == 0 do
    {min, max} = get_min_max(map)

    case {map["additionalProperties"], min, max} do
      {x, y, z} when is_nil(x) or (is_boolean(x) and x) ->
        additional = objectype(map, nil, nil)
        bind_function(new_prop, additional, y, z)

      {x, y, z} when is_boolean(x) and not x ->
        StreamData.bind_filter(
          StreamData.optional_map(new_prop),
          fn
            map
            when map_size(map) in y..z ->
              {:cont, StreamData.constant(map)}

            map when true ->
              :skip
          end
        )

      {x, y, z} when is_map(x) ->
        obj = Jake.gen_init(x)
        key = Jake.gen_init(%{"type" => "string"})
        bind_function(new_prop, StreamData.map_of(key, obj), y, z)
    end
  end

  def check_additional_properties(map, req_size, req, non_req, new_prop) when req_size > 0 do
    {min, max} = get_min_max(map)

    case {map["additionalProperties"], min, max} do
      {x, y, z} when is_nil(x) or (is_boolean(x) and x) ->
        additional = objectype(map, nil, nil)
        val2 = bind_function(non_req, additional, y, z)
        bind_function_req(req, val2, y, z, "additional")

      {x, y, z} when is_boolean(x) and not x ->
        bind_function_req(req, non_req, y, z)

      {x, y, z} when is_map(x) ->
        obj = Jake.gen_init(x)
        key = Jake.gen_init(%{"type" => "string"})
        val1 = StreamData.map_of(key, obj, min_length: y, max_length: z)
        val2 = bind_function(non_req, val1, y, z)
        bind_function_req(req, val2, y, z, "additional")
    end
  end

  def decide_min_max(map, key, value, min, max)
      when is_integer(min) and is_integer(max) and min <= max do
    if map["additionalProperties"] != nil do
      objectype(map, nil, %{})
    else
      StreamData.map_of(key, value, min_length: min, max_length: max)
    end
  end
end
