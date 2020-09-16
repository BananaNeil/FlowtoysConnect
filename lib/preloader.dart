import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/client.dart';


class Preloader {

  static bool downloadStarted = false;

  static void downloadData() async {
    Client.getBaseModes().then((response) {
      if (response['success'])
        AppController.baseModes = response['baseModes'];
    });
  }

  static void downloadImages() async {
    if (downloadStarted) return;
    downloadStarted = true;

    var context = AppController.getCurrentContext();

    // // Preload images:
    // var configuration = createLocalImageConfiguration(context);
    // NetworkImage(image_url)..resolve(configuration);
  }

}


