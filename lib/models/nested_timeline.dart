import 'package:app/models/timeline_element.dart';
import "package:collection/collection.dart";
import 'package:app/app_controller.dart';
import 'package:json_api/document.dart';
import 'package:app/client.dart';

class NestedTimeline {
  List<TimelineElement> timelineElements;
  List<dynamic> timelineElementIds;
  List<dynamic> propCounts;
  Duration duration;
  String trackType;
  String id;

  NestedTimeline({
    this.id,
    this.duration,
    this.trackType,
    this.propCounts,
    timelineElements,
    this.timelineElementIds,
  }) {
    this.timelineElements = timelineElements ?? [];
  }

  bool get isPersisted => id != null;

  Future<Map<dynamic, dynamic>> save() {
    var method = isPersisted ? Client.updateNestedTimeline : Client.createNestedTimeline;

    // I think you should create a bulk "create timeline" method here... maybe?
    return Future.wait(timelineElements.map((element) => element.save()).toList()).then((response) {
      return method(this).then((response) {
        if (response['success']) {
          this.id = id ?? response['nestedTimeline'].id;

          // This isn't really necessary, but seems right for good measure?
          // assignAttributesFromCopy(response['nestedTimeline']);

          response['id'] = id;
          response['nestedTimeline'] = this;
        } else {
          // else Fail some how?
          print("FAIL SAVE NESTED TIMELINE: ${response['message']}");
        }
        return response;
      });
    });
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'track_type': trackType,
      'prop_counts': propCounts,
      'duration': duration.inMilliseconds,
      'timeline_element_ids': timelineElements.map((element) => element.id).toList(),
    };
  }

  factory NestedTimeline.fromResource(Resource resource, {included}) {
    print("NESTED TIME LINE HAS ELs: ${resource.toMany['timeline_elements'].length}");
    var elements = resource.toMany['timeline_elements'].map((element) {
      var elementData = (included ?? []).firstWhere((item) => item.id == element.id);
      return TimelineElement.fromResource(elementData.unwrap(), included: included);
    }).toList();

    var json = resource.attributes;
    json['timeline_elements'] = elements;

    return NestedTimeline.fromMap(json);
  }

  factory NestedTimeline.fromMap(Map<String, dynamic> json) {
    return NestedTimeline(
      trackType: json['track_type'],
      propCounts: json['prop_counts'],
      timelineElementIds: json['timeline_element_ids'],
      duration: Duration(milliseconds: json['duration'] ?? 0),
      id: json['id'],
    );
  }

  List<TimelineElement> elementsAt(groupIndex, [propIndex = null, timelineIndex = null]) {
    if (trackType == 'props')
      if (propIndex == null) {
        List<TimelineElement> track;
        int trackOffset = sumList(propCounts.sublist(0, timelineIndex));
        int trackCount = propCounts[groupIndex];
        print("Truning props into groups, timline index: ${timelineIndex} track_count: ${elementTracks.length} sublisting:(${trackOffset} ${trackCount}");
        var tracksToCombine = elementTracks.sublist(trackOffset, trackOffset + trackCount);
        var elements = tracksToCombine.expand((el) => el).toList();


        print("@@@ Grouping nested props into groups: ${elements.map((e) => e.endOffset).join(", ")}");
        return TimelineElement.groupIntoSingleTrack(elements,
          childCount: trackCount,
          propCounts: propCounts,
          useLocalOffsets: true,
          childType: 'props',
          duration: duration,
        );
      } else return elementTracks[timelineIndex];
    else if (trackType == 'groups')
      if (propIndex == null)
        return elementTracks[groupIndex];
      else {
        List<TimelineElement> elements = [];
        var track = elementTracks[groupIndex];
        track.forEach((element) {
          if (element.objectType == 'NestedTimeline') {
            element.object.elementsAt(groupIndex, propIndex, timelineIndex).forEach((trackElement) {
              trackElement.timelineIndex = timelineIndex;
              elements.add(trackElement);
            });
          } else {
            var dup = element.dup();
            dup.timelineIndex = timelineIndex;
            // This is a little weird, but in this case, the mode is
            // already a subMode, where it's direct children are props
            dup.object?.setAsSubMode(groupIndex: propIndex);
            elements.add(dup);
          }
        });
        
        return elements;
      }



  }

  void setStartOffset(offset) {
    timelineElements.forEach((element) {
      element.startOffset = offset + element.nestedStartOffset;
    });
  }

  List<List<TimelineElement>> elementTracks;

  void addElements(newElements, {startOffset}) {
    print("@@@ ADD ELEMTNS ${newElements.length}");
    timelineElements.addAll(newElements);

    elementTracks = groupBy(timelineElements, (element) {
      return element.timelineIndex;
    }).values.toList()
      ..sort((a, b) => a.first.timelineIndex.compareTo(b.first.timelineIndex));

    elementTracks.forEach((elements) {
      elements.sort((a, b) => a.position.compareTo(b.position));
      Duration offset = Duration.zero;
      eachWithIndex(elements, (index, element) {
        element.nestedStartOffset = offset;
        element.timelineType = 'nested';
        element.position = index + 1;
        offset += element.duration;
      });
      // print("@@@ ADDed elements to nested timeline: ${elements.map((e) => e.endOffset).join(", ")}");
    });
    setStartOffset(startOffset);
  }
}
