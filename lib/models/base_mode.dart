import 'package:json_api/document.dart';
import 'package:app/client.dart';
import 'dart:convert';

class BaseMode {
  Map<String, dynamic> images;
  num brightness;
  num saturation;
  String name;
  num number;
  num page;
  num hue;
  num id;

  BaseMode({
    this.saturation,
    this.brightness,
    this.images,
    this.number,
    this.page,
    this.name,
    this.hue,
    this.id,
  });

  String get thumbnailPath => (images['club'] ?? {})['thumb'];
  String get imagePath => (images['club'] ?? {})['medium'];
  String get thumbnail => "${Client.host}${thumbnailPath}";
  String get image => "${Client.host}${imagePath}";

  String get trailImagePath => (images['trail'] ?? {})['medium'];
  String get trailImage => "${Client.host}${trailImagePath}";

  num getValue(param) {
    return {
      'brightness': brightness,
      'saturation': saturation,
      'hue': hue,
    }[param];
  }

  Map<String, dynamic> toMap() {
    return {
      'brightness': brightness,
      'saturation': saturation,
      'images': images,
      'number': number,
      'page': page,
      'name': name,
      'hue': hue,
      'id': id,
    } as Map;
  }

  ResourceObject toResource() {
    return ResourceObject('base_mode', id.toString(), attributes: toMap(), relationships: {});
  }

  static String toJson(List<BaseMode> modes) {
    return jsonEncode({
      'data': modes.map((mode) => mode.toResource()).toList(),
    });
  }

  factory BaseMode.fromMap(Map<String, dynamic> body) {
    var json = body;
    return BaseMode(
      saturation: json['saturation'],
      brightness: json['brightness'],
      images: json['images'] ?? {},
      number: json['number'],
      page: json['page'],
      name: json['name'],
      hue: json['hue'],
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
