import 'package:app/models/bridge.dart';
import 'package:app/models/group.dart';
import 'package:app/models/mode.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:async';
import 'dart:math';

class Prop {
  Timer animationUpdater;
  Mode _currentMode;
  String propType;
  String groupId;
  int groupIndex;
  String userId;
  bool virtual;
  String id;
  int index;

  String get uid => id;

  String get currentModeId => currentMode?.id;

  bool _isCyclingPage;
  bool get isCyclingPage => _isCyclingPage;
  void set isCyclingPage(value) {
    _isCyclingPage = value;
    Prop.propUpdateController.sink.add(this);
  }

  bool _isCheckingBattery;
  bool get isCheckingBattery => _isCheckingBattery;
  void set isCheckingBattery(value) {
    print("PROP setting check battery: ${value}");
    _isCheckingBattery = value;
    Prop.propUpdateController.sink.add(this);
  }


  bool _isOn;
  bool get isOn => _isOn;
  void set isOn(value) {
    _isOn = value;
    Prop.propUpdateController.sink.add(this);
  }

  Group get group => Group.possibleGroups.firstWhere((group) => group.groupId == groupId);
  static List<String> get connectedModeIds => Group.connectedProps.map((prop) => prop.currentModeId).toList();
  static List<Mode> get connectedModes => (Group.connectedProps.map((prop) => prop.currentMode).toSet()..removeWhere((mode) => mode == null)).toList();
  static List<Mode> get currentModes => (Group.currentProps.map((prop) => prop.currentMode).toSet()..removeWhere((mode) => mode == null)).toList();

  static List<Prop> get unconnectedProps => Group.possibleProps.where((prop) => !Group.connectedProps.contains(prop)).toList();

  static String _quickGroupPropIdsWas;
  static Map<String, List<Prop>> _quickGroupPropsByGroupId;
  static Map<String, List<Prop>> get quickGroupPropsByGroupId {
    if (_quickGroupPropIdsWas == Group.currentQuickGroup.propIds.toString())
      return _quickGroupPropsByGroupId;
    Map<String, List<Prop>> map = {};
    Group.currentQuickGroup.props.forEach((prop) {
      map[prop.groupId] ??= [];
      map[prop.groupId].add(prop);
    });

    _quickGroupPropIdsWas = Group.currentQuickGroup.propIds.toString();
    _quickGroupPropsByGroupId = map;
    return map;
  }
  static Map<String, List<Prop>> get propsByModeId {
    Map<String, List<Prop>> map = {};
    connectedModes.forEach((mode) {
      map[mode.id] ??= Group.connectedProps.where((prop) => prop.currentModeId == mode?.id).toList();
    });

    return map;
  }
  static Map<Mode, List<Prop>> get propsByMode {
    Map<Mode, List<Prop>> map = {};
    connectedModes.forEach((mode) {
      map[mode] ??= Group.connectedProps.where((prop) => prop.currentModeId == mode?.id).toList();
    });

    return map;
  }

  static List<Prop> get current => Group.currentProps;
  static List<Prop> get possible => Group.possibleProps;
  static List<Prop> get connected => Group.connectedProps;

  static void refreshByMode(mode) {
    (propsByModeId[mode.id] ?? []).forEach((prop) => prop.currentMode = mode );
  }

  Map<String, dynamic> get adjustedModeParamValues {
    if (!Mode.globalParamsEnabled)
      return currentModeParamValues;

    var values = currentModeParamValues;
    var globalValues = Mode.globalParamRatios;
    values.keys.forEach((param) {
      if (currentMode.booleanParams.keys.contains(param))
        values[param] = values[param] || globalValues[param];
      else values[param] *= globalValues[param];
    });
    return values;
  }

  Map<String, dynamic> get currentModeParamValues {
    return currentMode.getParamValues(
      groupIndex: groupIndex,
      propIndex: index,
    ); 
  }

  static BehaviorSubject<Prop> propUpdateController = BehaviorSubject<Prop>();
  static Stream<Prop> get propUpdateStream => propUpdateController.stream;

  // StreamController<Mode> currentModeController = StreamController<Mode>();
  // Stream<Mode> get currentModeStream => currentModeController.stream;
  //
  void refreshMode() {
    currentMode = _currentMode;
  }

  Mode get currentMode => _currentMode;
  void set internalMode(mode) {
    // propUpdateController.add(mode);
    _currentMode = mode;
    Prop.propUpdateController.sink.add(this);
  }
  DateTime _currentModeSetAt;
  void set currentMode(mode) {
    if (mode.adjustRandomized)
      mode.setValue('adjust', Random().nextDouble());

    internalMode = mode;
    animationUpdater?.cancel();
    if (mode.isAnimating)
      animationUpdater = Timer(Bridge.animationDelay * 1.02, () {
        this.currentMode = _currentMode;
      });
    if (_currentModeSetAt == null || DateTime.now().difference(_currentModeSetAt) > Bridge.animationDelay) {
      _currentModeSetAt = DateTime.now();
      Bridge.setProp(
        propId: id,
        groupId: groupId,
        page: currentMode.page,
        number: currentMode.number,
        params: adjustedModeParamValues, 
      );
    }
  }

  void setAttributes(data) {
    userId = data['user_id'];
    propType = data['prop_type'];
    group.name = data['group_name'];
    if (group.props.length < data['group_count'])
      List.generate((data['group_count'] - group.props.length), (i) {
        group.addVirtualProp();
      });
  }

  Prop({
    this.id,
    this.index,
    this.userId,
    this.virtual,
    this.groupId,
    this.propType,
    this.groupIndex,
  });
}
