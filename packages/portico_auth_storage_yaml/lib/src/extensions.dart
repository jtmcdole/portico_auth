import 'package:json_annotation/json_annotation.dart';
import 'package:yaml/yaml.dart';

class DateConverter implements JsonConverter<DateTime, String> {
  const DateConverter();

  @override
  DateTime fromJson(String timestamp) {
    return DateTime.parse(timestamp);
  }

  @override
  String toJson(DateTime date) => date.toIso8601String();
}

extension YamlMapToMap on YamlMap {
  Map<String, Object?> get asMap => <String, Object?>{
    for (final MapEntry(:key, :value) in nodes.entries)
      if (value is YamlMap)
        '${key.value}': value.asMap
      else if (value is YamlList)
        '${key.value}': value.asList
      else
        '${key.value}': value.value,
  };
}

extension YamlListToList on YamlList {
  List<Object?> get asList => <Object?>[
    for (final value in nodes)
      if (value is YamlMap)
        value.asMap
      else if (value is YamlList)
        value.asList
      else
        value.value,
  ];
}
