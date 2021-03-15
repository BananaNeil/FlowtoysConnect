import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:app/models/mode_list.dart';
import 'package:app/models/base_mode.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/models/group.dart';
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
  static Map<String, int> downloadTaskProgress = {};

  static ReceivePort _port = ReceivePort();


  static Future<bool> ready() {
    return Storage.ready();
  }

  static void downloadCallback(String id, DownloadTaskStatus status, int progress) {
    print("DOWN CALLBACK: ${[id, status, progress]} ===> ${status} == ${DownloadTaskStatus.complete} => ${status == DownloadTaskStatus.complete}");

    final SendPort send = IsolateNameServer.lookupPortByName('downloader_send_port');
    send.send([id, status, progress]);
  }


  static void initDownloader() async {
    // TODO: Implaement a macos version of the downloader?
    if (!Platform.isAndroid && !Platform.isIOS) return; 

    await FlutterDownloader.initialize(
      debug: true // optional: set false to disable printing logs to console
    );

    IsolateNameServer.registerPortWithName(_port.sendPort, 'downloader_send_port');
    _port.listen((dynamic data) {
      String id = data[0];
      DownloadTaskStatus status = data[1];
      int progress = data[2];

      downloadTaskProgress[id] = progress;
      if (status == DownloadTaskStatus.complete) {
        print("Trigger complete!!!!");
        print("Trigger complete on ${id} ${downloadTasks[id]}");
        downloadTasks[id].complete(true);
      } else if (status == DownloadTaskStatus.failed) {
        downloadTasks[id].completeError('Download failed');
      }
    });

    FlutterDownloader.registerCallback(downloadCallback);
  }

  // This will probably request permissions,
  // and we should probably find a way to move it
  // so it's not the first thing that the user sees.
  static ensureSongDir() async {
    if (kIsWeb) return Future.value(null);
    Directory appDocDirectory = await getApplicationDocumentsDirectory();
    return Directory("${appDocDirectory.path}/songs/")
     .create(recursive: true).then((Directory directory) {
        print("Created song dir!!!!! ${directory}");
       songDir = directory;
     });
  }

  static Future<List<String>> saveGroupId(id) async {
    Group.savedGroupIds.add(id);
    await Storage.write('savedGroupIds', jsonEncode(Group.savedGroupIds));
  }

  static Future<List<String>> recallSavedGroupIds() {
    return Storage.read('savedGroupIds').then((listJson) {
      if (listJson == null) return [];
      Group.savedGroupIds = json.decode(listJson);
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
      modeLists = modeLists.distinct((list) => list.id).toList();
      return modeLists;
    });
  }

  static Future<void> cacheLists([List<ModeList> lists]) async {
    return getCachedLists().then((cachedLists) {
      // Put the newest ones first, incase of multiple devices
      cachedLists = List.from(lists ?? [])..addAll(cachedLists);
      cachedLists = cachedLists.where((list) => list?.id != null).distinct((list) => list.id).toList();
      modeLists = cachedLists;
      return Storage.write('modeLists', ModeList.toJson(cachedLists));
    });
  }

  static Future<List<ModeList>> getModeLists([query]) async {
    query ??= {};
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

  static Future downloadData() async {
    if (downloadStarted)
      return Future.value(true);
    else return Client.getBaseModes().then((response) {
      if (response['success']) {
        baseModes = response['baseModes'];
        baseModes.forEach((mode) {
          if (downloadStarted) return;
          downloadStarted = true;

          var context = AppController.getCurrentContext();

          // Preload images:
          var configuration = createLocalImageConfiguration(context);
          NetworkImage(mode.thumbnail ?? mode.defaultImage)..resolve(configuration);
          NetworkImage(mode.image ?? mode.defaultImage)..resolve(configuration);
        });
      }
    });
  }

}


