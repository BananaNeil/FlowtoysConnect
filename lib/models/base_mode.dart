import 'package:json_api/document.dart';
import 'package:app/client.dart';
import 'dart:convert';

class BaseMode {
  Map<String, dynamic> images;
  String description;
  bool stallReactive;
  bool bumpReactive;
  bool spinReactive;
  int adjustCycles;
  num brightness;
  num saturation;
  num density;
  String name;
  num number;
  num speed;
  String id;
  num page;
  num hue;

  BaseMode({
    this.stallReactive,
    this.bumpReactive,
    this.spinReactive,
    this.adjustCycles,
    this.description,
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
  }) {
    this.adjustCycles ??= 1;
  }

  String get thumbnail => Client.url((images['club'] ?? {})['thumb'] ?? defaultImage);
  String get image => Client.url((images['club'] ?? {})['medium'] ?? defaultImage);
  // ..... change this later?
  String get defaultImage => "";

  String get trailImage => Client.url((images['trail'] ?? {})['medium']);

  bool get motionReactive => stallReactive || bumpReactive || spinReactive;

  num getValue(param) {
    return {
      'brightness': brightness,
      'saturation': saturation,
      'density': density,
      'speed': speed,
      'adjust': 0.0,
      'hue': hue,
    }[param];
  }

  Map<String, dynamic> toMap() {
    return {
      'stall_reactive': stallReactive,
      'bump_reactive': bumpReactive,
      'spin_reactive': spinReactive,
      'adjust_cycles': adjustCycles,
      'description': description,
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
      stallReactive: json['stall_reactive'] ?? false,
      spinReactive: json['spin_reactive'] ?? false,
      bumpReactive: json['bump_reactive'] ?? false,
      adjustCycles: json['adjust_cycles'] ?? 1,
      description: json['description'] ?? "",
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
      name: 'Mode',
      saturation: 0.5,
      brightness: 0.5,
      density: 0.5,
      speed: 0.5,
      images: {},
      hue: 0.5,
    );
  }
}
