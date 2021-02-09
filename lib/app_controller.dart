import 'package:flutter_siri_suggestions/flutter_siri_suggestions.dart';
import 'package:bugsnag_crashlytics/bugsnag_crashlytics.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:package_info/package_info.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:app/models/base_mode.dart';
import 'package:app/models/mode_list.dart';
import 'package:app/authentication.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app/models/group.dart';
import 'package:app/models/prop.dart';
import 'package:app/preloader.dart';
import 'package:app/oscmanager.dart';
import 'package:app/blemanager.dart';
import 'dart:io' show Platform;
import 'dart:convert';
import 'dart:async';
import 'dart:math';

class AppController extends StatefulWidget {
  final Function(BuildContext) builder;

  static GlobalKey<NavigatorState> globalKey;
  static Map<String, dynamic> config = {};
  static bool dialogIsOpen = false;
  static String openedPath;
  static String appEnv;

  static String buildNumber;
  static String version;

  static OSCManager _oscManager;
  static OSCManager get oscManager => _oscManager ??= OSCManager();

  static BLEManager _bleManager;
  static BLEManager get bleManager => _bleManager ??= BLEManager();

  static void initConnectionManagers() {
    print(bleManager);
    print(oscManager);
  }

  static bool wifiIsConnected;
  static DateTime wifiLastCheckedAt;
  static Connectivity _connectivity;

  static String currentWifiNetworkName;
  static String currentWifiPassword;
  static String currentWifiSSID;

  static bool get wifiRecentlyChecked => wifiLastCheckedAt != null && DateTime.now().difference(wifiLastCheckedAt) < Duration(seconds: 1);
  static Future checkWifiConnection() async {
    wifiLastCheckedAt ??= DateTime.fromMillisecondsSinceEpoch(0);
    _connectivity ??= Connectivity();


    // .............................
    //
    // I fear that we need this for ios devices.... but it's throwing an error
    // (on macos... maybe we should try limiting it to ios and running again)
    //
    // var status = await NetworkInfo().getLocationServiceAuthorization();
    // if (status == LocationAuthorizationStatus.notDetermined) {
    //   status = await NetworkInfo().requestLocationServiceAuthorization();
    // }

    return _connectivity.checkConnectivity().then(updateWifiConnection);
  }

  static Future updateWifiConnection(connectionResult) async {
    // print("UPDATEwIFIcONNECTION ${connectionResult}");
    wifiLastCheckedAt = DateTime.now();
    wifiIsConnected = connectionResult == ConnectivityResult.wifi;
    if (wifiIsConnected) {
      print("Connected to wifi.......");
      try {
        currentWifiNetworkName = await NetworkInfo().getWifiName();
        print("Connected to wifi  NAME: ${currentWifiNetworkName}.......");
        currentWifiSSID = await NetworkInfo().getWifiBSSID();
        print("Connected to wifi  NAME: ${currentWifiSSID}.......");
      } on PlatformException catch (e) {
          print(e.toString());
      }
    }
  }

  static Future<void> setEnv(String env) async {
    final contents = await rootBundle.loadString('assets/config/${env ?? 'dev'}.json');
    config = jsonDecode(contents);
    appEnv = env;
  }

  static showGlobalMessage(message) {
    if (Platform.isAndroid || Platform.isIOS)
      Fluttertoast.showToast(msg: message);
    else print("GLOABL MESSAGE: ${message}");
  }

  static void initBugsnag() {
    PackageInfo.fromPlatform().then((PackageInfo packageInfo) {
      buildNumber = packageInfo.buildNumber;
      version = packageInfo.version;
      if (Platform.isAndroid || Platform.isIOS) {
        BugsnagCrashlytics.instance.register(
          androidApiKey: config['bugsnag']['android'],
          iosApiKey: config['bugsnag']['ios'],
          releaseStage: appEnv,
          appVersion: version,
        );
        FlutterError.onError = BugsnagCrashlytics.instance.recordFlutterError;
      }
    });
  }

  static void initSiriSuggestions() async {
    // FlutterSiriSuggestions.instance.configure(onLaunch: (Map<String, dynamic> message) async {
    //   //Awaken from Siri Suggestion
    //   ///// TO DO : do something!
    //   var arguments = message["key"].split(":");
    //
    //   if (arguments[0] == "openPath") {
    //     Timer(Duration(milliseconds: 1000), () {
    //       Navigator.pushNamed(getCurrentContext(), arguments[1]);
    //     });
    //   }
    // });
    //
    // await Preloader.getCachedLists().then((lists) {
    //   lists.forEach((list) {
    //     list.modes.forEach((mode) async {
    //       await FlutterSiriSuggestions.instance.buildActivity(FlutterSiriActivity("Set Mode To ${mode.name}",
    //         "openPath:/modes/${mode.id}",
    //         isEligibleForSearch: true,
    //         isEligibleForPrediction: true,
    //         contentDescription: "Sets props to the mode: ${mode.name}",
    //         suggestedInvocationPhrase: "Set my props to ${mode.name}")
    //       );
    //     });
    //   }); 
    // }).then((_) {
    //   FlutterSiriSuggestions.instance.retryLaunchWithActivity();
    // });

  }

  static BaseMode getBaseMode(id) {
    return Preloader.baseModes.firstWhere((baseMode) => baseMode.id == id);
  }

  static String logoImagePath() {
    return 'assets/images/logo.png';
  }

  static String backspaceImagePath() {
    return 'assets/images/backspace.png';
  }

  static Color randomColor = randomizeColor();

  static Color randomizeColor() {
    randomColor = (colors..shuffle()).first;
    return randomColor;
  }

