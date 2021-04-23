import 'package:app/authentication.dart';
import 'package:app/app_controller.dart';
import 'package:app/audio_manager.dart';
import 'package:app/blemanager.dart';
import 'package:app/oscmanager.dart';
import 'package:app/client.dart';
import 'dart:math';
import 'dart:async';

class Bridge {

  // static String get name => ownerName != null ? "$ownerName's FlowConnect" : 'Bridge';
  static String id;
  static String name;
  static String bleId;
  static String ownerName;
  static String unclaimedId;

  static bool isClaimed = false;
  static bool _isSyncing = false;

  static bool _isRestarting = false;
  static bool get isRestarting => _isRestarting;
  static void set isRestarting(value) {
    if (value == true)
      Timer(Duration(seconds: 10), () => _isRestarting = false);
    _isRestarting = value;
  }


  static StreamController<void> _changeStream;
  static StreamController<void> get changeStream {
    if (_changeStream != null) return _changeStream;
    return _changeStream = StreamController<void>.broadcast();
  }

  static Stream get stateStream => changeStream.stream;


  static AudioManager _audioManager;
  static AudioManager get audioManager => _audioManager ??= AudioManager();
  static Stream<double> get audioIntensityStream => audioManager.intensityStream;


  static void toggleSyncing() {
    isSyncing = !isSyncing;
  }

  static get isSyncing => _isSyncing;
  static set isSyncing(val) {
    _isSyncing = val;
    channel.setSyncing(val); //infinite
  }

  static Future save() {
    if (!Authentication.isAuthenticated || !isClaimed)
      return Future.value(null); 

    print("SAVING BRIDGE NAME.... ${name}");
    if (bleId != null) {
      Authentication.currentAccount.bridgeBleIds.add(bleId);
      Authentication.saveAccountToDisk();
    }
    Client.updateBridge();
  }

  static void setNetworkName() {
    channel.setNetworkName(name);
  }

  static Map<String, dynamic> toMap() {
    return {
      'name': name,
      'ble_id': bleId,
    };
  }

  static Duration get animationDelay => isWifi ? Duration(milliseconds: 60) : bleAnimationDelay;

  static Duration bleAnimationDelay = Duration(milliseconds: 120);

  static void setGroup({groupId, page, number, params}) {
    var paramNames = ["hue", "saturation", "brightness", "speed", "density"];

    var adjust = params['adjust'];
    var totalLFO = (adjust * params['adjustCycles']) as double;
    List<double> adjustValues = List.generate(4, (i) {
      return min(max(0, totalLFO - i), 1);
    });
    print("TOTAL LFO: ${totalLFO}");

    List<double> paramRatios = paramNames.map<double>((name) => params[name]).toList();
    paramRatios.addAll(adjustValues);

    List<int> paramValues = paramRatios.map<int>((value) => (value * 255).ceil()).toList();

    var adjustingValue = params['isAdjusting'] ? 1 : 0;
    if (params['adjustRandomized']) adjustingValue += 64;



    // WITH THE OLD FIRMWARE, YOU CAN't jump from one adjusting mode to another adjusting mode.
    // so we use this hackey work around, where we send two packets.
    //
    // The new firmware will fix this, so we shoould detect which firm ware is running
    // (probalby via absent propID), and fix this for that case.
    channel.sendPattern(
      actives: sumList(mapWithIndex(paramNames, (index, name) => pow(2, index+1)))+1,
      paramValues: [...paramValues, 0], // 0 => Forcing adjust to be false
      groupId: groupId,
      mode: number,
      page: page,
    );

    // if (params['adjustRandomized'])
    // Then start adjust, and randomize, and possibly stop adjust
    //
    // OR Choose a random adjust for the first signal, and let it be cool.



    if (params['isAdjusting'] || params['adjustRandomized'])
      Timer(Duration(milliseconds: 100), () {
        paramValues.add(adjustingValue);
        channel.sendPattern(
          actives: sumList(mapWithIndex(paramNames, (index, name) => pow(2, index+1)))+1,
          paramValues: paramValues,
          groupId: groupId,
          mode: number,
          page: page,
        );
      });
  }

  static void factoryReset() {
    channel.factoryReset();
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

  static bool get isConnected => bleConnected || oscConnected;
  static bool get wifiNetworkKnown => oscManager.networkKnown;
  static bool get bleConnected => bleManager.isConnected;
  static bool get oscConnected => oscManager.isConnected;

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
