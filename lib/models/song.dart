import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:app/helpers/duration_helper.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:json_api/document.dart';
import 'package:app/preloader.dart';
import 'package:app/client.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'dart:io';


class Song {

  String thumbnailUrl;
  Duration duration;
  String youtubeUrl;
  String filePath;
  String status;
  int position;
  String name;
  num id;

  Song({
    this.id,
    this.name,
    this.status,
    this.filePath,
    this.position,
    this.duration,
    this.youtubeUrl,
    this.thumbnailUrl,
  });

  void assignAttributes(attributes) {
  }

  String get fileUrl {
    final protocol = AppController.config['protocol'];
    final domain = AppController.config['domain'];
    final host = "$protocol://$domain";
    return "$host$filePath";
  }

  String get fileName => "${id}.wav";
  String get localPath => "${Preloader.songDir.path}/${fileName}";

  Completer downloadTask = Completer();
  bool fileDownloadPending = false;


  String get durationString => twoDigitString(duration);


  Future<dynamic> downloadFile() async {
    print('Downloading ${fileUrl} into: '+ Preloader.songDir.path);

    if (fileDownloadPending)
      return downloadTask.future;

    if (File(localPath).existsSync())
      return Future.value(true);

    fileDownloadPending = true;

    var taskId = await FlutterDownloader.enqueue(
      url: fileUrl,
      fileName: fileName,
      savedDir: Preloader.songDir.path,
      showNotification: true, // show download progress in status bar (for Android)
      openFileFromNotification: false, // click on notification to open downloaded file (for Android)
    );

    Preloader.downloadTasks[taskId] = downloadTask;
    return downloadTask.future;
  }

  Future<Map<dynamic, dynamic>> save() {
    var method = id == null ? Client.createSong : Client.updateSong;
    return method(toMap());
  }


  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'position': position,
      'youtube_url': youtubeUrl,
      'thumbnail_url': thumbnailUrl,
      'duration': duration.inMilliseconds,
    };
  }

  factory Song.fromResource(Resource resource, {included}) {
    return Song(
      id: resource.attributes['id'],
      name: resource.attributes['name'],
      status: resource.attributes['status'],
      position: resource.attributes['position'],
      filePath: resource.attributes['file_path'],
      thumbnailUrl: resource.attributes['thumbnail_url'],
      duration: Duration(milliseconds: resource.attributes['duration']),
    );
  }

  factory Song.fromMap(Map<String, dynamic> json) {
    return Song(
      id: json['id'],
      name: json['name'],
      status: json['status'],
      position: json['position'],
      filePath: json['file_path'],
      thumbnailUrl: json['thumbnail_url'],
      duration: Duration(milliseconds: json['duration'] ?? 0),
    );
  }
}
