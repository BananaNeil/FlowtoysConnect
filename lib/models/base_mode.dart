import 'package:json_api/document.dart';
import 'package:app/client.dart';
import 'dart:convert';

class BaseMode {
  Map<String, dynamic> images;
  num brightness;
  num saturation;
  num density;
  String name;
  num number;
  num speed;
  num page;
  num hue;
  num id;

  BaseMode({
    this.saturation,
    this.brightness,
    this.density,
    this.images,
    this.number,
    this.speed,
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
      'density': density,
      'speed': speed,
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
      density: json['density'],
      number: json['number'],
      speed: json['speed'],
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

  factory BaseMode.basic() {
    return BaseMode(
      name: 'Rainbow',
      saturation: 0.5,
      brightness: 0.5,
      density: 0.5,
      speed: 0.5,
      images: {},
      hue: 0.5,
    );
  }
}
