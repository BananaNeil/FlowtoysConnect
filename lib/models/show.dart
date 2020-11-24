import 'package:app/helpers/duration_helper.dart';
import 'package:app/models/timeline_element.dart';
import 'package:app/models/nested_timeline.dart';
import "package:collection/collection.dart";
import 'package:app/app_controller.dart';
import 'package:app/authentication.dart';
import 'package:json_api/document.dart';
import 'package:app/models/mode.dart';
import 'package:app/models/song.dart';
import 'package:app/models/group.dart';
import 'package:app/preloader.dart';
import 'package:app/client.dart';
import 'dart:collection';
import 'dart:convert';
import 'dart:async';
import 'dart:math';

class Show {
  List<TimelineElement> timelineElements = [];
  String editMode = 'global';
  List<int> propCounts;
  int audioByteSize;
  String name;
  String id;

  Show({
    this.id,
    this.name,
    this.editMode,
    this.propCounts,
    this.audioByteSize,
    this.timelineElements,
  });

  int get groupCount => propCounts.length;
  int get propCount => propCounts.reduce((a, b) => a + b);

  bool get audioDownloadedPending {
    return audioElements.any((element) {
      return element.objectType == 'Song' && element.object.fileDownloadPending;
    });
  }

  bool get audioDownloaded {
    return audioElements.every((element) {
      return element.objectType != 'Song' || element.object.isDownloaded;
    });
  }

  List<TimelineElement> get audioElements => timelineElements.where((element) {
    return element.timelineType == 'audio';
  }).toList()..sort((a, b) => a.position.compareTo(b.position));

  List<TimelineElement> _modeElements;
  List<TimelineElement> reloadModeElements() {
    // if (editMode == 'global')
    //   _modeElements = timelineElements.where((element) {
    //     return element.timelineType == 'modes';
    //   }).toList()..sort((a, b) => a.position.compareTo(b.position));
    // else if (editMode == 'groups')
    // return _modeElements;


    _modeElements = timelineElements.where((element) {
      return element.timelineType == 'modes';
    }).toList()..sort((a, b) => a.position.compareTo(b.position));
    return _modeElements;
  }

  List<TimelineElement> get globalModeElements {
    // List<TimelineElement> timelines = groupBy(timelineElements, (element) => element.timelineIndex).values();
    List<TimelineElement> globalTimeline = [];
    if (editMode == 'global')
      return modeElements;
    else {
      Map<String, List<TimelineElement>> elementsByTimeRange = {};
      List<TimelineElement> siblings;
      int childCount;

      if (editMode == 'groups') 
        childCount = groupCount;
      else childCount = propCount;


      // Group by similarities
      elementsByTimeRange = groupBy(modeElements, (element) {
        return [
          element.objectType == 'Mode' ?
              element.object.baseModeId : null,
          element.startOffset,
          element.duration,
        ].toString();
      });


      // Move identical siblings into global timeline
      elementsByTimeRange.keys.forEach((key) {
        if (elementsByTimeRange[key].length == childCount) {
          siblings = elementsByTimeRange.remove(key);
          var newElement = siblings.first.dup();
          newElement.object = Mode.fromSiblings(
            siblings.map((element) => element.object).toList()
          );
          globalTimeline.add(newElement);
        }
      });

      List<List<TimelineElement>> elementsToBeSubGrouped = elementsByTimeRange.values;
      globalTimeline.sort((a, b) => a.startOffset.compareTo(b.startOffset));


      // Create TimelineElements that fill the incongruent spaces
      var offset = duration;
      eachWithIndex(globalTimeline.reversed, (index, element) {
        if (element.endOffset < offset)
          globalTimeline.insert(globalTimeline.length - index, TimelineElement(
            startOffset: element.endOffset,
            duration: offset - element.endOffset,
          ));
        offset = element.startOffset;
      });


      // Attach remaining elements to their sub-timeline chunks:
      elementsToBeSubGrouped.forEach((elements) {
        var element = globalTimeline.firstWhere((globalElement) {
          return globalElement.startOffset <= elements.first.startOffset &&
              globalElement.endOffset >= elements.first.endOffset;
        });
        element.object ??= NestedTimeline();
        element.object.addElements(elements);
      });

      // Save global timeline
      eachWithIndex(globalTimeline, (index, element) => element.position = index);
      // saveAndOverwrite();

      return globalTimeline;

    }
  }

  List<TimelineElement> get modeElements => _modeElements ?? reloadModeElements();

  List<TimelineElement> modeElementsFor({groupIndex, propIndex}) {
    return modeElements.map((element) {
      var dup = element.dup();
      dup.object.setAsSubMode(groupIndex: groupIndex, propIndex: propIndex);
      print("OBJ SET: ${dup.object.childType}");
      return dup;
    }).toList();
  }

  TimelineElement addAudioElement(song) {
    var element = TimelineElement(
      position: audioElements.isEmpty ? 1 : audioElements.last.position + 1,
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
    reloadModeElements();
  }

  void clearModes() {
    this.timelineElements = timelineElements.where((element) {
      return element.timelineType != 'modes';
    }).toList();
  }

  List<String> get songIds => audioElements.map((element) => element.objectId).toList();
  List<String> get modeIds => modeElements.map((element) => element.objectId).toList();

  String get durationString => twoDigitString(duration);

  Duration get duration {
    if (audioElements.length == 0 && modeElements.length == 0) return Duration(minutes: 1);
    if (songDuration == Duration() && modeDuration == Duration()) return Duration(minutes: 1);
    return maxDuration(songDuration, modeDuration);
  }

  Duration get songDuration {
    var songDurations = audioElements.map((song) => song.duration);
    if (songDurations.length == 0) return Duration();
    return songDurations.reduce((a, b) => a+b); 
  }

  Duration get modeDuration {
    var modeDurations = modeElements.map((mode) => mode.duration ?? Duration());
    if (modeDurations.length == 0) return Duration();
    return modeDurations.reduce((a, b) => a+b); 
  }

  Future<void> downloadSongs() {
    return Future.wait(audioElements.map((element) {
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
      editMode: resource.attributes['edit_mode'],
      propCounts: resource.attributes['propCounts'],
      audioByteSize: resource.attributes['audio_byte_size'],
    );
  }

  void updateFromCopy(copy) {
    audioByteSize = copy.audioByteSize;
    timelineElements = copy.timelineElements;
    propCounts = copy.propCounts;
    editMode = copy.editMode;
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
      'edit_mode': editMode,
      'prop_counts': propCounts,
      'audio_byte_size': audioByteSize,
      'timeline_element_ids': timelineElements.map((element) => element.id).toList(),
    };
  }

  factory Show.create() {
    return Show(
      editMode: 'global',
      timelineElements: [],
      propCounts: Group.currentGroups.map((group) => group.props.length).toList(),
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



