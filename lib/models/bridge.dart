import 'package:app/app_controller.dart';
import 'package:app/blemanager.dart';
import 'package:app/oscmanager.dart';
import 'dart:math';

class Bridge {

  static String currentChannel = 'bluetooth';

  // List<bool> paramsEnabled = [false, false, false, false, false];
  // List<double> paramValues = [.5, 1, 1, .5, .5];

  static void setGroup({groupId, page, position, params}) {
    var paramNames = ["hue", "saturation", "brightness", "speed", "density"];
    print("SET GROUP: ${paramNames.map<double>((name) => params[name]).toList()}");
    channel.sendPattern(
      actives: sumList(mapWithIndex(paramNames, (index, name) => pow(2, index+1))),
      paramValues: paramNames.map<double>((name) => params[name]).toList(),
      group: groupId,
      mode: position,
      page: page,
    );
  }

  static BLEManager _bleManager;
  static BLEManager get bleManager => _bleManager ??= BLEManager();

  static OSCManager _oscManager;
  static OSCManager get oscManager => _oscManager ??= OSCManager();

  static dynamic get channel {
    return currentChannel == 'bluetooth' ? 
      bleManager : oscManager;
  }

}
