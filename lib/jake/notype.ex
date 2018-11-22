defmodule Jake.Notype do
  @prop %{
    "minLength" => "string",
    "maxLength" => "string",
    "pattern" => "string",
    "multipleOf" => "number",
    "minimum" => "number",
    "maximum" => "number",
    "exclusiveMinimum" => "number",
    "exclusiveMaximum" => "number",
    "items" => "array",
    "additionalItems" => "array",
    "minItems" => "array",
    "maxItems" => "array",
    "uniqueItems" => "array",
    "properties" => "object",
    "patternProperties" => "object",
    "additionalProperties" => "object",
    "dependencies" => "object",
    "required" => "object",
    "minProperties" => "object",
    "maxProperties" => "object"
  }

  def gen_notype(map, type, omap) do
    nmap = for {k, v} <- map, into: %{}, do: {k, v}
    nlist = for {k, v} <- map, into: [], do: @prop[k]

    types =
      Enum.reduce(nlist, nil, fn
        x, acc when not is_nil(x) -> x
        x, acc when is_nil(x) -> acc
      end)

    if type == nil do
      nmap = if not is_nil(types), do: Map.put(nmap, "type", types), else: nmap
      if nmap["type"], do: Jake.gen_init(nmap, omap)
    else
      types
    end
  end
end
