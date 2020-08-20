import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';


class Preloader {

  static bool downloadStarted = false;

  static void downloadImages() async {
    if (downloadStarted) return;
    downloadStarted = true;

    var context = AppController.getCurrentContext();

    // // Preload images:
    // var configuration = createLocalImageConfiguration(context);
    // NetworkImage(image_url)..resolve(configuration);
  }

}


