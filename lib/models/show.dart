import 'package:app/authentication.dart';
import 'package:json_api/document.dart';
import 'package:app/models/mode.dart';
import 'package:app/models/song.dart';
import 'package:app/client.dart';
import 'dart:convert';

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

  // Duration get duration => songs.map((song) => song.duration).reduce((a, b) => a+b); 
  Duration get duration {
    var songDurations = songs.map((song) => song.duration);
    if (songDurations.length == 0)
      return Duration(minutes: 1);
    else
      return songDurations.reduce((a, b) => a+b); 
  }

  static List<Show> fromList(Map<String, dynamic> json) {
    var data = ResourceCollectionData.fromJson(json);
    return data.collection.map((object) {
      return Show.fromResource(object.unwrap(), included: data.included);
    }).toList();
  }

  factory Show.fromResource(Resource resource, {included}) {
    var modes;

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

  factory Show.fromMap(Map<String, dynamic> json) {
    var data = Document.fromJson(json, ResourceData.fromJson).data;
    print("FROM MAP: ${json} \n ----> ${data.included} (data: ${data})");
    return Show.fromResource(data.unwrap(), included: data.included);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'song_ids': songs.map((song) => song.id).toList(),
    };
  }

  factory Show.create() {
    return Show(
      modes: [],
      songs: [],
    );
  }

  bool get isPersisted => id != null;

  Future<Map<dynamic, dynamic>> save() {
    var method = isPersisted ? Client.updateShow : Client.createShow;
    return method(toMap());
  }

}



