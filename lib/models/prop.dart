import 'package:app/models/group.dart';
import 'package:app/models/mode.dart';

class Prop {
  Mode currentMode;
  String groupId;
  int groupIndex;
  String id;
  int index;

  String get currentModeId => currentMode?.id;

  static List<String> get connectedModeIds => Group.connectedProps.map((prop) => prop.currentModeId).toList();

  Prop({
    this.id,
    this.index,
    this.groupId,
    this.groupIndex,
  });
}
