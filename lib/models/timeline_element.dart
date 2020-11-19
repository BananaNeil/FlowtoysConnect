import 'package:app/models/mode_param.dart';
// import 'package:app/models/base_mode.dart';
// import 'package:app/app_controller.dart';
import 'package:json_api/document.dart';
import 'package:app/models/song.dart';
import 'package:app/models/mode.dart';
// import 'package:flutter/material.dart';
// import 'package:app/preloader.dart';
import 'package:app/client.dart';
import 'dart:convert';

class TimelineElement {

  Duration startOffset;
  String timelineType;

  int timelineIndex;
  Duration duration;
  dynamic object;
  String showId;
  int position;
  String id;

  TimelineElement({
    this.timelineIndex,
    this.timelineType,
    this.startOffset,
    this.position,
    this.duration,
    this.showId,
    this.object,
    this.id,
  });

  bool get isPersisted => id != null;

  Duration get endOffset => startOffset + duration;
  Duration get midPoint => startOffset + (duration * 0.5);

  String get objectId => object?.id;
  String get objectType => object?.runtimeType.toString();

  Future<Map<dynamic, dynamic>> save() {
    if (showId == null) return Future.value({});
    return ensurePersistedObject().then((_) {
      var method = isPersisted ? Client.updateTimelineElement : Client.createTimelineElement;
      return method(toMap());
    });
  }

  Future<void> ensurePersistedObject() {
    if (!object.isPersisted) return object.save();
    else return Future.value(true);
  }

  Map<String, dynamic> toObjectMap() {
    return {
      'startOffset': startOffset?.inMilliseconds,
      'duration': duration?.inMilliseconds,
      'timeline_index': timelineIndex,
      'timeline_type': timelineType,
      'position': position,
      'show_id': showId,
      'object': object,
      'id': id,
    } as Map;
  }

  Map<String, dynamic> toMap() {
    return {
      'object_type': objectType,
      'startOffset': startOffset?.inMilliseconds,
      'duration': duration?.inMilliseconds,
      'timeline_index': timelineIndex,
      'timeline_type': timelineType,
      'object_id': object.id,
      'position': position,
      'show_id': showId,
      'id': id,
    } as Map;
  }

  TimelineElement dup() {
    var attributes = toObjectMap();
    attributes['id'] = null;

    if (objectType == 'Mode')
      attributes['object'] = object.dup();

    return TimelineElement.fromMap(attributes);
  }

  factory TimelineElement.fromObject(dynamic object) {
    return TimelineElement(
      duration: object.duration,
      object: object,
    );
  }

  factory TimelineElement.fromResource(Resource resource, {included}) {
    var objectIdentifier = resource.toOne['object'];
    var object;
    if (objectIdentifier != null) {
      var objectData = (included ?? []).firstWhere((data) {
        return data.type == objectIdentifier.type && data.id == objectIdentifier.id;
      }, orElse: () => null);

      if (objectIdentifier.type == 'modes')
        object = Mode.fromMap(objectData.attributes);
      else if (objectIdentifier.type == 'songs')
        object = Song.fromMap(objectData.attributes);
    }

    return TimelineElement(
      duration: Duration(milliseconds: resource.attributes['duration'] ?? 0),
      timelineIndex: resource.attributes['timeline_index'],
      timelineType: resource.attributes['timeline_type'],
      position: resource.attributes['position'],
      showId: resource.attributes['show_id'],
      id: resource.attributes['id'],
      object: object,
    );
  }

  factory TimelineElement.fromMap(Map<String, dynamic> json) {
    return TimelineElement(
      duration: Duration(milliseconds: json['duration']?.floor() ?? 0),
      timelineIndex: json['timeline_index'],
      timelineType: json['timeline_type'],
      position: json['position'],
      showId: json['show_id'],
      object: json['object'],
      id: json['id'],
    );
  }

  factory TimelineElement.fromJson(String body) {
    return TimelineElement.fromMap(jsonDecode(body));
  }

  static List<TimelineElement> fromList(List<dynamic> objects) {
    return objects.map((object) {
      return TimelineElement.fromObject(object);
    }).toList();
  }
}


