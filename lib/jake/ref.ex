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

    nmap = Map.merge(nmap, ref_map)
    nref = nmap["$ref"]
    if nref, do: expand_ref(nref, nmap, omap), else: nmap
  end

  def get_head_list_path(path_list, omap) do
    {head, tail} = Enum.split(path_list, -1)
    IO.inspect({head, tail})

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

    {:ok, {{_, 200, _}, _, schema}} = :httpc.request(:get, {url, []}, [], [])
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
