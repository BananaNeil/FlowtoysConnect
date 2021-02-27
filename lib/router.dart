import 'package:flutter/material.dart' hide Router;
import 'package:fluro/fluro.dart';

import 'package:app/routes/reset_password.dart';
import 'package:app/routes/create_account.dart';
import 'package:app/routes/neil_research.dart';
import 'package:app/routes/new_subshow.dart';
import 'package:app/routes/edit_show.dart';
import 'package:app/routes/edit_mode.dart';
import 'package:app/routes/new_list.dart';
import 'package:app/routes/new_song.dart';
import 'package:app/routes/research.dart';
import 'package:app/routes/new_show.dart';
import 'package:app/authentication.dart';
import 'package:app/routes/shows.dart';
import 'package:app/routes/show.dart';
import 'package:app/routes/login.dart';
import 'package:app/routes/modes.dart';
import 'package:app/routes/lists.dart';
import 'package:app/routes/props.dart';

class AppRouter {
  static FluroRouter router = FluroRouter();

  static newHandler(klass, [key]) {
    return Handler(handlerFunc: (BuildContext context, Map<String, dynamic> params) {
      if (key == null) return klass();
      else return klass(params[key][0]);
    });
  }

  static void setupRouter() {
    router.define(
      '/login-overlay',
      handler: newHandler(() => Login()),
      transitionType: TransitionType.inFromBottom,
    );
    router.define(
      '/login',
      handler: newHandler(() => Login()),
      transitionType: TransitionType.fadeIn,
    );
    router.define(
      '/signup',
      handler: newHandler(() => CreateAccount()),
      transitionType: TransitionType.inFromRight,
    );
    router.define(
      '/reset-password',
      handler: newHandler(() => ResetPassword()),
      transitionType: TransitionType.inFromRight,
    );
    router.define(
      '/modes',
      handler: newHandler(() => Modes()),
      transitionType: TransitionType.fadeIn,
    );
    router.define(
      '/modes/:id',
      handler: newHandler((id) => EditMode(id: id), 'id'),
      transitionType: TransitionType.inFromBottom,
    );
    router.define(
      '/lists/new',
      handler: newHandler(() => NewList()),
      transitionType: TransitionType.inFromRight,
    );
    router.define(
      '/lists',
      handler: newHandler(() => Lists()),
      transitionType: TransitionType.fadeIn,
    );
    router.define(
      '/neils-research',
      handler: newHandler(() => NeilsResearch()),
      transitionType: TransitionType.inFromRight,
    );
    router.define(
      '/research',
      handler: newHandler(() => Research()),
      transitionType: TransitionType.inFromRight,
    );
    router.define(
      '/lists/:id',
      handler: newHandler((id) => Modes(id: id), 'id'),
      transitionType: TransitionType.inFromRight,
    );
    router.define(
      '/props',
      handler: newHandler(() => Props()),
      transitionType: TransitionType.inFromRight,
    );
    router.define(
      '/subshows/new',
      handler: newHandler(() => NewSubShow()),
      transitionType: TransitionType.inFromBottom,
    );
    router.define(
      '/shows/:id/edit',
      handler: newHandler((id) => EditShow(id: id), 'id'),
      transitionType: TransitionType.inFromBottom,
    );
    router.define(
      '/shows/:id',
      handler: newHandler((id) {
        if (id == 'new') return NewShow();
        else return ShowPage(id: id);
      }, 'id'),
      transitionType: TransitionType.inFromRight,
    );
    router.define(
      '/shows/new',
      handler: newHandler(() => NewShow()),
      transitionType: TransitionType.inFromRight,
    );
    router.define(
      '/shows',
      handler: newHandler(() => Shows()),
      transitionType: TransitionType.inFromRight,
    );
    router.define(
      '/songs/new',
      handler: newHandler(() => NewSong()),
      transitionType: TransitionType.inFromBottom,
    );
  }
}
