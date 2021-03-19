import 'package:app/models/mode_param.dart';
import 'package:app/models/base_mode.dart';
import 'package:app/app_controller.dart';
import 'package:json_api/document.dart';
import 'package:app/models/group.dart';
import 'package:flutter/material.dart';
import 'package:app/preloader.dart';
import 'package:app/client.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math';

class Mode {
  bool get isPersisted => id != null;

  String get image => Client.url((images['club'] ?? {})['medium'] ?? defaultImage);
  String get thumbnail => Client.url((images['club'] ?? {})['thumb'] ?? defaultImage);
  String get defaultImage => baseMode.defaultImage;

  String get trailImage {
    return Client.url((images['trail'] ?? {})['medium']);
  }

  bool get hasTrailImage => trailImage != null;

  Map<String, dynamic> get images => baseMode.images;
  bool adjustRandomized;
  String accessLevel;
  bool bypassParams; 
  String parentType;
  String baseModeId;
  bool isAdjusting;
  String parentId;
  num position;
  String name;
  num number;
  String id;
  num page;

  Timer saveTimer;

  ModeParam saturation;
  ModeParam brightness;
  ModeParam density;
  ModeParam adjust;
  ModeParam speed;
  ModeParam hue;

  Mode({
    this.adjustRandomized,
    this.bypassParams,
    this.accessLevel,
    this.isAdjusting,
    this.saturation,
    this.brightness,
    this.baseModeId,
    this.parentType,
    this.parentId,
    this.position,
    this.density,
    this.adjust,
    this.number,
    this.speed,
    this.page,
    this.name,
    this.hue,
    this.id,
  }) {
    this.adjustRandomized ??= false;
    this.bypassParams ??= false;
    this.isAdjusting ??= false;
  }

  static bool globalParamsEnabled = false;
  static Mode _global;
  static Mode get global => _global ??= Mode.basic();
  static Map<String, dynamic> get globalParamValues {
    return global.getParamValues();
  }

  static Map<String, dynamic> get globalParamRatios {
    var params = globalParamValues;
    params.keys.forEach((name) {
      if (!global.booleanParams.keys.contains(name)) {
        var defaultValue = Mode.global.baseMode.getValue(name);
        if (defaultValue != null && defaultValue != 0)
          params[name] /= defaultValue.toDouble();
      }
    });
    return params;
  }

  Map<String, bool> get booleanParams {
    return {
      'isAdjusting': isAdjusting,
      'adjustRandomized': adjustRandomized,
    };
  }

  Map<String, ModeParam> get colorModeParams {
    return {
      'saturation': saturation,
      'brightness': brightness,
      'hue': hue,
    };
  }

  String get childType => brightness.childType;
  int get childCount => brightness.childCount;
  int get groupIndex => brightness.groupIndex;
  int get propIndex => brightness.propIndex;

  Map<String, ModeParam> _modeParams;
  Map<String, ModeParam> get modeParams {
    return _modeParams ??= {
      'saturation': saturation,
      'brightness': brightness,
      'density': density,
      'adjust': adjust,
      'speed': speed,
      'hue': hue,
    };
  }

  void resetParam(name) {
    modeParams[name].animationSpeed = 0.0;
    modeParams[name].multiValueEnabled = false;
    modeParams[name].value = initialValue(name);
  }

  void resetToBaseMode() {
    modeParams.keys.forEach((key) {
      resetParam(key);
    });
  }

  void setAsSubMode({propIndex, groupIndex}) {
    saturation = getParam('saturation', propIndex: propIndex, groupIndex: groupIndex);
    brightness = getParam('brightness', propIndex: propIndex, groupIndex: groupIndex);
    density = getParam('density', propIndex: propIndex, groupIndex: groupIndex);
    adjust = getParam('adjust', propIndex: propIndex, groupIndex: groupIndex);
    speed = getParam('speed', propIndex: propIndex, groupIndex: groupIndex);
    hue = getParam('hue', propIndex: propIndex, groupIndex: groupIndex);
  }

