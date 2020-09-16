import 'package:app/models/mode_param.dart';
import 'package:app/app_controller.dart';
import 'package:app/models/group.dart';
import 'dart:convert';

class Mode {
  String accessLevel;
  bool isAdjusting;
  num modeListId;
  num baseModeId;
  num position;
  String name;
  num number;
  num page;
  num id;

  ModeParam saturation;
  ModeParam brightness;
  ModeParam density;
  ModeParam speed;
  ModeParam hue;

  Mode({
    this.accessLevel,
    this.isAdjusting,
    this.saturation,
    this.brightness,
    this.modeListId,
    this.baseModeId,
    this.position,
    this.density,
    this.number,
    this.speed,
    this.page,
    this.name,
    this.hue,
    this.id,
  });

  Map<String, ModeParam> get modeParams {
    return {
      'saturation': saturation,
      'brightness': brightness,
      'density': density,
      'speed': speed,
      'hue': hue,
    };
  }

  num getValue(param, {groupIndex, propIndex}) {
    return getParam(param).getValue(indexes: [groupIndex, propIndex]);
  }

  ModeParam getParam(param, {groupIndex, propIndex}) {
    var modeParam = modeParams[param];
    if (groupIndex != null) {
      modeParam = modeParam.childParamAt(groupIndex);
    }
    if (propIndex != null) modeParam = modeParam.childParamAt(propIndex);
    return modeParam;
  }

  void updateBaseModeId(id) {
    var currentBaseMode = AppController.getBaseMode(baseModeId);
    var baseMode = AppController.getBaseMode(id);

    if (name == currentBaseMode.name) name = baseMode.name;
    number = baseMode.number;
    page = baseMode.page;
    baseModeId = id;
  }

  Map<String, dynamic> toMap() {
    return {
      'access_level': accessLevel,
      'is_adjusting': isAdjusting,
      'mode_list_id': modeListId,
      'base_mode_id': baseModeId,
      'position': position,
      'number': number,
      'page': page,
      'name': name,

      'saturation': saturation.toMap(),
      'brightness': brightness.toMap(),
      'density': density.toMap(),
      'speed': speed.toMap(),
      'hue': hue.toMap(),
    } as Map;
  }

  factory Mode.fromMap(Map<String, dynamic> body) {
    var json = body;
    return Mode(
      saturation: ModeParam.fromMap(json['saturation'], childType: 'group'),
      brightness: ModeParam.fromMap(json['brightness'], childType: 'group'),
      density: ModeParam.fromMap(json['density'], childType: 'group'),
      speed: ModeParam.fromMap(json['speed'], childType: 'group'),
      hue: ModeParam.fromMap(json['hue'], childType: 'group'),

      accessLevel: json['access_level'],
      isAdjusting: json['is_adjusting'],
      modeListId: json['mode_list_id'],
      baseModeId: json['base_mode_id'],
      position: json['position'],
      number: json['number'],
      page: json['page'],
      name: json['name'],
      id: json['id'],
    );
  }

  factory Mode.fromJson(String body) {
    return Mode.fromMap(jsonDecode(body));
  }
}

