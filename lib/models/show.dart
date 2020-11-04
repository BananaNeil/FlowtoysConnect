import 'package:app/helpers/duration_helper.dart';
import 'package:app/app_controller.dart';
import 'package:app/authentication.dart';
import 'package:json_api/document.dart';
import 'package:app/models/mode.dart';
import 'package:app/models/song.dart';
import 'package:app/preloader.dart';
import 'package:app/client.dart';
import 'dart:convert';
import 'dart:async';

class Show {
  List<Song> songs = [];
  List<Mode> modes = [];
  String name;
  num id;

  Show({
    this.id,
    this.name,
    this.modes,
    this.songs,
  });

  Duration get duration {
    if (songs.length == 0 && modes.length == 0) return Duration(minutes: 1);
    return maxDuration(songDuration, modeDuration);
  }

  Duration get songDuration {
    var songDurations = songs.map((song) => song.duration);
    if (songDurations.length == 0)
      return Duration(minutes: 1);
    else
      return songDurations.reduce((a, b) => a+b); 
  }

  Duration get modeDuration {
    var modeDurations = modes.map((mode) => mode.duration);
    if (modeDurations.length == 0) return Duration();
    return modeDurations.reduce((a, b) => a+b); 
  }

  Future<void> downloadSongs() {
    return Future.wait(songs.map((song) {
			return song.downloadFile();
    }));
  }

  Mode createNewMode() {
    var baseMode;
    if (Preloader.baseModes.isNotEmpty)
      baseMode = Preloader.baseModes.elementAt(0);
    print ("fromMap: ");
    return Mode.fromMap({
      'base_mode_id': baseMode?.id,
      'position': modes.length + 1,
      'parent_type': 'Show',
      'parent_id': id,
    });
  }

  static List<Show> fromList(Map<String, dynamic> json) {
    var data = ResourceCollectionData.fromJson(json);
    return data.collection.map((object) {
      return Show.fromResource(object.unwrap(), included: data.included);
    }).toList();
  }
  factory Show.fromResource(Resource resource, {included}) {
    var modes = resource.toMany['modes'].map((mode) {
      var modeData = (included ?? []).firstWhere((item) => item.id == mode.id);
      return Mode.fromMap(modeData.attributes);
    }).toList();

    var songs = resource.toMany['songs'].map((song) {
      var songData = (included ?? []).firstWhere((item) => item.id == song.id);
      return Song.fromMap(songData.attributes);
    }).toList();

    return Show(
      modes: modes ?? [],
      songs: songs ?? [],
      id: resource.attributes['id'],
      name: resource.attributes['name'],
    );
  }

  void updateFromCopy(copy) {
    modes = copy.modes;
    songs = copy.songs;
    name = copy.name;
    id = copy.id;
  }

  factory Show.fromMap(Map<String, dynamic> json) {
    var data = Document.fromJson(json, ResourceData.fromJson).data;
    // print("FROM MAP: ${json} \n ----> ${data.included} (data: ${data})");
    return Show.fromResource(data.unwrap(), included: data.included);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'song_ids': songs.map((song) => song.id).toList(),
      'mode_ids': modes.map((mode) => mode.id).toList(),
    };
  }

  factory Show.create() {
    return Show(
      modes: [],
      songs: [],
    );
  }

  bool get isPersisted => id != null;

  Future<Map<dynamic, dynamic>> save({modeDuration}) {
    var method = isPersisted ? Client.updateShow : Client.createShow;
    var attributes = toMap();

    if (!isPersisted) {
      attributes['mode_duration'] = modeDuration?.inMilliseconds;
      attributes['duration'] = duration.inMilliseconds;
    }
    return method(attributes);
  }

}



