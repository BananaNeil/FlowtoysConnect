import 'dart:convert';

class Mode {
  bool isAdjusting;
  num saturation;
  num brightness;
  num modeListId;
  num position;
  num density;
  String name;
  num number;
  num speed;
  num page;
  num hue;
  num id;

  Mode({
    this.isAdjusting,
    this.saturation,
    this.brightness,
    this.modeListId,
    this.position,
    this.density,
    this.number,
    this.speed,
    this.page,
    this.name,
    this.hue,
    this.id,
  });

  Map<String, dynamic> toMap() {
    return {
      'is_adjusting': isAdjusting,
      'mode_list_id': modeListId,
      'saturation': saturation,
      'brightness': brightness,
      'position': position,
      'density': density,
      'number': number,
      'speed': speed,
      'page': page,
      'name': name,
      'hue': hue,
    } as Map;
  }

  factory Mode.fromMap(Map<String, dynamic> body) {
    var json = body;
    return Mode(
      isAdjusting: json['is_adjusting'],
      modeListId: json['mode_list_id'],
      saturation: json['saturation'],
      brightness: json['brightness'],
      position: json['position'],
      density: json['density'],
      number: json['number'],
      speed: json['speed'],
      page: json['page'],
      name: json['name'],
      hue: json['hue'],
      id: json['id'],
    );
  }

  factory Mode.fromJson(String body) {
    return Mode.fromMap(jsonDecode(body));
  }
}


