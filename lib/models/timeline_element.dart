import 'package:app/helpers/duration_helper.dart';
import "package:collection/collection.dart";
import 'package:app/models/mode_param.dart';
import 'package:app/app_controller.dart';
// import 'package:app/models/base_mode.dart';
// import 'package:app/app_controller.dart';
import 'package:json_api/document.dart';
import 'package:app/models/song.dart';
import 'package:app/models/mode.dart';
import 'package:app/models/show.dart';
// import 'package:flutter/material.dart';
// import 'package:app/preloader.dart';
import 'package:app/client.dart';
import 'dart:convert';




class TimelineElement {

  Duration contentOffset;
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
    this.contentOffset,
    this.timelineType,
    this.startOffset,
    this.position,
    this.duration,
    this.showId,
    this.object,
    this.id,
  }) {
  }

  bool get isPersisted => id != null;

  Duration get endOffset => startOffset + duration;
  Duration get midPoint => startOffset + (duration * 0.5);
  String get durationString => twoDigitString(duration);

  String get objectId => object?.id;
  String get objectType => object?.runtimeType.toString();

  static Map<String, List<TimelineElement>> groupSimilar(elements) {
    return groupBy(elements, (element) {
      return [
        element.objectType == 'Mode' ?
            element.object.baseModeId : element.object?.id,
        element.startOffset,
        element.duration,
      ].toString();
    });
  }

  Future<void> ensurePersistedObject() {
    if (object != null && !object.isPersisted) return object.save();
    else return Future.value(true);
  }

  Map<String, dynamic> toObjectMap() {
    return {
      'content_offset': contentOffset?.inMicroseconds,
      'start_offset': startOffset?.inMicroseconds,
      'duration': duration?.inMicroseconds,
      'timeline_index': timelineIndex,
      'timeline_type': timelineType,
      'position': position,
      'object': object,
    } as Map;
  }

  Map<String, dynamic> toMap() {
    return {
      'content_offset': contentOffset?.inMicroseconds,
      'start_offset': startOffset?.inMicroseconds,
      'duration': duration?.inMicroseconds,
      'timeline_index': timelineIndex,
      'timeline_type': timelineType,
      'object_type': objectType,
      'object_id': object?.id,
      'position': position,
      'show_id': showId,
      'id': id,
    } as Map;
  }

  TimelineElement dup() {
    var attributes = toObjectMap();
    attributes['id'] = null;

    return TimelineElement.fromMap(attributes);
  }

  factory TimelineElement.fromObject(dynamic object) {
    return TimelineElement(
      duration: object.duration,
      object: object,
    );
  }


  factory TimelineElement.fromMap(Map<String, dynamic> json) {
    json = json['data'] ?? json;
    return TimelineElement(
      contentOffset: Duration(microseconds: json['content_offset'] ?? 0),
      duration: Duration(microseconds: json['duration']?.floor() ?? 0),
      startOffset: Duration(microseconds: json['start_offset'] ?? 0),
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

  static List<TimelineElement> fromData(List<dynamic> data, {show, objects}) {
    return data.map((element) {
      var object;
      if (element['object_type'] == 'Show')
        object = Show(
          modeTimeline: element['mode_timeline'],
          propCounts: show.propCounts,
          trackType: 'props',
          modes: objects,
        );
      else
        object = objects.firstWhere((obj) {
          return obj.runtimeType.toString() == element['object_type'] &&
            obj.id == element['object_id'];
        }, orElse: () => null);

      return TimelineElement(
        duration: Duration(microseconds: element['duration']),
        object: object,
      );
    }).toList();
  }

  static List<TimelineElement> fromList(List<dynamic> objects) {
    return objects.map((object) {
      return TimelineElement.fromObject(object);
    }).toList();
  }

  Map<String, dynamic> asJson() {
    Map<String, dynamic> json = {
      'object_type': objectType,
      'duration': duration.inMicroseconds,
    };
    if (['Mode', 'Song'].contains(objectType))
      json['object_id'] = objectId;
    else if (objectType == 'Show')
      json['mode_timeline'] = object.modeTimelineAsJson;

    return json;
  }
}


