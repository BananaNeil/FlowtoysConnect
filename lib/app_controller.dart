import 'package:flutter_siri_suggestions/flutter_siri_suggestions.dart';
import 'package:bugsnag_crashlytics/bugsnag_crashlytics.dart';
import 'package:app/components/bridge_connection_status.dart';
import 'package:package_info/package_info.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:app/models/base_mode.dart';
import 'package:app/models/mode_list.dart';
import 'package:app/authentication.dart';
import 'package:app/models/bridge.dart';
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

  static OSCManager get oscManager => Bridge.oscManager;
  static BLEManager get bleManager => Bridge.bleManager;

  static void initConnectionManagers() {
    print("INIT CONNECTION MANAGERS");
    print(bleManager);
    print(oscManager);
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

  static bool get isSmallScreen {
    return screenWidth < 380; 
  }

  static double get screenWidth {
    return MediaQuery.of(getCurrentContext()).size.width;
  }

  static double get bottomPadding {
    return MediaQuery.of(getCurrentContext()).padding.bottom;
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

  static void rebuild() {
    of(getCurrentContext()).rebuild();
  }

  static double scaleViaWidth(num value, {num maxValue, num minValue}) {
    var screenData = MediaQuery.of(getCurrentContext());
    value = value * screenData.size.width/450;
    value = min(value, maxValue ?? double.maxFinite);
    value = max(value, minValue ?? 0);
    return value.toDouble();
  }

  static double scale(num value, {num maxValue, num minValue}) {
    var screenData = MediaQuery.of(getCurrentContext());
    value = value * screenData.size.height/650;
    value = min(value, maxValue ?? double.maxFinite);
    value = max(value, minValue ?? 0);
    return value.toDouble();
  }

  static Future<dynamic> openCustomDialog(dialog) async {
    if (dialogIsOpen) return Future.value(false);
    dialogIsOpen = true;

    var context = getCurrentContext();
    return showDialog(
      context: context,
      builder: (context) => dialog,
    ).then((result) {
      dialogIsOpen = false;
      return result;
    });
  }

  static Future<dynamic> openDialog(title, body, {child, path, buttonText, buttons, reverseButtons, floatingButton, alignSubtitle}) async {
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
        contentPadding: EdgeInsets.only(top: 15),
        insetPadding: EdgeInsets.all(isSmallScreen ? 15 : 25),
        actionsPadding: EdgeInsets.all(5),
        content: Stack(
          children: [
            ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 5 : 10, vertical: 10),
              title: Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20)
              ),
              subtitle: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  child ?? Container(),
                  Container(width: 500, child: Text(body, textAlign: alignSubtitle ?? TextAlign.center, )),
                ]
              )
            ),
              Container(
                height: 40,
                margin: EdgeInsets.only(right: 15),
                child: Align(
                  alignment: FractionalOffset.topRight,
                  child: floatingButton,
                ),
              )
          ],
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

Future ensureAuthentication(Function callback) {
  if (Authentication.isAuthenticated) return callback();
  return _openLoginScreen().then((_) {
    if (Authentication.isAuthenticated)
      callback();
  });
}

Future _openLoginScreen() {
  return Navigator.pushNamed(AppController.getCurrentContext(), '/login-overlay', arguments: {
    'showCloseButton': true
  });
}

Future openBridgeDetails() {
  return AppController.openCustomDialog(BridgeConnectionStatus()).then((callback) {
    if (callback != null && callback is Function) callback();
  });
}
