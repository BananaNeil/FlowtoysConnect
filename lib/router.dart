import 'package:flutter/material.dart' hide Router;
import 'package:fluro/fluro.dart';

import 'package:app/routes/reset_password.dart';
import 'package:app/routes/create_account.dart';
import 'package:app/routes/new_list.dart';
import 'package:app/routes/research.dart';
import 'package:app/authentication.dart';
import 'package:app/routes/login.dart';
import 'package:app/routes/modes.dart';

class FluroRouter {
  static Router router = Router();

  static newHandler(klass, [key]) {
    return Handler(handlerFunc: (BuildContext context, Map<String, dynamic> params) {
      if (key == null) return klass();
      else return klass(params[key][0]);
    });
  }

  static void setupRouter() {
    router.define(
      '/login',
      handler: newHandler(() => Login()),
      transitionType: TransitionType.fadeIn,
    );
    router.define(
      '/signup',
      handler: newHandler(() => CreateAccount()),
      transitionType: TransitionType.inFromBottom,
    );
    router.define(
      '/reset-password',
      handler: newHandler(() => ResetPassword()),
      transitionType: TransitionType.inFromBottom,
    );
    router.define(
      '/modes',
      handler: newHandler(() => Modes()),
      transitionType: TransitionType.inFromBottom,
    );
    router.define(
      '/lists/new',
      handler: newHandler(() => NewList()),
      transitionType: TransitionType.inFromBottom,
    );
    router.define(
      '/research',
      handler: newHandler(() => Research()),
      transitionType: TransitionType.inFromBottom,
    );
    router.define(
      '/lists/:id',
      handler: newHandler((id) => Modes(id: id), 'id'),
      transitionType: TransitionType.inFromBottom,
    );
  }
}
