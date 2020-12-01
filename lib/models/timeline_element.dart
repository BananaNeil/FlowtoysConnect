import 'package:app/helpers/duration_helper.dart';
import 'package:app/models/nested_timeline.dart';
import "package:collection/collection.dart";
import 'package:app/models/mode_param.dart';
import 'package:app/app_controller.dart';
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

  Duration nestedStartOffset;
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
    nestedStartOffset,
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
    this.nestedStartOffset = nestedStartOffset ?? Duration.zero;
  }

  bool get isPersisted => id != null;

  // Duration get localStartOffset => nestedStartOffset ?? startOffset;
  // Duration get localEndOffset => localStartOffset + duration;
  Duration get nestedEndOffset => nestedStartOffset + duration;
  Duration get endOffset => startOffset + duration;
  Duration get midPoint => startOffset + (duration * 0.5);
  String get durationString => twoDigitString(duration);

  String get objectId => object?.id;
  String get objectType => object?.runtimeType.toString();

  Future<Map<dynamic, dynamic>> save() {
    if (showId == null) return Future.value({});
    return ensurePersistedObject().then((_) {
      var method = isPersisted ? Client.updateTimelineElement : Client.createTimelineElement;
      return method(toMap()).then((response) {
        print("SETTING ID: ${response['timelineElement'].id}");
        this.id = response['timelineElement'].id;
      });
    });
  }

  static List<TimelineElement> groupIntoSingleTrack(elements, {childCount, duration, childType, propCounts, useLocalOffsets}) {
    Map<String, List<TimelineElement>> elementsByTimeRange = {};
    List<TimelineElement> globalTimeline = [];
    List<TimelineElement> siblings;
    useLocalOffsets ??= false;

    // Group by similarities
    elementsByTimeRange = TimelineElement.groupSimilar(elements);

    print("Grouped Elements by similarities. keys:\n${elementsByTimeRange.keys.join("\n")}\n\n");
    print("Grouped Elements by similarities, values: ${elementsByTimeRange.values.map((r) => r.length)}\n\n");

    // Move identical siblings into global timeline
    List.from(elementsByTimeRange.keys).forEach((key) {
      if (elementsByTimeRange[key].length == childCount) {
        siblings = elementsByTimeRange.remove(key);
        var newElement = siblings.first.dup();
        newElement.object = Mode.fromSiblings(
          siblings.map((element) => element.object).toList()
        );
        globalTimeline.add(newElement);
      }
    });

    if (globalTimeline.isEmpty)
      globalTimeline = [
        TimelineElement(
          nestedStartOffset: Duration.zero,
          startOffset: Duration.zero,
          timelineType: 'modes',
          duration: duration,
        )
      ];

    List<List<TimelineElement>> elementsToBeSubGrouped = elementsByTimeRange.values.toList();
    globalTimeline.sort((a, b) => a.startOffset.compareTo(b.startOffset));

    print("duration: ${duration}");
    print("(use local: ${useLocalOffsets}) globalTimeline: ${globalTimeline.map((t) => [t.timelineType, t.startOffset, t.nestedStartOffset, t.endOffset, t.objectType, t.objectId])}");

    // Create TimelineElements that fill the incongruent spaces
    var offset = duration;
    var globalTimelineLength = globalTimeline.length;
    eachWithIndex(List.from(globalTimeline.reversed), (index, element) {
      var endOffset = useLocalOffsets ? element.nestedEndOffset : element.endOffset;
      if (endOffset < offset)
        globalTimeline.insert(globalTimelineLength - index, TimelineElement(
          duration: offset - endOffset,
          startOffset: endOffset,
          timelineType: 'modes',
          timelineIndex: 0,
        ));
      offset = useLocalOffsets ? element.nestedStartOffset : element.startOffset;
    });

    if (offset > Duration.zero)
      globalTimeline.insert(0, TimelineElement(
        startOffset: Duration.zero,
        timelineType: 'modes',
        duration: offset,
        timelineIndex: 0,
      ));


    // Attach remaining elements to their sub-timeline chunks:
    print("globalTimeline: ${globalTimeline.map((t) => [t.startOffset, t.endOffset, t.objectType, t.objectId])}");
    elementsToBeSubGrouped.forEach((elements) {
      print("FIRST: (use local: ${useLocalOffsets}) id: ${elements.first.id} type: ${elements.first.timelineType} objectType: ${elements.first.objectType} start: ${elements.first.startOffset}, nestedStart: ${elements.first.nestedStartOffset}  End: ${elements.first.endOffset} - ${elements.first.timelineIndex}");
      var element = globalTimeline.firstWhere((globalElement) {
        // This seems a little hackey to me, but when turning
        // prop based nested timelines into group timelines,
        // we need to use nested offsets, not global offsets.
        if (useLocalOffsets)
          return globalElement.startOffset <= elements.first.nestedStartOffset &&
              globalElement.endOffset >= elements.first.nestedEndOffset;
        else
          return globalElement.startOffset <= elements.first.startOffset &&
              globalElement.endOffset >= elements.first.endOffset;
      });
      element.object ??= NestedTimeline(
        trackType: childType,
        propCounts: propCounts,
        duration: element.duration,
      );
      element.object.addElements(elements.toList(), startOffset: useLocalOffsets ? element.nestedStartOffset : element.startOffset);
    });

    globalTimeline.sort((a, b) => a.startOffset.compareTo(b.startOffset));
    eachWithIndex(globalTimeline, (index, element) => element.position = index + 1);
    print("GLOBAL TIMELINE POSITIONS AND TYPES: ${globalTimeline.map((el) => [el.objectType, el.position])}");
    return globalTimeline;
  }


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
      'content_offset': contentOffset?.inMilliseconds,
      'start_offset': startOffset?.inMilliseconds,
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
      'content_offset': contentOffset?.inMilliseconds,
      'start_offset': startOffset?.inMilliseconds,
      'duration': duration?.inMilliseconds,
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
      else if (objectIdentifier.type == 'nested_timelines') {
        object = NestedTimeline.fromMap(objectData.attributes);
      } else print("OBJECT IDENTIFER: ${objectIdentifier} NEEDS IMPLEMENTATION");
    }

    return TimelineElement(
      contentOffset: Duration(milliseconds: resource.attributes['content_offset'] ?? 0),
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
    json = json['data'] ?? json;
    return TimelineElement(
      contentOffset: Duration(milliseconds: json['content_offset'] ?? 0),
      duration: Duration(milliseconds: json['duration']?.floor() ?? 0),
      startOffset: Duration(milliseconds: json['start_offset'] ?? 0),
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


