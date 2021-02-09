import 'package:app/models/bridge.dart';
import 'package:app/models/group.dart';
import 'package:app/models/mode.dart';
import 'dart:async';

class Prop {
  Timer animationUpdater;
  Mode _currentMode;
  String groupId;
  int groupIndex;
  String id;
  int index;

  String get currentModeId => currentMode?.id;

  static List<String> get connectedModeIds => Group.connectedProps.map((prop) => prop.currentModeId).toList();
  static List<Mode> get connectedModes => (Group.connectedProps.map((prop) => prop.currentMode).toSet()..removeWhere((mode) => mode == null)).toList();
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

  Map<String, num> get currentModeParamValues {
    return currentMode.getParamValues(
      groupIndex: groupIndex,
      propIndex: index,
    ); 
  }

  Mode get currentMode => _currentMode;
  void set internalMode(mode) {
    _currentMode = mode;
  }
  void set currentMode(mode) {
    internalMode = mode;
    animationUpdater?.cancel();
    if (mode.isAnimating)
      animationUpdater = Timer.periodic(Duration(milliseconds: 100), (_) {
        this.currentMode = _currentMode;
      });
    Bridge.setGroup(
      groupId: groupId,
      page: currentMode.page,
      number: currentMode.number,
      params: currentModeParamValues, 
    );
  }

  Prop({
    this.id,
    this.index,
    this.groupId,
    this.groupIndex,
  });
}
