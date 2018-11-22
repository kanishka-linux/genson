defmodule JakeTestRef do
  use ExUnitProperties
  use ExUnit.Case
  doctest Jake

  def test_generator_property(jschema) do
    gen = Jake.generator(jschema)
    schema = Poison.decode!(jschema)
    IO.inspect(Enum.take(gen, 3))

    check all a <- gen do
      assert ExJsonSchema.Validator.valid?(schema, a)
    end
  end

  property "test ref simple" do
    jschema = ~s({"properties": {
                "foo": {"type": "integer"},
                "bar": {"$ref": "#/properties/foo"}
                }})
    test_generator_property(jschema)
  end

  property "test ref escape pointer" do
    jschema = ~s({"tilda~field": {"type": "integer"},
            "slash/field": {"type": "integer"},
            "percent%field": {"type": "integer"},
            "properties": {
                "tilda": {"$ref": "#/tilda~0field"},
                "slash": {"$ref": "#/slash~1field"},
                "percent": {"$ref": "#/percent%25field"}
            }})
    test_generator_property(jschema)
  end

  property "test ref nested schema" do
    jschema = ~s({"definitions": {
                "a": {"type": "integer"},
                "b": {"$ref": "#/definitions/a"},
                "c": {"$ref": "#/definitions/b"}
            },
            "$ref": "#/definitions/c"})
    test_generator_property(jschema)
  end

  property "test ref overrides any sibling keywords" do
    jschema = ~s({"definitions": {
                "reffed": {
                    "type": "array"
                }
            },
            "properties": {
                "foo": {
                    "$ref": "#/definitions/reffed",
                    "maxItems": 2
                }
            }})
    test_generator_property(jschema)
  end

  property "test ref not reference" do
    jschema = ~s({"properties": {
                "$ref": {"type": "string"}
            }})
    test_generator_property(jschema)
  end

  property "test ref array index" do
    jschema = ~s({"items": [
                {"type": "integer"},
                {"$ref": "#/items/0"}
            ]})
    test_generator_property(jschema)
  end

  property "test ref root" do
    jschema = ~s({"properties": {
                "bar" : {"type":"integer"},
                "foo": {"$ref": "#"}
            },
            "additionalProperties": false})
    test_generator_property(jschema)
  end
end
