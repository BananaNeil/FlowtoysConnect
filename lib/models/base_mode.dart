import 'package:json_api/document.dart';
import 'dart:convert';

class BaseMode {
  String name;
  num number;
  num page;
  num id;

  BaseMode({
    this.number,
    this.page,
    this.name,
    this.id,
  });

  Map<String, dynamic> toMap() {
    return {
      'number': number,
      'page': page,
      'name': name,
      'id': id,
    } as Map;
  }

  factory BaseMode.fromMap(Map<String, dynamic> body) {
    var json = body;
    return BaseMode(
      number: json['number'],
      page: json['page'],
      name: json['name'],
      id: json['id'],
    );
  }

  factory BaseMode.fromResource(Resource resource, {included}) {
    return BaseMode.fromMap(resource.attributes);
  }

  static List<BaseMode> fromList(Map<String, dynamic> json) {
    var data = ResourceCollectionData.fromJson(json);
    return data.collection.map((object) {
      return BaseMode.fromMap(object.unwrap().attributes);
    }).toList();
  }

  factory BaseMode.fromJson(String body) {
    return BaseMode.fromMap(jsonDecode(body));
  }
}
