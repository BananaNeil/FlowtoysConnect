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
    this.timelineType,
    contentOffset,
    startOffset,
    this.position,
    this.duration,
    this.showId,
    this.object,
    this.id,
  }) {
    this.startOffset = startOffset ?? Duration.zero;
    this.contentOffset = contentOffset ?? Duration.zero;
  }

  bool get isPersisted => id != null;

  Duration get endOffset => startOffset + duration;
  Duration get midPoint => startOffset + (duration * 0.5);
  String get durationString => twoDigitString(duration);

  String get objectId => object?.id;
  String get objectType => object?.runtimeType.toString();
  String get timelineKey => [
    objectType == 'Mode' ?
        object.baseModeId : objectId,
    startOffset, duration,
  ].toString();

  static Map<String, List<TimelineElement>> groupSimilar(elements) {
    return groupBy(elements, (element) => element.timelineKey);
  }

  List<Mode> modesAtTime(time) {
    if (objectType == 'Show') {
      Duration localTime = time - startOffset;
      return localNestedModeTracks.map<Mode>((List<TimelineElement> nestedTrack) {
          return nestedTrack.firstWhere((element) {
             return element.startOffset <= localTime &&
                 element.endOffset > localTime;
          }, orElse: () => null)?.object;
      }).toList();
    } else return [object];
  }

  void stretchBy(ratio) {
    this.duration *= ratio;
    if (this.objectType == 'Show')
      this.object.stretchBy(ratio);
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
          // audioTimeline: [],
        ); 
      else
        object = objects?.firstWhere((obj) {
          return obj.runtimeType.toString() == element['object_type'] &&
            obj.id == element['object_id'];
        }, orElse: () => null);

      return TimelineElement(
        contentOffset: Duration(microseconds: element['content_offset'] ?? 0),
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

  List<List<TimelineElement>> get localNestedModeTracks {
    if (objectType != 'Show') return [];
    contentOffset ??= Duration.zero;
    var trackCount = object.propCount;
    List<List<TimelineElement>> tracks = List.generate(object.modeTracks.length, (index) => []);
    List.generate(object.modeTracks.length, (timelineIndex) {
      object.modeTracks[timelineIndex].forEach((nestedElement) {
        var _nestedElement = nestedElement.dup();
        if (contentOffset < nestedElement.endOffset && duration > nestedElement.startOffset - contentOffset) {
          _nestedElement.duration = minDuration(nestedElement.endOffset, contentOffset + duration)
              - maxDuration(nestedElement.startOffset, contentOffset);
          tracks[timelineIndex].add(_nestedElement);
        }
      });
    });
    eachWithIndex(tracks, (trackIndex, track) {
      var offset = Duration.zero;
      track.forEach((element) {
        element.timelineIndex = trackIndex;
        element.startOffset = offset;
        offset += element.duration;
      });
    });
    return tracks;
  }

  Map<String, dynamic> asJson() {
    Map<String, dynamic> json = {
      'object_type': objectType,
      'duration': duration.inMicroseconds,
      'content_offset': contentOffset?.inMicroseconds,
    };
    if (['Mode', 'Song'].contains(objectType))
      json['object_id'] = objectId;
    else if (objectType == 'Show')
      json['mode_timeline'] = object.modeTimelineAsJson;

    return json;
  }
}


