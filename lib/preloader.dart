import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:app/models/mode_list.dart';
import 'package:app/models/base_mode.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/client.dart';
import 'package:darq/darq.dart';
import 'dart:isolate';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:app/native_storage.dart'
  if (dart.library.html) 'package:app/web_storage.dart';


class Preloader {

  static Directory songDir;
  static Map<String, Completer> downloadTasks = {};

  static ReceivePort _port = ReceivePort();


  static void downloadCallback(String id, DownloadTaskStatus status, int progress) {
    final SendPort send = IsolateNameServer.lookupPortByName('downloader_send_port');
    send.send([id, status, progress]);
  }


  static void initDownloader() async {
    await FlutterDownloader.initialize(debug: false);

    IsolateNameServer.registerPortWithName(_port.sendPort, 'downloader_send_port');
    _port.listen((dynamic data) {
      String id = data[0];
      DownloadTaskStatus status = data[1];
      int progress = data[2];

      if (status == DownloadTaskStatus.complete) {
        downloadTasks[id].complete(true);
      }
    });

    FlutterDownloader.registerCallback(downloadCallback);
  }

  static ensureSongDir() async {
    Directory appDocDirectory = await getApplicationDocumentsDirectory();
    return Directory("${appDocDirectory.path}/songs/")
     .create(recursive: true).then((Directory directory) {
        print("Created song dir!!!!! ${directory}");
       songDir = directory;
     });
  }

  static bool downloadStarted = false;
  static List<ModeList> modeLists = [];
  static List<BaseMode> baseModes = [];

  static Future<void> cacheBaseModes(newBaseModes) async {
    return getCachedBaseModes().then((cachedBaseModes) {
      cachedBaseModes = List.from(newBaseModes ?? [])..addAll(cachedBaseModes);
      cachedBaseModes = cachedBaseModes.distinct((baseMode) => baseMode.id).toList();
      baseModes = cachedBaseModes;
      return Storage.write('baseModes', BaseMode.toJson(cachedBaseModes));
    });
  }

  static Future<List<BaseMode>> getCachedBaseModes() async {
    if (baseModes.length > 0) return Future.value(baseModes);
    return Storage.read('baseModes').then((listJson) {
      if (listJson == null) return [];
      var listData = json.decode(listJson) as Map;
      baseModes = BaseMode.fromList(listData);
      return baseModes;
    });
  }

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
      modeLists = cachedLists;
      return Storage.write('modeLists', ModeList.toJson(cachedLists));
    });
  }

  static Future<List<ModeList>> getModeLists(query) async {
    return getCachedLists().then((lists) {
      return lists.where((list) {
        bool isMatch = true;
        query.forEach((key, value) {
          isMatch = isMatch && list.toMap()[key].toString() == value.toString();
        });
        return isMatch;
      }).toList();
    });
  }

  static void downloadData() async {
    Client.getBaseModes().then((response) {
      if (response['success']) {
        baseModes = response['baseModes'];
        baseModes.forEach((mode) {
          if (downloadStarted) return;
          downloadStarted = true;

          var context = AppController.getCurrentContext();

          // Preload images:
          var configuration = createLocalImageConfiguration(context);
          NetworkImage(mode.thumbnail)..resolve(configuration);
          NetworkImage(mode.image)..resolve(configuration);
        });
      }
    });
  }

}


