import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:portico_auth_storage_yaml/src/extensions.dart';

void main() {
  group('Yaml Extensions', () {
    test('YamlMap.asMap converts nested structures', () {
      final yaml =
          loadYaml('''
key: value
nested_map:
  a: 1
  b: 2
nested_list:
  - 1
  - 2
  - c: 3
''')
              as YamlMap;

      final map = yaml.asMap;
      expect(map['key'], 'value');
      expect(map['nested_map'], isA<Map>());
      expect((map['nested_map'] as Map)['a'], 1);
      expect(map['nested_list'], isA<List>());
      expect((map['nested_list'] as List)[0], 1);
      expect((map['nested_list'] as List)[2], isA<Map>());
      expect(((map['nested_list'] as List)[2] as Map)['c'], 3);
    });

    test('YamlList.asList converts nested structures', () {
      final yaml =
          loadYaml('''
- item1
- a: 1
- - 2
  - 3
''')
              as YamlList;

      final list = yaml.asList;
      expect(list[0], 'item1');
      expect(list[1], isA<Map>());
      expect((list[1] as Map)['a'], 1);
      expect(list[2], isA<List>());
      expect((list[2] as List)[0], 2);
    });

    test('DateConverter works', () {
      const converter = DateConverter();
      final date = DateTime.utc(2023, 1, 1);
      final json = converter.toJson(date);
      expect(json, '2023-01-01T00:00:00.000Z');
      expect(converter.fromJson(json), date);
    });
  });
}
