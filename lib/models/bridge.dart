import 'package:app/app_controller.dart';
import 'package:app/blemanager.dart';
import 'package:app/oscmanager.dart';
import 'package:app/client.dart';
import 'dart:math';
import 'dart:async';

class Bridge {

  // static String get name => ownerName != null ? "$ownerName's FlowConnect" : 'Bridge';
  static String id;
  static String name;
  static String newName;
  static String ownerName;
  static String unclaimedId;

  static bool _isSyncing = false;

  static StreamController<void> _changeStream;
  static StreamController<void> get changeStream {
    if (_changeStream != null) return _changeStream;
    return _changeStream = StreamController<void>.broadcast();
  }

  static Stream get stateStream => changeStream.stream;

  static void toggleSyncing() {
    isSyncing = !isSyncing;
  }

  static get isSyncing => _isSyncing;
  static set isSyncing(val) {
    _isSyncing = val;
    channel.setSyncing(val); //infinite
  }

  static Future save() {
    channel.setNetworkName(name);
    Client.updateBridge();
  }

  static Map<String, dynamic> toMap() {
    return {
      name: name,
    };
  }

  static void setGroup({groupId, page, number, params}) {
    var paramNames = ["hue", "saturation", "brightness", "speed", "density"];

    var adjust = params['adjust'];
    var totalLFO = (adjust * params['adjustCycles']) as double;
    List<double> adjustValues = List.generate(params['adjustCycles'].toInt(), (i) {
      return min(max(0, totalLFO - i), 1);
    });



    print("SET GROUP: ${paramNames.map<double>((name) => params[name]).toList()..addAll(adjustValues)}");
    channel.sendPattern(
      actives: sumList(mapWithIndex(paramNames, (index, name) => pow(2, index+1))),
      paramValues: paramNames.map<double>((name) => params[name]).toList()..addAll(adjustValues),
      groupId: groupId,
      mode: number,
      page: page,
    );
  }

  static void setProp({groupId, propId, page, number, params}) {
    // Fix this when propIds
    setGroup(groupId: groupId, page: page, number: number, params: params);
  }

  static void connectToMostRecentWifiNetwork() {
     channel.sendConfig(
       networkName: oscManager.mostRecentWifiNetworkName,
       password: oscManager.mostRecentWifiPassword,
       ssid: oscManager.mostRecentWifiSSID,
     );
  }

  static BLEManager _bleManager;
  static BLEManager get bleManager => _bleManager ??= BLEManager();

  static OSCManager _oscManager;
  static OSCManager get oscManager => _oscManager ??= OSCManager();

  static get currentChannel => oscManager.isConnected ? 'wifi' : 'bluetooth'; 
  static get isBle => currentChannel == 'bluetooth'; 
  static get isWifi => currentChannel == 'wifi';

  static dynamic get channel {
    return isBle ? 
      bleManager : oscManager;
  }

  static bool get isUnclaimed {
    RegExp regex = RegExp(r'^FlowConnect \d+');
    return regex.hasMatch(name ?? "");
  }

}
