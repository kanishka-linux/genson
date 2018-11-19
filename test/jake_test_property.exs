defmodule JakeTestProperty do
  use ExUnitProperties
  use ExUnit.Case
  doctest Jake

  @tag timeout: 300_000
  property "suite" do
    for path <- [
          "draft4/type.json",
          "draft4/anyOf.json",
          "draft4/required.json",
          "draft4/allOf.json",
          "draft4/enum.json",
          "draft4/minimum.json",
          "draft4/maximum.json",
          "draft4/items.json",
          "draft4/minItems.json",
          "draft4/maxItems.json",
          "draft4/uniqItems.json",
          "draft4/pattern.json",
          "draft4/minLength.json",
          "draft4/maxLength.json",
          "draft4/maxProperties.json",
          "draft4/minProperties.json",
          "draft4/additionalItems.json",
          "draft4/additionalProperties.json",
          "draft4/multipleOf.json",
          "draft4/properties.json",
          "draft4/patternProperties.json",
          "draft4/dependencies.json",
          "draft4/default.json",
          "draft4/oneOf.json",
          "draft4/not.json"
        ] do
      Path.wildcard("test_suite/tests/#{path}")
      |> Enum.map(fn path -> File.read!(path) |> Poison.decode!() end)
      |> Enum.concat()
      |> Enum.map(fn %{"schema" => schema} -> verify(schema) end)
    end
  end

  def verify(schema) do
    Poison.encode!(schema) |> test_generator_property()
  end

  def test_generator_property(jschema) do
    gen = Jake.generator(jschema)
    schema = Poison.decode!(jschema)
    IO.inspect(Enum.take(gen, 3))

    check all a <- gen do
      assert ExJsonSchema.Validator.valid?(schema, a)
    end
  end

  property "test anyOf" do
    jschema = ~s({"anyOf": [{"type": "object"}, {"type": "array"}]})
    test_generator_property(jschema)
  end

  property "test allOf" do
    jschema = ~s({"allOf": [{"type": "integer"}, {"maximum": 255}]})
    test_generator_property(jschema)
  end

  property "test not" do
    jschema = ~s({"not": {"type": "integer"}})
    test_generator_property(jschema)
  end

  property "test oneOf" do
    jschema = ~s({"type": "integer", "minimum": 29, "oneOf": [{"maximum": 255}, {"minimum": 25}]})
    test_generator_property(jschema)
  end

  property "test type both integer string" do
    jschema = ~s({"type": ["string", "integer"], "maxLength": 5, "minLength": 1, "maximum": 29})
    test_generator_property(jschema)
  end

  property "test object with no properties" do
    jschema = ~s({"type": "object"})
    test_generator_property(jschema)
  end

  property "test object with properties" do
    jschema =
      ~s({"type": "object", "properties": {"name":{"type":"string", "maxLength": 10}, "age":{"type": "integer", "minimum": 1, "maximum": 125}}, "required":["name", "age"]})

    test_generator_property(jschema)
  end

  property "test object with required properties and dependencies" do
    jschema =
      ~s({"type": "object", "properties": {"name":{"type":"string", "maxLength": 10}, "age":{"type": "integer", "minimum": 1, "maximum": 125}, "dt":{"type":"string", "pattern":"[0][1-9]|[1-2][0-9]|[3][0-1]"}, "address": {"type":"string"}}, "required":["name"], "dependencies":{"dt":["age"], "age":["dt"]}})

    test_generator_property(jschema)
  end

  property "test object with required properties, dependencies and no additional properties" do
    jschema =
      ~s({"type": "object", "properties": {"name":{"type":"string", "maxLength": 10}, "age":{"type": "integer", "minimum": 1, "maximum": 125}, "dt":{"type":"string", "pattern":"[0][1-9]|[1-2][0-9]|[3][0-1]"}, "address": {"type":"string"}}, "required":["name"], "dependencies":{"dt":["age"], "age":["dt"]}, "additionalProperties":false})

    test_generator_property(jschema)
  end

  property "test object with required properties, dependencies and map of additional properties" do
    jschema =
      ~s({"type": "object", "properties": {"name":{"type":"string", "maxLength": 10}, "age":{"type": "integer", "minimum": 1, "maximum": 125}, "dt":{"type":"string", "pattern":"[0][1-9]|[1-2][0-9]|[3][0-1]"}, "address": {"type":"string"}}, "required":["name"], "dependencies":{"dt":["age"], "age":["dt"]}, "additionalProperties":{"type":"boolean"}})

    test_generator_property(jschema)
  end

  property "test object with dependencies and map of additional properties" do
    jschema =
      ~s({"type": "object", "properties": {"name":{"type":"string", "maxLength": 10}, "age":{"type": "integer", "minimum": 1, "maximum": 125}, "dt":{"type":"string", "pattern":"[0][1-9]|[1-2][0-9]|[3][0-1]"}, "address": {"type":"string"}}, "dependencies":{"dt":["age"], "age":["dt"]}, "additionalProperties":{"type":"boolean"}})

    test_generator_property(jschema)
  end

  property "test object with dependencies and no additional properties" do
    jschema =
      ~s({"type": "object", "properties": {"name":{"type":"string", "maxLength": 10}, "age":{"type": "integer", "minimum": 1, "maximum": 125}, "dt":{"type":"string", "pattern":"[0][1-9]|[1-2][0-9]|[3][0-1]"}, "address": {"type":"string"}}, "dependencies":{"dt":["age"], "age":["dt"]}, "additionalProperties":false})

    test_generator_property(jschema)
  end

  property "test object with dependencies and additional properties" do
    jschema =
      ~s({"type": "object", "properties": {"name":{"type":"string", "maxLength": 10}, "age":{"type": "integer", "minimum": 1, "maximum": 125}, "dt":{"type":"string", "pattern":"[0][1-9]|[1-2][0-9]|[3][0-1]"}, "address": {"type":"string"}}, "dependencies":{"dt":["age"], "age":["dt"]}, "additionalProperties":true})

    test_generator_property(jschema)
  end

  property "test object with properties minmax" do
    jschema =
      ~s({"type": "object", "properties": {"name":{"type":"string", "maxLength": 10}, "age":{"type": "integer", "minimum": 1, "maximum": 125}}, "additionalProperties": {"type": "integer"}, "minProperties":1, "maxProperties": 50})

    test_generator_property(jschema)
  end

  property "test object with properties required" do
    jschema =
      ~s({"type": "object", "properties": {"name":{"type":"string", "maxLength": 10}, "age":{"type": "integer", "minimum": 1, "maximum": 125}}, "additionalProperties": false, "minProperties":1, "maxProperties": 5, "required": ["age", "name"]})

    test_generator_property(jschema)
  end

  property "test object with additional properties and required" do
    jschema =
      ~s({"type": "object", "properties": {"name":{"type":"string", "maxLength": 10}, "age":{"type": "integer", "minimum": 1, "maximum": 125}}, "additionalProperties": {"type": "integer"}, "minProperties":2, "maxProperties": 5, "required": ["age"]})

    test_generator_property(jschema)
  end

  property "test array items" do
    jschema =
      ~s({"type": "array", "items" : [{"type": "integer"}, {"type": "string", "maxLength": 10}, {"type": "boolean"}], "additionalItems": {"type": "boolean"} })

    test_generator_property(jschema)
  end

  property "test array item with bounds" do
    jschema =
      ~s({"type": "array", "items" : {"type": "string", "maxLength": 10, "minLength":5}, "minItems": 1, "maxItems": 100 })

    test_generator_property(jschema)
  end

  property "test array single item" do
    jschema =
      ~s({"type": "array", "items" : {"type": "string", "maxLength": 10}, "additionalItems":true})

    test_generator_property(jschema)
  end

  property "test string" do
    jschema = ~s({"type": "string", "maxLength": 5, "minLength": 1})
    test_generator_property(jschema)
  end

  property "test string regex" do
    jschema = ~s({"type": "string", "pattern": "[a-zA-Z0-9_]{5,10}@abc[.]\(org|com|in\)"})
    test_generator_property(jschema)
  end

  property "test string regex with length" do
    jschema =
      ~s({"type": "string", "pattern": "[a-zA-Z0-9_]{5,10}@abc[.]\(org|com|in\)", "minLength": 5, "maxLength": 20})

    test_generator_property(jschema)
  end

  property "test integer" do
    jschema = ~s({"type": "integer", "maximum": 111, "minimum": -87, "multipleOf": 9})
    test_generator_property(jschema)
  end

  property "test integer excl" do
    jschema =
      ~s({"type": "integer", "maximum": 120, "minimum": -87, "multipleOf": 6, "exclusiveMaximum": true})

    test_generator_property(jschema)
  end

  property "test number" do
    jschema = ~s({"type": "number", "maximum": 7.5, "minimum": 3.6})
    test_generator_property(jschema)
  end

  property "test number multiple" do
    jschema = ~s({"type": "number", "maximum": 9.7, "minimum": 3.2, "multipleOf": 1.5})
    test_generator_property(jschema)
  end

  property "test number multiple again" do
    jschema = ~s({"type": "number", "maximum": 9.8, "minimum": -3.6, "multipleOf": 2})
    test_generator_property(jschema)
  end

  property "test fraction" do
    jschema = ~s({"type": "number", "maximum": 9.7, "minimum": 9.65, "multipleOf": 0.04})
    test_generator_property(jschema)
  end

  property "test fraction excl" do
    jschema =
      ~s({"type": "number", "maximum": 8.1, "minimum": 7.79, "multipleOf": 0.3, "exclusiveMaximum": true, "exclusiveMinimum": true})

    test_generator_property(jschema)
  end

  property "test number negative" do
    jschema = ~s({"type": "number", "maximum": -3, "minimum": -9})
    test_generator_property(jschema)
  end

  property "test integer enum" do
    jschema = ~s({"type": "integer", "enum": [30, -11, 18, 75, 99, -65, null, "abc"]})
    test_generator_property(jschema)
  end

  property "test only enum" do
    jschema = ~s({"enum": [1, 2, "hello", -3, "world"]})
    test_generator_property(jschema)
  end

  property "test only enum with mix types" do
    jschema =
      ~s({"type": ["integer", "string"], "enum": [1, 2, "hello", -3, "world", null, true]})

    test_generator_property(jschema)
  end

  property "test boolean" do
    jschema = ~s({"type": "boolean"})
    test_generator_property(jschema)
  end

  property "test null" do
    jschema = ~s({"type": "null"})
    test_generator_property(jschema)
  end

  property "test notype" do
    jschema = ~s({"maxLength": 20, "minLength": 10, "minItems": 3})
    test_generator_property(jschema)
  end
end
