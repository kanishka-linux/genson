defmodule Jake.Ref do
  def expand_ref(ref, map, _omap)
      when is_nil(ref) or is_map(ref) or ref == "#" do
    map
  end

  def expand_ref(ref, map, omap) when is_binary(ref) do
    nmap = Map.drop(map, ["$ref"])
    uri = URI.decode(ref)

    ref_map =
      if String.starts_with?(uri, "http") do
        process_http_path(uri)
      else
        process_local_path(uri) |> get_head_list_path(omap)
      end

    nmap =
      if ref_map != nil do
        Map.merge(nmap, ref_map)
      else
        nmap
      end

    check_ref_string(nmap, omap, [], ref)
  end

  def check_ref_string(nmap, omap, ref_list, ref) do
    if ref in ref_list do
      str = Poison.encode!(nmap)

      ref_map =
        URI.decode(ref)
        |> process_local_path()
        |> get_head_list_path(omap)
        |> Poison.encode!()
        |> String.slice(1..-2)

      String.replace(str, ~r/"\$ref":"#{ref}"/, ref_map)
      |> String.replace(~r/"\$ref":"#{ref}"/, "")
      |> Poison.decode!()
    else
      ref_list = ref_list ++ [ref]
      str = Poison.encode!(nmap)
      relist = Regex.scan(~r/"\$ref":"(?<name>[^"]*)"/, str)
      if length(relist) == 0, do: nmap, else: find_replace_ref(str, relist, omap, ref_list)
    end
  end

  def find_replace_ref(str, relist, omap, ref_list) do
    nlist =
      for n <- relist do
        [refstr, ref] = n
        ref_map = URI.decode(ref) |> process_local_path() |> get_head_list_path(omap)

        map =
          check_ref_string(ref_map, omap, ref_list, ref)
          |> Poison.encode!()
          |> String.slice(1..-2)

        {refstr, map}
      end

    Enum.reduce(nlist, str, fn {ref, map} = x, acc -> String.replace(acc, "#{ref}", map) end)
    |> Poison.decode!()
  end

  def get_head_list_path(path_list, omap) do
    {head, tail} = Enum.split(path_list, -1)

    head_path =
      if length(head) > 0 do
        get_in(omap, head)
      else
        get_in(omap, path_list)
      end

    tail =
      if is_list(head_path) do
        Enum.fetch!(tail, 0)
      else
        nil
      end

    if tail != nil and is_numeric(tail) do
      {index, ""} = Integer.parse(tail)
      Enum.fetch!(head_path, index)
    else
      get_in(omap, path_list)
    end
  end

  def process_http_path(url) do
    [url, local] =
      if String.contains?(url, "#/") do
        String.split(url, "#/")
      else
        [url, nil]
      end

    IO.inspect({url, local})
    {:ok, {{_, 200, _}, _, schema}} = :httpc.request(:get, {to_charlist(url), []}, [], [])
    jschema = Poison.decode!(schema)

    if is_nil(local) do
      jschema
    else
      process_local_path(local) |> get_head_list_path(jschema)
    end
  end

  def process_local_path(path) do
    str =
      String.replace(path, "~0", "~")
      |> String.replace("#/", "", global: false)

    if String.contains?(str, "~1") do
      strlist = String.split(str, "/")
      for n <- strlist, do: String.replace(n, "~1", "/")
    else
      String.split(str, "/")
    end
  end

  def is_numeric(str) do
    case Integer.parse(str) do
      {_num, ""} -> true
      _ -> false
    end
  end
end
