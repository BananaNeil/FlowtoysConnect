import 'package:app/helpers/duration_helper.dart';
import 'package:app/models/timeline_element.dart';
import 'package:app/app_controller.dart';
import 'package:app/authentication.dart';
import 'package:json_api/document.dart';
import 'package:app/models/mode.dart';
import 'package:app/models/song.dart';
import 'package:app/preloader.dart';
import 'package:app/client.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math';

class Show {
  List<TimelineElement> timelineElements = [];
  String name;
  String id;

  Show({
    this.id,
    this.name,
    this.timelineElements,
  });

  List<TimelineElement> get songElements => timelineElements.where((element) {
    return element.timelineType == 'audio';
  }).toList()..sort((a, b) => a.position.compareTo(b.position));

  List<TimelineElement> get modeElements => timelineElements.where((element) {
    return element.timelineType == 'modes';
  }).toList()..sort((a, b) => a.position.compareTo(b.position));

  TimelineElement addAudioElement(song) {
    var element = TimelineElement(
      position: songElements.isEmpty ? 1 : songElements.last.position + 1,
      duration: song.duration,
      timelineType: 'audio',
      timelineIndex: 0,
      object: song,
      showId: id,
    );
    timelineElements.add(element);
    return element;
  }

  void set modes(_modes) {
    clearModes();
    timelineElements.addAll(mapWithIndex(_modes, (index, mode) {
      return TimelineElement(
        timelineType: 'modes',
        position: index + 1,
        timelineIndex: 0,
        object: mode,
      );
    }).toList());
  }

  void clearModes() {
    this.timelineElements = timelineElements.where((element) {
      return element.timelineType != 'modes';
    }).toList();
  }

  List<String> get songIds => songElements.map((element) => element.objectId).toList();
  List<String> get modeIds => modeElements.map((element) => element.objectId).toList();

  Duration get duration {
    if (songElements.length == 0 && modeElements.length == 0) return Duration(minutes: 1);
    if (songDuration == Duration() && modeDuration == Duration()) return Duration(minutes: 1);
    return maxDuration(songDuration, modeDuration);
  }

  Duration get songDuration {
    var songDurations = songElements.map((song) => song.duration);
    if (songDurations.length == 0) return Duration();
    return songDurations.reduce((a, b) => a+b); 
  }

  Duration get modeDuration {
    var modeDurations = modeElements.map((mode) => mode.duration ?? Duration());
    if (modeDurations.length == 0) return Duration();
    return modeDurations.reduce((a, b) => a+b); 
  }

  Future<void> downloadSongs() {
    return Future.wait(songElements.map((element) {
      return element.object?.downloadFile() ?? Future.value(true);
    }));
  }

  Mode createNewMode() {
    var baseMode;
    if (Preloader.baseModes.isNotEmpty)
      baseMode = Preloader.baseModes.elementAt(0);
    print ("fromMap: ");
    return Mode.fromMap({
      'position': modeElements.length + 1,
      'base_mode_id': baseMode?.id,
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
    var elements = resource.toMany['timeline_elements'].map((element) {
      var elementData = (included ?? []).firstWhere((item) => item.id == element.id);
      return TimelineElement.fromResource(elementData.unwrap(), included: included);
    }).toList();


    return Show(
      timelineElements: elements,
      id: resource.attributes['id'],
      name: resource.attributes['name'],
    );
  }

  void updateFromCopy(copy) {
    timelineElements = copy.timelineElements;
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
      'timeline_element_ids': timelineElements.map((element) => element.id).toList(),
    };
  }

  factory Show.create() {
    return Show(
      timelineElements: [],
    );
  }

  bool get isPersisted => id != null;

  Future<Map<dynamic, dynamic>> save({modeDuration}) {
    var method = isPersisted ? Client.updateShow : Client.createShow;
    var attributes = toMap();

    if (!isPersisted) {
      attributes['mode_duration'] = modeDuration?.inMilliseconds;
      attributes['duration'] = duration.inMilliseconds;
      attributes['song_ids'] = songIds;
      attributes['mode_ids'] = modeIds;
    }
    return method(attributes);
  }

}