  void assignAttributesFromCopy(copy) {
    var json = copy.toFullMap();

    saturation = ModeParam.fromModeMap(json, 'saturation', this);
    brightness = ModeParam.fromModeMap(json, 'brightness', this);
    density = ModeParam.fromModeMap(json, 'density', this);
    adjust = ModeParam.fromModeMap(json, 'adjust', this);
    speed = ModeParam.fromModeMap(json, 'speed', this);
    hue = ModeParam.fromModeMap(json, 'hue', this);
    baseModeId = json['base_mode_id'];
    name = json['name'];
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
    saveTimer?.cancel();
    var completer = Completer<Map<dynamic, dynamic>>();
    saveTimer = Timer(Duration(seconds: 1), () {
      var method = (id == null) ? Client.createMode : Client.updateMode;
      method(this).then((response) {
        if (response['success']) {
          this.id = response['mode'].id ?? id;
          // assignAttributesFromCopy(response['mode']); // This isn't really necessary, but seems right for good measure?
          response['id'] = id;
          response['mode'] = this;

        } else {
          print("FAIL SAVE MODE: ${response['message']}");
        }
        // else Fail some how?
        completer.complete(response);
        return response;
      });
    });
    return completer.future;
  }

  Mode dup() {
    var attributes = toFullMap();
    attributes['id'] = null;
    attributes['access_level'] = 'editable';
    attributes['parent_type'] = null;
    attributes['parent_id'] = null;
    return Mode.fromMap(attributes);
  }

  int get adjustCycles => baseMode.adjustCycles;
  Map<String, dynamic> getParamValues({groupIndex, propIndex}) {
    return {
      'isAdjusting': isAdjusting,
      'adjustRandomized': adjustRandomized,
      'adjustCycles': 4,//adjustCycles.toDouble(),
      'adjust': getValue('adjust', groupIndex: groupIndex, propIndex: propIndex),
      'saturation': getValue('saturation', groupIndex: groupIndex, propIndex: propIndex),
      'brightness': getValue('brightness', groupIndex: groupIndex, propIndex: propIndex),
      'density': getValue('density', groupIndex: groupIndex, propIndex: propIndex),
      'speed': getValue('speed', groupIndex: groupIndex, propIndex: propIndex),
      'hue': getValue('hue', groupIndex: groupIndex, propIndex: propIndex),
    };
  }

  bool get isMultivalue => modeParams.values.any((param) => !!param.multiValueActive);
  bool get colorIsMultivalue => colorModeParams.values.any((param) => !!param.multiValueActive);

  void recursivelySetMultiValue() {
    modeParams.values.forEach((param) => param.recursivelySetMultiValue());
  }

  HSVColor getHSVColor({groupIndex, propIndex}) {
    HSVColor color = HSVColor.fromColor(Colors.blue);
    if (childType == 'prop') groupIndex = null;

    var hue = getValue('hue', groupIndex: groupIndex, propIndex: propIndex);
    var saturation = getValue('saturation', groupIndex: groupIndex, propIndex: propIndex);
    var brightness = getValue('brightness', groupIndex: groupIndex, propIndex: propIndex);
    return color.withHue(hue * 360 % 360).withSaturation(saturation).withValue(brightness);
  }

  Color getColor({groupIndex, propIndex}) {
    return getHSVColor(groupIndex: groupIndex, propIndex: propIndex).toColor();
  }

  bool get isAnimating {
    return modeParams.values.any((param) => param.isAnimating || param.linkAudio);
  }

  bool get colorIsAnimating {
    return colorModeParams.values.any((param) => param.isAnimating);
  }

  double getAnimationSpeed(param, {groupIndex, propIndex}) {
    return getParam(param, groupIndex: groupIndex, propIndex: propIndex).animationSpeed ?? 0.0;
  }

  void setAnimationSpeed(param, speed) {
    getParam(param).animationSpeed = speed.clamp(-1.0, 1.0);
  }

