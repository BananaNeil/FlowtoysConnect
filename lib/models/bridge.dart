import 'package:app/app_controller.dart';
import 'package:app/blemanager.dart';
import 'package:app/oscmanager.dart';
import 'dart:math';

class Bridge {

  static String currentChannel = 'bluetooth';
  static bool _isSyncing = false;

  static void toggleSyncing() {
    isSyncing = !isSyncing;
  }

  static get isSyncing => _isSyncing;
  static set isSyncing(val) {
    _isSyncing = val;
    channel.setSyncing(val); //infinite
  }

  static void setGroup({groupId, page, number, params}) {
    var paramNames = ["hue", "saturation", "brightness", "speed", "density", "adjust"];
    print("SET GROUP: ${paramNames.map<double>((name) => params[name]).toList()}");
    channel.sendPattern(
      actives: sumList(mapWithIndex(paramNames, (index, name) => pow(2, index+1))),
      paramValues: paramNames.map<double>((name) => params[name]).toList()..addAll([0.0, 0.0, 0.0]),
      group: groupId ?? 0, // Fix this .....
      mode: number,
      page: page,
    );
  }

  static void connectToCurrentWifiNetwork() {
     AppController.bleManager.sendConfig(
       networkName: AppController.currentWifiNetworkName,
       password: AppController.currentWifiPassword,
       ssid: AppController.currentWifiSSID,
     );
  }

  static BLEManager _bleManager;
  static BLEManager get bleManager => _bleManager ??= BLEManager();

  static OSCManager _oscManager;
  static OSCManager get oscManager => _oscManager ??= OSCManager();

  static get isBle => currentChannel == 'bluetooth'; 
  static get isWifi => currentChannel == 'wifi';

  static dynamic get channel {
    return isBle ? 
      bleManager : oscManager;
  }

}
