// import 'package:app/models/bridge.dart';
import 'package:app/models/group.dart';
import 'package:app/models/mode.dart';
import 'package:app/preloader.dart';
// import 'dart:async';



import 'package:app/models/prop.dart';
import 'package:app/client.dart';

class SyncPacket {
  String command;
  String groupId;
  int modeNumber;
  int page;

  Group _group;
  Group get group => _group ??= Group.findOrCreateById(groupId);

  factory SyncPacket.fromBridge(List<int> data) {
    String groupId = "${(data[1] << 8) + data[0]}";
    print("FROM BLE: GROUP ID: ${groupId}");

    // Sync packets for mode 10 of page 1,2,3
    // is showiing up with only 12 items
    SyncPacket syncPacket;
    if (data.length >=18) {
      String command;
      if (data[20] & 4 == 4)
        command = 'sleep';
      else if (data[20] & 2 == 2)
        command = 'wakeup';
      // else if (data[19] == 255)
      //   command = 'start_cycle';
      else if (data[20] & 1 == 1)
        command = 'start_adjust';
      else if (data[20] & 8 == 8)
        command = 'next_mode';
      else if (data[20] & 1 == 0)
        command = 'stop_adjust';
      else print("COMMAND UNKNOWN ${data[20]}");


      syncPacket = SyncPacket(
        modeNumber: data[19],
        groupId: groupId,
        command: command,
        page: data[18],
      );
    }

    return syncPacket;
  }

  SyncPacket({
    this.modeNumber,
    this.command,
    this.groupId,
    this.page,
  }) {
    if (command == 'sleep')
      group.isOn = false;
    else //if (group.isOn == false && command == 'wakeup' && page != 255)
      group.isOn = true;

    if (modeNumber == 255)
      group.isCyclingPage = true;
    else group.isCyclingPage = false;

    if (page == 255) {
      group.isCheckingBattery = true;
      return;
    }

    print("???????? ${group.isOn} ${group.possiblyOn} ${group.hashCode}");

    group.internalMode = null;
    if (group.isOn == false && command != 'sleep')
      if (group.possiblyOn)
        group.isOn = true;
      else group.possiblyOn = true;

    // print("prop ON: ${group.props.first.isOn} ... isON: ${group.isOn} possiblyON: ${group.possiblyOn}");

    Preloader.getModeLists({'creation_type': 'system'}).then((lists) {
      print("(page: ${page}, mode: ${modeNumber}) GET MODE LISTS: ${lists}");
      lists.forEach((list) {
        list.modes.forEach((mode) {
          if (mode.page == page + 1 && mode.number == modeNumber + 1){
            print("Set teh mode: ${mode.images}");
            group.internalMode = mode;
          }
        });
      });
    });
    group.internalMode ??=  Mode.basic(
      page: page + 1,
      number: modeNumber + 1,
    );

    if (command == 'start_adjust')
      group.internalMode.isAdjusting = true;

    print("COMMAND: ${command}");
    if (Group.connectedIds.contains(group.groupId) && (command == 'start_adjust' || command == 'next_mode'))
      Group.setCurrentProps(group.internalMode);
  }
}
