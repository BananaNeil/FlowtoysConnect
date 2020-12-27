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
  bool get isPersisted => id != null;

  String thumbnailUrl;
  Duration duration;
  String youtubeUrl;
  String filePath;
  String status;
  int byteSize;
  String name;
  double bpm;
  String id;

  Song({
    this.id,
    this.bpm,
    this.name,
    this.status,
    this.byteSize,
    this.filePath,
    this.duration,
    this.youtubeUrl,
    this.thumbnailUrl,
  });

  void assignAttributesFromCopy(copy) {
    var attributes = copy.toMap();

    id = attributes['id'];
    bpm = attributes['bpm'];
    name = attributes['name'];
    status = attributes['status'];
    byteSize = attributes['byte_size'];
    filePath = attributes['file_path'];
    thumbnailUrl = attributes['thumbnail_url'];
  }

  String get fileUrl {
    if (filePath == null) return null;
    final protocol = AppController.config['protocol'];
    final domain = AppController.config['domain'];
    final host = "$protocol://$domain";
    return "$host$filePath";
  }

  String get fileName => "${id}.wav";
  String get localPath => "${Preloader.songDir.path}/${fileName}";

  Completer downloadTask = Completer();
  bool fileDownloadPending = false;


  String downloadTaskId;
  String get durationString => twoDigitString(duration);
  int get downloadProgress => downloadTaskId == null ? 0 : Preloader.downloadTaskProgress[downloadTaskId];

  bool get isDownloaded => File(localPath).existsSync();

  Future<dynamic> downloadFile() async {
    print('Downloading ${fileUrl} into: '+ Preloader.songDir.path);

    if (fileDownloadPending)
      return downloadTask.future;

    if (isDownloaded)
      return Future.value(true);

    fileDownloadPending = true;

    downloadTaskId = await FlutterDownloader.enqueue(
      url: fileUrl,
      fileName: fileName,
      savedDir: Preloader.songDir.path,
      showNotification: true, // show download progress in status bar (for Android)
      openFileFromNotification: false, // click on notification to open downloaded file (for Android)
    );

    Preloader.downloadTasks[downloadTaskId] = downloadTask;
    Preloader.downloadTaskProgress[downloadTaskId] = 0;
    return downloadTask.future;
  }


  Future<Map<dynamic, dynamic>> save() {
    var method = id == null ? Client.createSong : Client.updateSong;
    return method(toMap());
  }


  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bpm': bpm,
      'name': name,
      'byte_size': byteSize,
      'file_path': filePath,
      'youtube_url': youtubeUrl,
      'thumbnail_url': thumbnailUrl,
      'duration': duration.inMicroseconds,
    };
  }



  factory Song.fromResource(Resource resource, {included}) {
    return Song(
      id: resource.attributes['id'],
      bpm: resource.attributes['bpm'],
      name: resource.attributes['name'],
      status: resource.attributes['status'],
      byteSize: resource.attributes['byte_size'],
      filePath: resource.attributes['file_path'],
      thumbnailUrl: resource.attributes['thumbnail_url'],
      duration: Duration(microseconds: resource.attributes['duration']),
    );
  }

  factory Song.fromMap(Map<String, dynamic> json) {
    return Song(
      id: json['id'],
      bpm: json['bpm'],
      name: json['name'],
      status: json['status'],
      byteSize: json['byte_size'],
      filePath: json['file_path'],
      thumbnailUrl: json['thumbnail_url'],
      duration: Duration(microseconds: json['duration'] ?? 0),
    );
  }
}
