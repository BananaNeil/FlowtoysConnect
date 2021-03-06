import 'package:app/models/bridge.dart';
import 'package:app/models/group.dart';
import 'package:app/models/mode.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:async';

class Prop {
  Timer animationUpdater;
  Mode _currentMode;
  String groupId;
  int groupIndex;
  String id;
  int index;


  String setName;
  String type;


  String get uid => id;

  String get currentModeId => currentMode?.id;

  Group get group => Group.connectedGroups.firstWhere((group) => group.id == groupId);
  static List<String> get connectedModeIds => Group.connectedProps.map((prop) => prop.currentModeId).toList();
  static List<Mode> get connectedModes => (Group.connectedProps.map((prop) => prop.currentMode).toSet()..removeWhere((mode) => mode == null)).toList();

  static List<Prop> get unclaimedProps => Group.possibleProps.where((prop) => !Group.connectedProps.contains(prop)).toList();

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
  Mode get currentMode => _currentMode;
  void set internalMode(mode) {
    // propUpdateController.add(mode);
    _currentMode = mode;
    Prop.propUpdateController.sink.add(this);
  }
  DateTime _currentModeSetAt;
  void set currentMode(mode) {
    internalMode = mode;
    animationUpdater?.cancel();
    if (mode.isAnimating)
      animationUpdater = Timer(Duration(milliseconds: 205), () {
        this.currentMode = _currentMode;
      });
    if (_currentModeSetAt == null || DateTime.now().difference(_currentModeSetAt) > Duration(milliseconds: 200)) {
      _currentModeSetAt = DateTime.now();
      Bridge.setProp(
        propId: id,
        groupId: groupId,
        page: currentMode.page,
        number: currentMode.number,
        params: currentModeParamValues, 
      );
    }
  }

  void setAttributes(data) {
    type = data['type'];
    setName = data['set_name'];
  }

  Prop({
    this.id,
    this.index,
    this.groupId,
    this.groupIndex,
  });
}
