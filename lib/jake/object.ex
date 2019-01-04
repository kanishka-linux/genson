defmodule Jake.Object do
  @min_properties 0

  @max_properties 1000

  def get_min_max(map) do
    min = Map.get(map, "minProperties", @min_properties)
    max = Map.get(map, "maxProperties", @max_properties)
    {min, max}
  end

  def gen_object(map, properties, omap, size) when is_nil(properties) do
    {min, max} = get_min_max(map)

    if map["patternProperties"] do
      nlist =
        for {k, v} <- map["patternProperties"],
            do: build_and_verify_patterns(k, v, map["patternProperties"], omap, size)

      merge_patterns(nlist)
    else
      if map["dependencies"] do
        decide_dep_and_properties(map, omap, size)
      else
        decide_min_max(
          map,
          Jake.gen_init(%{"type" => "string"}, omap, size),
          StreamData.term(),
          min,
          max,
          omap,
          size
        )
      end
    end
  end

  def gen_object(map, properties, omap, size) when is_map(properties) do
    nproperties = check_pattern_properties(map, properties, map["patternProperties"])

    pmap =
      if nproperties != nil and is_list(nproperties) do
        nlist = for n <- nproperties, length(n) > 0, do: Enum.fetch!(n, 0)
        Enum.reduce(nlist, %{}, fn x, acc -> Map.merge(x, acc) end)
      else
        properties
      end

    fn_not_check = fn k, v ->
      if v["not"] != nil and is_map(v["not"]) and map_size(v["not"]) == 0,
        do: {"null", "null"},
        else: {k, Jake.gen_init(v, omap, size)}
    end

    map = Map.put(map, "properties", pmap)
    new_prop = for {k, v} <- pmap, into: %{}, do: fn_not_check.(k, v)
    new_prop = if new_prop["null"] == "null", do: Map.drop(new_prop, ["null"]), else: new_prop

    req =
      if map["required"] do
        for n <- map["required"], into: %{}, do: {n, Map.get(new_prop, n)}
      end

    non_req =
      if is_map(req) and map_size(req) > 0 do
        for {k, v} <- new_prop, req[k] == nil, into: %{}, do: {k, v}
      end

    if is_nil(req) or map_size(req) == 0 do
      check_additional_properties(map, 0, req, non_req, new_prop, omap, size)
    else
      check_additional_properties(map, Map.size(req), req, non_req, new_prop, omap, size)
    end
  end

  def merge_patterns(nlist) do
    merge_maps = fn list -> Enum.reduce(list, %{}, fn x, acc -> Map.merge(acc, x) end) end

    StreamData.bind(StreamData.fixed_list(nlist), fn list ->
      StreamData.constant(merge_maps.(list))
    end)
  end

  def build_and_verify_patterns(key, value, pprop, omap, size) do
    pprop_schema = %{"patternProperties" => pprop}
    # IO.inspect(pprop_schema)
    nkey = Randex.stream(~r/#{key}/, mod: Randex.Generator.StreamData)
    nval = Jake.gen_init(value, omap, size)

    StreamData.bind(nkey, fn k ->
      StreamData.bind_filter(
        nval,
        fn v ->
          result = ExJsonSchema.Validator.valid?(pprop_schema, %{k => v})
          if result, do: {:cont, StreamData.constant(%{k => v})}, else: :skip
        end,
        100
      )
    end)
  end

  def gen_with_no_prop(map, omap, size) do
    {min, max} = get_min_max(map)

    Jake.gen_init(%{"type" => "string"}, omap, size)
    |> StreamData.map_of(StreamData.term(), min_length: min, max_length: max)
  end

  def decide_dep_and_properties(map, omap, size) do
    dep = map["dependencies"]

    list_with_map =
      for {k, v} <- dep do
        # IO.inspect(v)

        if is_list(v) do
          item = %{k => StreamData.term()}
          nmap = for i <- v, into: %{}, do: {i, StreamData.term()}
          Map.merge(item, nmap)
        else
          prop_list = for {kl, vl} <- v["properties"], do: kl
          {k, prop_list, v["properties"]}
        end
      end

    resolve_dep(map, list_with_map, omap, size)
  end

  def resolve_dep(map, list_with_map, omap, size) do
    if is_map(List.first(list_with_map)) do
      properties = Enum.reduce(list_with_map, %{}, fn x, acc -> Map.merge(acc, x) end)
      check_additional_properties(map, 0, nil, nil, properties, omap, size)
    else
      dependencies =
        for({k, prop_list, prop_map} <- list_with_map, do: %{k => prop_list})
        |> Enum.reduce(%{}, fn x, acc -> Map.merge(x, acc) end)

      # IO.inspect(dependencies)

      properties =
        for({k, prop_list, prop_map} <- list_with_map, do: prop_map)
        |> Enum.reduce(%{}, fn x, acc -> Map.merge(x, acc) end)

      map = Map.put(map, "properties", properties) |> Map.put("dependencies", dependencies)
      # IO.inspect(map)
      gen_object(map, properties, omap, size)
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
    prop =
      if is_list(new_prop) do
        StreamData.one_of(new_prop)
      else
        StreamData.optional_map(new_prop)
      end

    # IO.inspect(prop)

    StreamData.bind(prop, fn mapn ->
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

  def create_dep_list_map(new_prop, dep) do
    dep_list = for {k, v} <- dep, do: k
    {dep_map, non_dep_map} = Map.split(new_prop, dep_list)

    list_with_map =
      for {k, v} <- dep do
        item = %{k => get_in(new_prop, [k])}
        nmap = for i <- v, into: %{}, do: {i, get_in(new_prop, [i])}
        StreamData.fixed_map(Map.merge(item, nmap))
      end

    list_with_map ++ [StreamData.optional_map(non_dep_map)]
  end

  def bind_function_req(non_req, req, y, z)
      when is_map(non_req) or is_nil(non_req) or is_list(non_req) do
    prop =
      if is_list(non_req) do
        StreamData.one_of(non_req)
      else
        StreamData.optional_map(non_req)
      end

    StreamData.bind_filter(
      StreamData.fixed_map(req),
      fn
        mapn when is_map(non_req) or is_list(non_req) ->
          {:cont,
           StreamData.bind_filter(prop, fn
             nmap
             when (map_size(mapn) + map_size(nmap)) in y..z ->
               {:cont, StreamData.constant(Map.merge(mapn, nmap))}

             nmap
             when map_size(mapn) in y..z ->
               {:cont, StreamData.constant(mapn)}

             _ ->
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

  def bind_function_req(non_req, req, y, z, add) when not is_nil(non_req) do
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

            _ ->
              :skip
          end)
      end
    )
  end

  def check_additional_properties(map, req_size, req, _non_req, new_prop, omap, size)
      when is_nil(req) or req_size == 0 do
    {min, max} = get_min_max(map)

    case {map["additionalProperties"], min, max} do
      {x, y, z} when is_nil(x) or (is_boolean(x) and x) ->
        additional = gen_with_no_prop(map, omap, size)

        check_dependencies(map, new_prop)
        |> bind_function(additional, y, z)

      {x, y, z} when is_boolean(x) and not x ->
        val = check_dependencies(map, new_prop)

        prop =
          if is_list(val) do
            StreamData.one_of(val)
          else
            StreamData.optional_map(val)
          end

        StreamData.filter(prop, fn nmap -> map_size(nmap) in y..z end)

      {x, y, z} when is_map(x) ->
        obj = Jake.gen_init(x, omap, size)
        key = Jake.gen_init(%{"type" => "string"}, omap, size)

        check_dependencies(map, new_prop)
        |> bind_function(StreamData.map_of(key, obj), y, z)
    end
  end

  def check_additional_properties(map, req_size, req, non_req, new_prop, omap, size)
      when req_size > 0 do
    {min, max} = get_min_max(map)

    case {map["additionalProperties"], min, max} do
      {x, y, z} when is_nil(x) or (is_boolean(x) and x) ->
        additional = gen_with_no_prop(map, omap, size)

        check_dependencies(map, non_req)
        |> bind_function(additional, y, z)
        |> bind_function_req(req, y, z, "additional")

      {x, y, z} when is_boolean(x) and not x ->
        check_dependencies(map, non_req)
        |> bind_function_req(req, y, z)

      {x, y, z} when is_map(x) ->
        obj = Jake.gen_init(x, omap, size)
        key = Jake.gen_init(%{"type" => "string"}, omap, size)
        val1 = StreamData.map_of(key, obj, min_length: y, max_length: z)

        check_dependencies(map, non_req)
        |> bind_function(val1, y, z)
        |> bind_function_req(req, y, z, "additional")
    end
  end

  def check_dependencies(map, non_req) do
    if map["dependencies"] do
      create_dep_list_map(non_req, map["dependencies"])
    else
      non_req
    end
  end

  def decide_min_max(map, key, value, min, max, omap, size)
      when is_integer(min) and is_integer(max) and min <= max do
    if map["additionalProperties"] != nil do
      gen_object(map, %{}, omap, size)
    else
      StreamData.map_of(key, value, min_length: min, max_length: max)
    end
  end
end
