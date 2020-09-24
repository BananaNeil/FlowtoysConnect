import 'package:app/models/mode_list.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/client.dart';
import 'package:darq/darq.dart';
import 'dart:convert';

import 'package:app/native_storage.dart'
  if (dart.library.html) 'package:app/web_storage.dart';


class Preloader {

  static bool downloadStarted = false;
  static List<ModeList> modeLists = [];

  static Future<List<ModeList>> getCachedLists() async {
    if (modeLists.length > 0) return Future.value(modeLists);
    return Storage.read('modeLists').then((listJson) {
      if (listJson == null) return [];
      var listData = json.decode(listJson) as Map;
      modeLists = ModeList.fromList(listData);
      return modeLists;
    });
  }

  static Future<void> cacheLists([List<ModeList> lists]) async {
    return getCachedLists().then((cachedLists) {
      // Put the newest ones first, incase of multiple devices
      cachedLists = List.from(lists ?? [])..addAll(cachedLists);
      cachedLists = cachedLists.distinct((list) => list.id).toList();
      return Storage.write('modeLists', ModeList.toJson(cachedLists));
    });
  }

  static Future<List<ModeList>> getModeLists(query) async {
    return getCachedLists().then((lists) {
      return lists.where((list) {
        bool isMatch = true;
        query.forEach((key, value) {
          isMatch = isMatch && list.toMap()[key] == value;
        });
        return isMatch;
      }).toList();
    });
  }

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


