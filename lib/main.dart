import 'package:app/authentication.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app/preloader.dart';
import 'package:app/router.dart';

import 'package:app/native_storage.dart'
  if (dart.library.html) 'package:app/web_storage.dart';

void main({String env}) async {
  WidgetsFlutterBinding.ensureInitialized();
  env = 'prod';

  AppController.setEnv(env).then((_) {
    AppController.initSiriSuggestions();
    AppController.initBugsnag();
    Preloader.ensureSongDir();
    Preloader.downloadData();
    Preloader.initDownloader();
    Authentication.checkForAuth().then((isAuthenticated) {
      AppRouter.setupRouter();
      runApp(FlowtoysConnect(isAuthenticated));
    });
  });
}

class FlowtoysConnect extends StatelessWidget {
  FlowtoysConnect(this.isAuthenticated);

  final bool isAuthenticated;

  @override
  Widget build(BuildContext context) {
    print("HEYYYYY4");
    return AppController(builder: (context) {
      var theme = ThemeData(
        primaryColorDark: Color(0xffCCCCCC),
        primaryColorLight: Color(0xFFFFFFFF),
        canvasColor: Color(0xFF000000),
        accentColor: Color(0xff78BFEE),
        
        brightness: Brightness.dark,
        fontFamily: 'Ubuntu',
      );

      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

      AppController.globalKey ??= new GlobalKey<NavigatorState>();
      return MaterialApp(
        initialRoute: isAuthenticated ? '/modes' : '/login',
        onGenerateRoute: AppRouter.router.generator,
        navigatorKey: AppController.globalKey,
        title: 'Flowtoys Connect',
        theme: theme,
      );
    });
  }
}
