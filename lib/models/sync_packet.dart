// import 'package:app/models/bridge.dart';
import 'package:app/models/group.dart';
import 'package:app/models/mode.dart';
import 'package:app/preloader.dart';
// import 'dart:async';

class SyncPacket {
  String groupId;
  int modeNumber;
  int page;

  factory SyncPacket.fromBridge(List<int> data) {
    String groupId = "${(data[1] << 8) + data[0]}";
    print("FROM BLE: GROUP ID: ${groupId}");
    Group group = Group.findOrCreateById(groupId);

    // Sync packets for mode 10 of page 1,2,3
    // is showiing up with only 12 items
    group.internalMode = null;
    SyncPacket syncPacket;
    if (data.length >=18) {
      syncPacket = SyncPacket(
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
      group.internalMode ??=  Mode.basic(
        page: syncPacket.page + 1,
        number: syncPacket.modeNumber + 1,
      );
    }

    return syncPacket;
  }

  SyncPacket({
    this.modeNumber,
    this.groupId,
    this.page,
  });
}
