import 'package:app/helpers/duration_helper.dart';
import 'package:app/models/timeline_element.dart';
import "package:collection/collection.dart";
import 'package:app/app_controller.dart';
import 'package:app/authentication.dart';
import 'package:json_api/document.dart';
import 'package:app/models/mode.dart';
import 'package:app/models/song.dart';
import 'package:app/models/group.dart';
import 'package:app/preloader.dart';
import 'package:app/client.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math';

class Show {
  List<Map<String, dynamic>> audioTimeline;
  List<Map<String, dynamic>> modeTimeline;
  List<Mode> modes;
  List<Song> songs;

  String trackType = 'global';
  List<dynamic> propCounts;
  int audioByteSize;
  String name;
  String id;

  Show({
    this.id,
    this.name,
    this.trackType,
    this.propCounts,
    this.modeTimeline,
    this.audioTimeline,
    this.audioByteSize,

    this.songs,
    this.modes,
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

  List<TimelineElement> _audioElements;
  List<TimelineElement> get audioElements {
    if (_audioElements != null) return _audioElements;
    _audioElements = TimelineElement.fromData(audioTimeline, objects: songs);
    return _audioElements;
  }

  // List<TimelineElement> _modeElements;
  // List<TimelineElement> get modeElements {
  //   if (_modeElements != null) return _modeElements;
  //   _modeElements = TimelineElement.fromData(modeTimeline, objects: modes);
  //   return _modeElements;
  // }

  List<TimelineElement> _modeElements;
  List<TimelineElement> reloadModeElements() {
    _modeElements = timelineElements.where((element) {
      return element.timelineType == 'modes';
    }).toList()..sort((a, b) => a.position.compareTo(b.position));

    Duration offset = Duration();
    modeElements.forEach((element) {
      if (element.duration != null) {
        element.startOffset = Duration() + offset;
        offset += element.duration;
      } // otherwise, the show has almost certainly not been created
    });

    return _modeElements;
  }

  List<TimelineElement> get nestedElements {
    return timelineElements.where((element) {
      return element.timelineType == 'nested';
    }).toList();
  }

  List<TimelineElement> recompileModeElements() {
    if (trackType == 'global') return null;
    else {
      List<TimelineElement> elements;
      int childCount;

      elements = (trackType == 'groups' ? groupElements : propElements).expand((el) => el).toList();
      childCount = trackType == 'groups' ? groupCount : propCount;

      var globalTimeline = TimelineElement.groupIntoSingleTrack(elements,
        childCount: childCount,
        propCounts: propCounts,
        childType: trackType,
        duration: duration,
      );

      // Compare timeline elements to the original timeline,
      // and save the ones that have been changed
      var elementComparison = TimelineElement.groupSimilar([
        ..._modeElements,
        ...globalTimeline,
      ]);
      // print("Compared elements: ${elementComparison.values.map((v) => v.length).toList()}");
      // print("..._modeElements: ${_modeElements.map((t) => [t.startOffset, t.endOffset, t.objectType, t.objectId])}");
      // print("...globalTimeline: ${globalTimeline.map((t) => [t.startOffset, t.endOffset, t.objectType, t.objectId])}");
      if (false)
        elementComparison.values.forEach((matches) {
          // TODO: Check on changes to the object and potentially save it as well.
          //       Imagine two identical global mode timeline elements, split into props.
          //       Adjust the hue of one prop within one timeline element. When stiching
          //       back together, the mode needs to be updated, and the object ID should
          //       sholud be changed.
          if (matches.length == 1) {
            var element = matches.first;
            if (globalTimeline.contains(element)) {
              element.showId = id;
              // print("Saving EL: ${[element.position, element.startOffset, element.endOffset, element.objectType, element.objectId, element.showId]}");
              element.save();
              timelineElements.add(element);
            } else {
              Client.removeTimelineElement(element);
              timelineElements.remove(element);
            }
          }
        });

      _modeElements = globalTimeline;
      _groupElements = null;
      _propElements = null;
    }
  }

  List<TimelineElement> get modeElements => _modeElements ?? reloadModeElements();

  List<List<TimelineElement>> _groupElements;
  List<List<TimelineElement>> get groupElements => _groupElements = List.generate(groupCount, (index) {
    return modeElementsFor(groupIndex: index, timelineIndex: index);
  }).toList();

  List<List<TimelineElement>> _propElements;
  List<List<TimelineElement>> get propElements {
    var indexOffset = 0;
    if (_propElements != null) return _propElements;
    _propElements = [];
    eachWithIndex(propCounts, (groupIndex, count) {
      var list = List.generate(count, (propIndex) {
        return modeElementsFor(groupIndex: groupIndex, propIndex: propIndex, timelineIndex: indexOffset + propIndex);
      }).toList();
      indexOffset += count;
      _propElements.addAll(list);
    });
    return _propElements;
  }

  List<TimelineElement> modeElementsFor({groupIndex, propIndex, timelineIndex}) {
    List<TimelineElement> elements = [];
    modeElements.forEach((element) {
      print("ELEMENT FOR: ${groupIndex}, ${propIndex}, ${timelineIndex}");
      if (element.objectType == 'NestedTimeline')
        element.object.elementsAt(groupIndex, propIndex, timelineIndex).forEach((trackElement) {
          trackElement.timelineIndex = timelineIndex;
          // if (!trackElement.isPersisted)
          trackElement.startOffset = element.startOffset + trackElement.nestedStartOffset;
          print("Adding nested timeline element: ${trackElement.startOffset} -> ${trackElement.duration}");
          elements.add(trackElement);
        });
      else {
        var dup = element.dup();
        dup.timelineIndex = timelineIndex;
        dup.object?.setAsSubMode(groupIndex: groupIndex, propIndex: propIndex);
        print("Adding mode timeline element: ${element.startOffset} -> ${element.duration}");
        elements.add(dup);
      }
    });
    print("\nThese are the elements for (${groupIndex} ${propIndex}):\n${elements.map((element) => [element.objectType, element.startOffset, element.duration]).join("\n")}\n\n");
    return elements;
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
    var songs = resource.toMany['songs'].map((element) {
      var elementData = (included ?? []).firstWhere((item) => item.id == element.id);
      return Song.fromResource(elementData.unwrap(), included: included);
    }).toList();

    var modes = resource.toMany['modes'].map((element) {
      var elementData = (included ?? []).firstWhere((item) => item.id == element.id);
      return Mode.fromResource(elementData.unwrap(), included: included);
    }).toList();


    Show show = Show(
      songs: songs,
      modes: modes,

      id: resource.attributes['id'],
      name: resource.attributes['name'],
      trackType: resource.attributes['edit_mode'],
      propCounts: resource.attributes['prop_counts'],
      modeTimeline: resource.attributes['mode_timeline'],
      audioTimeline: resource.attributes['audio_timeline'],
      audioByteSize: resource.attributes['audio_byte_size'],
    );

      audioByteSize: resource.attributes['audio_byte_size'],
    );

    // show.reloadModeElements();
    // show.attachNestedElements();
    return show;
  }

  // void attachNestedElements() {
  //   timelineElements.forEach((element) {
  //     if (element.objectType == 'NestedTimeline')
  //       element.object.addElements(
  //         nestedElements.where((el) {
  //           return element.object.timelineElementIds.contains(el.id);
  //         }).toList(),
  //         startOffset: element.startOffset
  //       );
  //   });
  // }

  void updateFromCopy(copy) {
    audioByteSize = copy.audioByteSize;
    audioTimeline = copy.audioTimeline;
    modeTimeline = copy.modeTimeline;
    propCounts = copy.propCounts;
    trackType = copy.trackType;
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
      'track_type': trackType,
      'prop_counts': propCounts,
      'audio_timeline': audioTimeline,
      'audio_byte_size': audioByteSize,
      'mode_timeline': modeTimelineAsJson,
    };
  }

  factory Show.create() {
    return Show(
      timeline: [],
      trackType: 'global',
      propCounts: Group.currentGroups.map((group) => group.props.length).toList(),
    );
  }

  bool get isPersisted => id != null;

  List<Map<String, dynamic>> get modeTimelineAsJson {
    List<TimelineElement> elements;
    int childCount;

    // if (trackType == 'global')

    elements = (trackType == 'groups' ? groupElements : propElements).expand((el) => el).toList();
    childCount = trackType == 'groups' ? groupCount : propCount;
    var globalTimeline = TimelineElement.groupIntoSingleTrack(elements,
      childCount: childCount,
      propCounts: propCounts,
      childType: trackType,
      duration: duration,
    );

    return globalTimeline.map((element) {
      return element.asJson();
    }).toList();
  }

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



