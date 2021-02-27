// import 'package:app/models/bridge.dart';
import 'package:app/models/group.dart';
import 'package:app/models/mode.dart';
import 'package:app/preloader.dart';
// import 'dart:async';

class SyncPacket {
  String groupId;
  int modeNumber;
  int page;

  factory SyncPacket.fromBle(List<int> data) {
    String groupId = "${(data[1] << 8) + data[0]}";
    Group group = Group.findOrCreateById(groupId);

    SyncPacket syncPacket = SyncPacket(
      modeNumber: data[19],
      groupId: groupId,
      page: data[18],
    );

    Preloader.getModeLists({'creation_type': 'system'}).then((lists) {
      lists.forEach((list) {
        list.modes.forEach((mode) {
          if (mode.page == syncPacket.page + 1 && mode.number == syncPacket.modeNumber + 1)
            group.internalMode = mode;
        });
      });
    });

    return syncPacket;
  }

  SyncPacket({
    this.modeNumber,
    this.groupId,
    this.page,
  });
}