  static double get screenWidth {
    return MediaQuery.of(getCurrentContext()).size.width;
  }

  static double topPadding() {
    return MediaQuery.of(getCurrentContext()).padding.top;
  }

  static double leftPadding() {
    return MediaQuery.of(getCurrentContext()).padding.left;
  }

  static Color yellow = Color(0xFFcfa015);
  static Color purple = Color(0xFFffaaaaff);
  static Color green = Color(0xFFffCCffCC);
  static Color blue = Color(0xFF7EB3DC);
  static Color red = Colors.red;
  static Color clear = Color(0x00FFFFFF);
  static Color white = Colors.white;
  static Color grey = Colors.grey;
  static Color darkGrey = Color(0xff333333);
  static Color lightGrey = Color(0xffCCCCCC);

  static List<Color> colors = [
    purple,
    yellow,
    green,
    blue,
    red,
  ].toList();

  static Map<dynamic, dynamic> getParams(BuildContext context) {
    return (ModalRoute.of(context).settings.arguments as Map) ?? {};
  }

  static void closeKeyboard() {
    FocusScopeNode currentFocus = FocusScope.of(getCurrentContext());
    if (!currentFocus.hasPrimaryFocus)
      currentFocus.unfocus();
  }


  static BuildContext getCurrentContext() {
    return globalKey.currentState.overlay.context;
  }

  static double scale(num value, {num maxValue, num minValue}) {
    var screenData = MediaQuery.of(getCurrentContext());
    value = value * screenData.size.height/650;
    value = min(value, maxValue ?? double.maxFinite);
    value = max(value, minValue ?? 0);
    return value.toDouble();
  }

  static Future<dynamic> openDialog(title, body, {child, path, buttonText, buttons, reverseButtons}) async {
    if (dialogIsOpen) return Future.value(false);
    dialogIsOpen = true;

    var context = getCurrentContext();
    buttons ??= [];

    var buttonWidgets = <Widget>[
      ...buttons.map((button) {
        return FlatButton(
          child: Container(
            child: Text(button['text']),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          textColor: button['color'] ?? white,
          onPressed: () {
            dialogIsOpen = false;
            Navigator.pop(context, button['returnValue'] ?? true);
            button['onPressed']();
          },
        );
      }),
      FlatButton(
        child: Text(buttonText ?? 'Ok'),
        onPressed: () {
          dialogIsOpen = false;
          Navigator.pop(context, null);
          if (path != null)
            openPath(path);
        },
      ),
    ];

    if (reverseButtons == true)
      buttonWidgets = buttonWidgets.reversed.toList();



    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        actionsPadding: EdgeInsets.all(5),
        content: ListTile(
          title: Text(title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20)
          ),
          subtitle: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              child ?? Container(),
              Container(width: 500, child: Text(body, textAlign: TextAlign.center, )),
            ]
          )
        ),
        actions: buttonWidgets,
      ),
    ).then((result) {
      dialogIsOpen = false;
      return result;
    });
  }

  static void closeUntilPath(String path) {
    Navigator.pushNamedAndRemoveUntil(getCurrentContext(), path, (Route<dynamic> route) => false);
  }

  static void openPath(String path) async {
    if (path != null && openedPath != path)
      Navigator.pushNamed(getCurrentContext(), path);
    Timer(Duration(milliseconds: 5000), () => openedPath = null);
    openedPath = path;
  }

  const AppController(
      {Key key, this.builder})
  : super(key: key);

  @override
  AppControllerState createState() => new AppControllerState();

  static AppControllerState of(BuildContext context) {
    return context.findAncestorStateOfType();
  }
}

class AppControllerState extends State<AppController> {

  @override
  Widget build(BuildContext context) {
    return widget.builder(context);
  }

  void rebuild() {
    setState(() {});
  }
}

int sumList(list) {
  if (list.isEmpty) return 0;
  return list.reduce((num a, num b) => a + b);
}


Iterable<E> mapWithIndex<E, T>(
    Iterable<T> items, E Function(int index, T item) f) sync* {
  var index = 0;

  for (final item in items) {
    yield f(index, item);
    index = index + 1;
  }
}

Iterable<T> eachWithIndex<E, T>(
    Iterable<T> items, E Function(int index, T item) f) {
  var index = 0;

  for (final item in items) {
    f(index, item);
    index = index + 1;
  }

  return items;
}
class TriangleClipper extends CustomClipper<Path> {

  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(size.width, 0.0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(TriangleClipper oldClipper) => false;
}
class PieClipper extends CustomClipper<Path> {
	PieClipper({this.ratio, this.offset});

	double ratio;
	double offset;

  @override
  Path getClip(Size size) {
    final path = Path();
    if (ratio == 1) {
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();
      return path;
    }

    // path.lineTo(0.0, 0.0);
    // path.lineTo(100* cos(ratio * 2 * pi), 100* cos(ratio * 2 * pi));
    path.moveTo(size.width/2, size.height/2);


		// Use this for the offset:
		path.lineTo( size.width * (0.5 + 100 * cos(offset * 2 * pi)),  size.height * (0.5 + 100 * sin(offset * 2 * pi)));

    ratio += offset;

    // path.lineTo( size.width * (0.5 + 100 * cos(ratio  * pi)),  size.height * (0.5 + 100 * sin(ratio * pi)));
    path.lineTo( size.width * (0.5 + 100 * cos(ratio * 2 * pi)),  size.height * (0.5 + 100 * sin(ratio * 2 * pi)));
    path.close();
    return path;
  }

  @override
  bool shouldReclip(PieClipper oldClipper) => true;
}
