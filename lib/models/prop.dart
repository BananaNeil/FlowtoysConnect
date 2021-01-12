import 'package:app/models/bridge.dart';
import 'package:app/models/group.dart';
import 'package:app/models/mode.dart';

class Prop {
  Mode _currentMode;
  String groupId;
  int groupIndex;
  String id;
  int index;

  String get currentModeId => currentMode?.id;

  static List<String> get connectedModeIds => Group.connectedProps.map((prop) => prop.currentModeId).toList();

  Map<String, num> get currentModeParamValues {
    return currentMode.getParamValues(
      groupIndex: groupIndex,
      propIndex: index,
    ); 
  }

  Mode get currentMode => _currentMode;
  void set currentMode(mode) {
    _currentMode = mode;
    Bridge.setGroup(
      groupId: groupId,
      page: currentMode.page,
      params: currentModeParamValues, 
      position: currentMode.position,
    );
  }

  Prop({
    this.id,
    this.index,
    this.groupId,
    this.groupIndex,
  });
}
