import 'package:app/models/mode_param.dart';
import 'package:app/models/base_mode.dart';
import 'package:app/app_controller.dart';
import 'package:json_api/document.dart';
import 'package:app/models/group.dart';
import 'package:flutter/material.dart';
import 'package:app/preloader.dart';
import 'package:app/client.dart';
import 'dart:convert';

class Mode {
  bool get isPersisted => id != null;

  String get thumbnailPath => (images['club'] ?? {})['thumb'];
  String get imagePath => (images['club'] ?? {})['medium'];
  String get thumbnail => "${Client.host}${thumbnailPath}";
  String get image => "${Client.host}${imagePath}";

  String get trailImagePath => (images['trail'] ?? {})['medium'];
  String get trailImage => "${Client.host}${trailImagePath}";

  bool get hasTrailImage => trailImagePath != null;

  Map<String, dynamic> get images => baseMode.images;
  String accessLevel;
  String parentType;
  String baseModeId;
  bool isAdjusting;
  String parentId;
  num position;
  String name;
  num number;
  String id;
  num page;

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
    this.baseModeId,
    this.parentType,
    this.parentId,
    this.position,
    this.density,
    this.number,
    this.speed,
    this.page,
    this.name,
    this.hue,
    this.id,
  });

  Map<String, ModeParam> get colorModeParams {
    return {
      'saturation': saturation,
      'brightness': brightness,
      'hue': hue,
    };
  }

  Map<String, ModeParam> get modeParams {
    return {
      'saturation': saturation,
      'brightness': brightness,
      'density': density,
      'speed': speed,
      'hue': hue,
    };
  }

  void resetParam(name) {
    modeParams[name].multiValueEnabled = false;
    modeParams[name].value = initialValue(name);
  }

  void resetToBaseMode() {
    modeParams.keys.forEach((key) {
      resetParam(key);
    });
  }

  void assignAttributesFromCopy(copy) {
    var json = copy.toFullMap();

    saturation = ModeParam.fromModeMap(json, 'saturation');
    brightness = ModeParam.fromModeMap(json, 'brightness');
    density = ModeParam.fromModeMap(json, 'density');
    speed = ModeParam.fromModeMap(json, 'speed');
    hue = ModeParam.fromModeMap(json, 'hue');
    baseModeId = json['base_mode_id'];
  }

  Future<Map<dynamic, dynamic>> updateFromCopy(copy) {
    assignAttributesFromCopy(copy);
    return this.save();
  }

  void setAsBlack() {
    brightness.multiValueEnabled = false;
    brightness.value = 0.0;
  }

  bool get isBlackMode {
    return !brightness.multiValueEnabled && brightness.value == 0.0;
  }

  Future<Map<dynamic, dynamic>> save() {
    var method = (id == null) ? Client.createMode : Client.updateMode;
    return method(this).then((response) {
      if (response['success']) {
        this.id = id ?? response['mode'].id;
        // assignAttributesFromCopy(response['mode']); // This isn't really necessary, but seems right for good measure?
        response['mode'] = this;
      } else {
        print("FAIL SAVE MODE: ${response['message']}");
      }
      // else Fail some how?
      return response;
    });
  }

  Mode dup() {
    var attributes = toFullMap();
    attributes['id'] = null;
    return Mode.fromMap(attributes);
  }

  Map<String, num> getParamValues({groupIndex, propIndex}) {
    return {
      'hue': getValue('hue', groupIndex: groupIndex, propIndex: propIndex),
      'saturation': getValue('saturation', groupIndex: groupIndex, propIndex: propIndex),
      'brightness': getValue('brightness', groupIndex: groupIndex, propIndex: propIndex),
    };
  }

  bool get isMultivalue => colorModeParams.values.any((param) => !!param.multiValueActive);

  HSVColor getHSVColor({groupIndex, propIndex}) {
    HSVColor color = HSVColor.fromColor(Colors.blue);
    var hue = getValue('hue', groupIndex: groupIndex, propIndex: propIndex);
    var saturation = getValue('saturation', groupIndex: groupIndex, propIndex: propIndex);
    var brightness = getValue('brightness', groupIndex: groupIndex, propIndex: propIndex);
    return color.withHue(hue * 360 % 360).withSaturation(saturation).withValue(brightness);
  }

  Color getColor({groupIndex, propIndex}) {
    return getHSVColor(groupIndex: groupIndex, propIndex: propIndex).toColor();
  }

  num getValue(param, {groupIndex, propIndex}) {
    return getParam(param).getValue(indexes: [groupIndex, propIndex]);
  }

  num initialValue(param) {
    return baseMode.getValue(param);
  }

  Map<String, BaseMode> _baseMode = {};
  BaseMode get baseMode {
    return _baseMode[baseModeId] ??=
      Preloader.baseModes.firstWhere((bm) {
        return baseModeId == bm.id;
      }, orElse: () {
        return BaseMode.basic();
      });
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
    if (!hue.multiValueActive) hue.setValue(baseMode.hue);
    number = baseMode.number;
    page = baseMode.page;
    baseModeId = id;
  }

  Map<String, dynamic> toMap() {
    return Map.from(toFullMap())..removeWhere((k, v) {
      return ![
        'is_adjusting',
        'base_mode_id',
        'parent_type',
        'parent_id',
        'position',
        'id',

        'saturation',
        'brightness',
        'density',
        'speed',
        'hue',
      ].contains(k);
    });
  }

  Map<String, dynamic> toFullMap() {
    return {
      'access_level': accessLevel,
      'is_adjusting': isAdjusting,
      'base_mode_id': baseModeId,
      'parent_type': parentType,
      'parent_id': parentId,
      'position': position,
      'number': number,
      'page': page,
      'name': name,
      'id': id,

      'saturation': saturation.toMap(),
      'brightness': brightness.toMap(),
      'density': density.toMap(),
      'speed': speed.toMap(),
      'hue': hue.toMap(),
    } as Map;
  }

  ResourceObject toResource() {
    return ResourceObject('mode', id.toString(), attributes: toFullMap());
  }

  void setModeOnParams() {
    modeParams.values.forEach((param) => param.setMode(this));
  }

  factory Mode.fromMap(Map<String, dynamic> body) {
    var json = body;
    var mode = Mode(
      saturation: ModeParam.fromModeMap(json, 'saturation'),
      brightness: ModeParam.fromModeMap(json, 'brightness'),
      density: ModeParam.fromModeMap(json, 'density'),
      speed: ModeParam.fromModeMap(json, 'speed'),
      hue: ModeParam.fromModeMap(json, 'hue'),
      baseModeId: json['base_mode_id'],

      accessLevel: json['access_level'],
      isAdjusting: json['is_adjusting'],
      parentType: json['parent_type'],
      parentId: json['parent_id'],
      position: json['position'],
      number: json['number'],
      page: json['page'],
      name: json['name'],
      id: json['id'],
    );

    mode.setModeOnParams();

    return mode;
  }

  factory Mode.fromJson(String body) {
    return Mode.fromMap(jsonDecode(body));
  }
}