  num getValue(param, {groupIndex, propIndex}) {
    return getParam(param).getValue(indexes: [groupIndex, propIndex]);
  }

  num initialValue(param) {
    return baseMode.getValue(param);
  }

  bool get motionReactive => baseMode.motionReactive;
  bool get stallReactive => baseMode.stallReactive;
  bool get bumpReactive => baseMode.bumpReactive;
  bool get spinReactive => baseMode.spinReactive;

  // I don't think you need this null safty::::::
  String get description => baseMode.description ?? "";

  Map<String, bool> _booleanAttributes;
  Map<String, bool> get booleanAttributes {
    return _booleanAttributes ??= {
      'motionReactive': motionReactive,
      'stallReactive': stallReactive,
      'bumpReactive': bumpReactive,
      'spinReactive': spinReactive,
    };
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

  void setParam(paramName, newParam, {groupIndex, propIndex}) {
    var param = getParam(paramName);
    if (groupIndex == null)
      modeParams[paramName] = newParam;
    else if (propIndex == null) {
      // this line makes sure that the param exists before overriding it
      var groupParam = param.childParamAt(groupIndex);
      param.childParams[groupIndex] = newParam;
    } else {
      var groupParam = param.childParamAt(groupIndex);
      // this line makes sure that the param exists before overriding it
      var propParam = groupParam.childParamAt(propIndex);
      groupParam.childParams[propIndex] = newParam;
    }
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
      return [
        'access_level',
        'number',
        'page',
      ].contains(k);
    });
  }

  Map<String, dynamic> toFullMap() {
    return {
      'adjust_randomized': adjustRandomized,
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
      'adjust': adjust.toMap(),
      'speed': speed.toMap(),
      'hue': hue.toMap(),
    } as Map;
  }

  ResourceObject toResource() {
    return ResourceObject('mode', id.toString(), attributes: toFullMap());
  }

  factory Mode.fromSiblings(siblings, {show}) {
    if (siblings.first == null) return null;



    var attributes = siblings.first.toFullMap();
    var mode = Mode.fromMap(attributes);
    siblings.first.modeParams.keys.forEach((paramName) {
      eachWithIndex(siblings, (index, sibling) {
        var groupIndex = show.groupIndexFromGlobalPropIndex(index);
        var propIndex = show.localPropIndexFromGlobalPropIndex(index);
        var value = sibling.getValue(paramName, groupIndex: groupIndex, propIndex: propIndex);
        mode.getParam(paramName,
          groupIndex: groupIndex,
          propIndex: propIndex,
        ).setValue(value);
      });
      mode.modeParams[paramName].recursivelySetMultiValue();
    });
    return mode;
  }

  factory Mode.basic({page, number}) {
    var baseMode;
    return Mode.fromMap({
      'page': page,
      'number': number,
      'hue': { 'value': 0.5 },
      'speed': { 'value': 0.5 },
      'adjust': { 'value': 0.0 },
      'density': { 'value': 0.5 },
      'saturation': { 'value': 0.5 },
      'brightness': { 'value': 0.5 },
      'accessLevel': 'editable',
      'base_mode_id': 'BASE',
    });
  }

  factory Mode.fromMap(Map<String, dynamic> body) {
    var json = body;
    var mode = Mode(
      baseModeId: json['base_mode_id'],

      adjustRandomized: json['adjust_randomized'],
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
    mode.saturation = ModeParam.fromModeMap(json, 'saturation', mode);
    mode.brightness = ModeParam.fromModeMap(json, 'brightness', mode);
    mode.density = ModeParam.fromModeMap(json, 'density', mode);
    mode.adjust = ModeParam.fromModeMap(json, 'adjust', mode);
    mode.speed = ModeParam.fromModeMap(json, 'speed', mode);
    mode.hue = ModeParam.fromModeMap(json, 'hue', mode);


    return mode;
  }

  factory Mode.fromJson(String body) {
    return Mode.fromMap(jsonDecode(body));
  }
}


