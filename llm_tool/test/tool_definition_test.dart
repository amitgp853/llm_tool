import 'dart:convert';

import 'package:llm_tool/llm_tool.dart';
import 'package:test/test.dart';

void main() {
  final weatherTool = ToolDefinition(
    name: 'getWeather',
    description: 'Gets the weather for a city.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'city': {'type': 'string'},
        'celsius': {'type': 'boolean'},
      },
      'required': ['city'],
    },
    execute: (args) {
      final celsius = args['celsius'] as bool? ?? true;
      return 'Sunny, ${celsius ? '31°C' : '88°F'} in ${args['city']}';
    },
  );

  group('validateArguments', () {
    final schema = weatherTool.parametersSchema;

    test('valid arguments return no errors', () {
      expect(validateArguments(schema, {'city': 'Kanpur'}), isEmpty);
    });

    test('valid optional argument returns no errors', () {
      expect(
        validateArguments(schema, {'city': 'Kanpur', 'celsius': false}),
        isEmpty,
      );
    });

    test('missing required argument is reported', () {
      expect(validateArguments(schema, {}), ['city is required']);
    });

    test('null required argument is reported', () {
      expect(validateArguments(schema, {'city': null}), ['city is required']);
    });

    test('wrong type is reported', () {
      expect(validateArguments(schema, {'city': 123}), [
        'city must be a string, got integer',
      ]);
    });

    test('unknown argument is reported', () {
      expect(validateArguments(schema, {'city': 'Kanpur', 'colour': 'red'}), [
        'colour is not a known argument',
      ]);
    });

    test('all errors are reported together', () {
      expect(validateArguments(schema, {'celsius': 'yes', 'colour': 'red'}), [
        'city is required',
        'celsius must be a boolean, got string',
        'colour is not a known argument',
      ]);
    });

    group('integer', () {
      final countSchema = {
        'type': 'object',
        'properties': {
          'count': {'type': 'integer'},
        },
      };

      test('accepts whole numbers sent as doubles (5.0)', () {
        expect(validateArguments(countSchema, {'count': 5.0}), isEmpty);
      });

      test('rejects fractional numbers with "an integer"', () {
        expect(validateArguments(countSchema, {'count': 5.5}), [
          'count must be an integer, got number',
        ]);
      });

      test('rejects infinity', () {
        expect(validateArguments(countSchema, {'count': double.infinity}), [
          'count must be an integer, got number',
        ]);
      });
    });

    group('enum', () {
      final unitSchema = {
        'type': 'object',
        'properties': {
          'unit': {
            'type': 'string',
            'enum': ['celsius', 'fahrenheit'],
          },
        },
      };

      test('accepts a listed value', () {
        expect(validateArguments(unitSchema, {'unit': 'celsius'}), isEmpty);
      });

      test('rejects an unlisted value and lists the allowed ones', () {
        expect(validateArguments(unitSchema, {'unit': 'kelvin'}), [
          'unit must be one of "celsius", "fahrenheit", got "kelvin"',
        ]);
      });

      test('is case-sensitive', () {
        expect(validateArguments(unitSchema, {'unit': 'Celsius'}), [
          'unit must be one of "celsius", "fahrenheit", got "Celsius"',
        ]);
      });

      test('wrong type reports the type error only', () {
        expect(validateArguments(unitSchema, {'unit': 1}), [
          'unit must be a string, got integer',
        ]);
      });

      test('enum without a type still works', () {
        final schema = {
          'type': 'object',
          'properties': {
            'level': {
              'enum': [1, 2, 3],
            },
          },
        };
        expect(validateArguments(schema, {'level': 2}), isEmpty);
        expect(validateArguments(schema, {'level': 4}), [
          'level must be one of 1, 2, 3, got 4',
        ]);
      });
    });

    group('array items', () {
      Map<String, Object?> listOf(Map<String, Object?> items) => {
        'type': 'object',
        'properties': {
          'tags': {'type': 'array', 'items': items},
        },
      };

      test('accepts matching items and an empty list', () {
        final schema = listOf({'type': 'string'});
        expect(
          validateArguments(schema, {
            'tags': ['a', 'b'],
          }),
          isEmpty,
        );
        expect(validateArguments(schema, {'tags': []}), isEmpty);
      });

      test('reports every wrong item with its index', () {
        expect(
          validateArguments(listOf({'type': 'string'}), {
            'tags': ['a', 1, true],
          }),
          [
            'tags[1] must be a string, got integer',
            'tags[2] must be a string, got boolean',
          ],
        );
      });

      test('null items are reported', () {
        expect(
          validateArguments(listOf({'type': 'string'}), {
            'tags': ['a', null],
          }),
          ['tags[1] must be a string, got null'],
        );
      });

      test('integer items accept whole doubles', () {
        expect(
          validateArguments(listOf({'type': 'integer'}), {
            'tags': [1, 2.0],
          }),
          isEmpty,
        );
      });

      test('enum items are checked', () {
        final schema = listOf({
          'type': 'string',
          'enum': ['red', 'green'],
        });
        expect(
          validateArguments(schema, {
            'tags': ['red', 'blue'],
          }),
          ['tags[1] must be one of "red", "green", got "blue"'],
        );
      });

      test('nested lists report the full path', () {
        final schema = listOf({
          'type': 'array',
          'items': {'type': 'integer'},
        });
        expect(
          validateArguments(schema, {
            'tags': [
              [1],
              [2, 'x'],
            ],
          }),
          ['tags[1][1] must be an integer, got string'],
        );
      });

      test('not a list is a type error, items are not checked', () {
        expect(validateArguments(listOf({'type': 'string'}), {'tags': 'a'}), [
          'tags must be an array, got string',
        ]);
      });

      test('array without items accepts anything inside', () {
        final schema = {
          'type': 'object',
          'properties': {
            'tags': {'type': 'array'},
          },
        };
        expect(
          validateArguments(schema, {
            'tags': [1, 'a', null],
          }),
          isEmpty,
        );
      });
    });

    group('nested objects', () {
      final passenger = {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
          'age': {'type': 'integer'},
          'nickname': {'type': 'string'},
        },
        'required': ['name', 'age'],
        'additionalProperties': false,
      };
      final schema = {
        'type': 'object',
        'properties': {
          'passenger': passenger,
          'group': {'type': 'array', 'items': passenger},
        },
      };

      test('accepts a valid object, optional fields can be missing', () {
        expect(
          validateArguments(schema, {
            'passenger': {'name': 'Asha', 'age': 30},
          }),
          isEmpty,
        );
      });

      test('reports missing, unknown and wrong fields with their path', () {
        expect(
          validateArguments(schema, {
            'passenger': {'age': 'thirty', 'seat': '4A'},
          }),
          [
            'passenger.name is required',
            'passenger.age must be an integer, got string',
            'passenger.seat is not a known field',
          ],
        );
      });

      test('null for a required field is reported, for optional is fine', () {
        expect(
          validateArguments(schema, {
            'passenger': {'name': null, 'age': 3, 'nickname': null},
          }),
          ['passenger.name is required'],
        );
      });

      test('objects inside lists report index and field', () {
        expect(
          validateArguments(schema, {
            'group': [
              {'name': 'Asha', 'age': 30},
              {'name': 'Ravi'},
            ],
          }),
          ['group[1].age is required'],
        );
      });

      test('not an object is a type error, fields are not checked', () {
        expect(validateArguments(schema, {'passenger': 'Asha'}), [
          'passenger must be an object, got string',
        ]);
      });

      test('top-level messages are unchanged', () {
        expect(validateArguments(schema, {'seat': '4A'}), [
          'seat is not a known argument',
        ]);
      });
    });

    test('malformed property schema does not crash', () {
      final badSchema = {
        'type': 'object',
        'properties': {'city': 'string'},
      };
      expect(validateArguments(badSchema, {'city': 'Kanpur'}), isEmpty);
    });

    group('limits', () {
      Map<String, Object?> one(Map<String, Object?> property) => {
        'type': 'object',
        'properties': {'x': property},
      };
      List<String> check(Map<String, Object?> property, Object? x) =>
          validateArguments(one(property), {'x': x});

      test('minimum and maximum are inclusive', () {
        final age = {'type': 'integer', 'minimum': 0, 'maximum': 130};
        expect(check(age, 0), isEmpty);
        expect(check(age, 130), isEmpty);
        expect(check(age, -1), ['x must be at least 0, got -1']);
        expect(check(age, 131), ['x must be at most 130, got 131']);
        // A whole number sent as 131.0 reads as 131.
        expect(check(age, 131.0), ['x must be at most 130, got 131']);
      });

      test('decimal limits', () {
        final ratio = {'type': 'number', 'minimum': 0.5, 'maximum': 1.5};
        expect(check(ratio, 0.75), isEmpty);
        expect(check(ratio, 0.25), ['x must be at least 0.5, got 0.25']);
      });

      test('string length counts characters', () {
        final name = {'type': 'string', 'minLength': 2, 'maxLength': 3};
        expect(check(name, 'ab'), isEmpty);
        // One emoji is two UTF-16 units but one character.
        expect(check(name, '😀😀'), isEmpty);
        expect(check(name, 'a'), ['x must be at least 2 characters, got 1']);
        expect(check(name, 'abcd'), ['x must be at most 3 characters, got 4']);
        expect(check({'type': 'string', 'maxLength': 1}, 'ab'), [
          'x must be at most 1 character, got 2',
        ]);
      });

      test('pattern finds a match anywhere unless anchored', () {
        expect(check({'type': 'string', 'pattern': '[0-9]'}, 'a1b'), isEmpty);
        final square = {'type': 'string', 'pattern': r'^[a-h][1-8]$'};
        expect(check(square, 'e4'), isEmpty);
        expect(check(square, 'e44'), [
          r'x must match the pattern ^[a-h][1-8]$, got "e44"',
        ]);
      });

      test('an invalid pattern is ignored, not a crash', () {
        expect(check({'type': 'string', 'pattern': '('}, 'a'), isEmpty);
      });

      test('minItems and maxItems', () {
        final tags = {
          'type': 'array',
          'items': {'type': 'string'},
          'minItems': 1,
          'maxItems': 2,
        };
        expect(check(tags, ['a']), isEmpty);
        expect(check(tags, []), ['x must have at least 1 item, got 0']);
        expect(check(tags, ['a', 'b', 'c']), [
          'x must have at most 2 items, got 3',
        ]);
      });

      test('item limits name the item', () {
        final scores = {
          'type': 'array',
          'items': {'type': 'integer', 'minimum': 0, 'maximum': 100},
        };
        expect(check(scores, [50, 101, -1]), [
          'x[1] must be at most 100, got 101',
          'x[2] must be at least 0, got -1',
        ]);
      });

      test('limits are not checked after a type error', () {
        expect(check({'type': 'integer', 'minimum': 5}, 'one'), [
          'x must be an integer, got string',
        ]);
      });
    });
  });

  group('withoutAdditionalProperties', () {
    test('removes it at every level and leaves the input unchanged', () {
      final schema = <String, Object?>{
        'type': 'object',
        'properties': {
          'passenger': {
            'type': 'object',
            'properties': {
              'name': {'type': 'string'},
            },
            'additionalProperties': false,
          },
          'group': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': <String, Object?>{},
              'additionalProperties': false,
            },
          },
        },
        'required': ['passenger'],
        'additionalProperties': false,
      };
      final copy = jsonEncode(schema);

      expect(withoutAdditionalProperties(schema), {
        'type': 'object',
        'properties': {
          'passenger': {
            'type': 'object',
            'properties': {
              'name': {'type': 'string'},
            },
          },
          'group': {
            'type': 'array',
            'items': {'type': 'object', 'properties': <String, Object?>{}},
          },
        },
        'required': ['passenger'],
      });
      expect(jsonEncode(schema), copy, reason: 'input must not change');
    });

    test('a field named additionalProperties is kept', () {
      final schema = <String, Object?>{
        'type': 'object',
        'properties': {
          'additionalProperties': {'type': 'string'},
        },
        'additionalProperties': false,
      };
      expect(withoutAdditionalProperties(schema), {
        'type': 'object',
        'properties': {
          'additionalProperties': {'type': 'string'},
        },
      });
    });
  });

  group('ToolDefinition.call', () {
    test('runs the tool when arguments are valid', () async {
      expect(await weatherTool({'city': 'Kanpur'}), 'Sunny, 31°C in Kanpur');
    });

    test('uses the optional argument when given', () async {
      expect(
        await weatherTool({'city': 'Kanpur', 'celsius': false}),
        'Sunny, 88°F in Kanpur',
      );
    });

    test('throws ToolArgumentException for invalid arguments', () {
      expect(
        () => weatherTool({'city': 123}),
        throwsA(isA<ToolArgumentException>()),
      );
    });

    test('exception contains the tool name and errors', () async {
      try {
        await weatherTool({});
        fail('Expected ToolArgumentException');
      } on ToolArgumentException catch (e) {
        expect(e.toolName, 'getWeather');
        expect(e.errors, ['city is required']);
      }
    });

    test('does not run execute when arguments are invalid', () async {
      var ran = false;
      final tracked = ToolDefinition(
        name: 'tracked',
        description: 'Records whether it ran.',
        parametersSchema: weatherTool.parametersSchema,
        execute: (args) => ran = true,
      );

      await expectLater(
        () => tracked({}),
        throwsA(isA<ToolArgumentException>()),
      );
      expect(ran, isFalse);
    });
  });
}
