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
  List<dynamic> audioTimeline;
  List<dynamic> modeTimeline;
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
  int get propCount => List<int>.from(propCounts).reduce((a, b) => a + b);

  int _historicalIndex = 0;
  List<Map<String, dynamic>> _history = [];
  bool get canUndo => _history.length > 0 && _historicalIndex + 1 < _history.length;
  bool get canRedo => _history.length > 0 && _historicalIndex > 0;

  void undo() {
    // print("${_history.length > 0} && ${_historicalIndex + 1 < _history.length}");
    if (!canUndo) return;
    _historicalIndex += 1;
    var newState = _history[_historicalIndex];
    modeTimeline = newState['modes'];
    audioTimeline = newState['audio'];
    trackType = newState['trackType'];
    _audioElements = null;
    _modeTracks = null;
  }

  void redo() {
    if (!canRedo) return;
    _historicalIndex -= 1;
    var newState = _history[_historicalIndex];
    modeTimeline = newState['modes'];
    audioTimeline = newState['audio'];
    _audioElements = null;
    _modeTracks = null;
  }

  int groupIndexFromGlobalPropIndex(index) {
    int groupIndex = 0;
    int totalPropCount = 0;
    propCounts.forEach((propCount) {
      totalPropCount += propCount;
      if (index + 1 > totalPropCount)
        groupIndex += 1;
    });
    return groupIndex;
  }

  int localPropIndexFromGlobalPropIndex(index) {
    int groupIndex = groupIndexFromGlobalPropIndex(index);
    return index - sumList(propCounts.sublist(0, groupIndex));
  }

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
    _audioElements = TimelineElement.fromData(audioTimeline ?? [], objects: songs);
    return _audioElements;
  }

  List<List<TimelineElement>> _modeTracks;
  List<List<TimelineElement>> get modeTracks {
    if (_modeTracks != null) return _modeTracks;
    _modeTracks = modeTimeline.map((trackData) {
      return TimelineElement.fromData(trackData, show: this, objects: modes);
    }).toList();
    ensureStartOffsets();
    ensureFilledEndSpace();
    return _modeTracks;
  }

  Mode createNewMode() {
    if (modes.isNotEmpty) return modes.first.dup();
    if (Preloader.modeLists.isNotEmpty && Preloader.modeLists.first.modes.isNotEmpty)
      return Preloader.modeLists.first.modes.first.dup();
    else return Mode.basic();
  }

  double get bpm {
    return audioElements.map((element) {
      return element.object?.bpm;
    }).firstWhere((bpm) => bpm != null,
    orElse: () => null);
  }

  List<List<TimelineElement>> get elementTracks {
    return [...modeTracks, audioElements];
  }

  void resetModeTracks() {
    _modeTracks = null;
  }

  void removeModeElement(element) {
    modeTracks.forEach((track) {
      track.remove(element);
    });
  }

  void ensureStartOffsets() {
    eachWithIndex([...modeTracks, audioElements], (trackIndex, track) {
      var offset = Duration.zero;
      track.forEach((element) {
        element.timelineIndex = trackIndex;
        element.startOffset = offset;
        offset += element.duration;
      });
    });
  }

  void ensureFilledEndSpace() {
    [...modeTracks, audioElements].forEach((track) {
      if (track.isNotEmpty && track.last.endOffset < duration)
        if (track.last.object == null) 
          track.last.duration = duration - track.last.startOffset;
        else
          track.add(TimelineElement(
            startOffset: track.last.endOffset,
            duration: duration - track.last.endOffset,
          ));
    });
  }

  List<TimelineElement> groupIntoSingleTrack(List<List<TimelineElement>> elementTracks) {
    Map<Duration, List<TimelineElement>> elementsByEndOffset = {};
    Map<String, List<TimelineElement>> elementsByTimeRange = {};
    List<TimelineElement> globalTimeline = [];
    int trackCount = elementTracks.length;
    List<Duration> sharedEndOffsets = [];
    List<TimelineElement> siblings;
    ensureStartOffsets();

    // // Group by similarities
    List<TimelineElement> allElements = elementTracks.expand((e) => e).toList(); 
    allElements = allElements.where((element) => element.duration > Duration.zero).toList();
    elementsByTimeRange = TimelineElement.groupSimilar(allElements);
    elementsByEndOffset = groupBy(allElements, (element) => element.endOffset);
    elementsByEndOffset.keys.forEach((endOffset) {
      if (elementsByEndOffset[endOffset].length == trackCount)
        sharedEndOffsets.add(endOffset);
    });



    // Move identical siblings into global timeline
    List.from(elementsByTimeRange.keys).forEach((key) {
      if (elementsByTimeRange[key].length == trackCount) {
        siblings = elementsByTimeRange.remove(key);
        var newElement = siblings.first.dup();
        newElement.object = Mode.fromSiblings(
          siblings.map((element) => element.object).toList(),
          show: this,
        );
        globalTimeline.add(newElement);
      }
    });

    List<List<TimelineElement>> elementsToBeSubGrouped = elementsByTimeRange.values.toList();
    globalTimeline.sort((a, b) => a.startOffset.compareTo(b.startOffset));
    sharedEndOffsets.addAll([duration, Duration.zero]);
    sharedEndOffsets = sharedEndOffsets.toSet().toList();
    sharedEndOffsets.sort();

    // Create TimelineElements that fill the incongruent spaces
    var offset = duration;
    var globalTimelineLength = globalTimeline.length;
    var reversedGlobalTimeline = List.from(globalTimeline.reversed);
    reversedGlobalTimeline.add(TimelineElement(duration: Duration.zero, startOffset: Duration.zero));
    reversedGlobalTimeline.forEach((globalElement) {
      if (offset > globalElement.endOffset) {
        var breakPoints = sharedEndOffsets.where((sharedEndOffset) {
          return sharedEndOffset > globalElement.endOffset && sharedEndOffset <= offset;
        }).toList();
        [...breakPoints.reversed, globalElement.endOffset].forEach((breakPoint) {
          globalTimeline.add(TimelineElement(
            duration: offset - breakPoint,
            startOffset: breakPoint,
            timelineType: 'modes',
            timelineIndex: 0,
          ));
          offset = breakPoint;
        });
      }
      offset = globalElement.startOffset;
    });
    globalTimeline.sort((a, b) => a.startOffset.compareTo(b.startOffset));
    globalTimeline = globalTimeline.where((el) => el.duration > Duration.zero).toList();
    // Attach remaining elements to their sub-timeline chunks:
    elementsToBeSubGrouped.forEach((elements) {
      var element = globalTimeline.firstWhere((globalElement) {
        return globalElement.startOffset <= elements.first.startOffset &&
            globalElement.endOffset >= elements.first.endOffset;
      });
      element.object ??= Show(
        modeTimeline: List.generate(trackCount, (index) => []),
        propCounts: propCounts,
        trackType: trackType,
      );

      element.object.addElements(elements.toList());
      element.object.modeTracks.forEach((track) {
        track.sort((TimelineElement a, TimelineElement b) => a.startOffset.compareTo(b.startOffset));
      });
      element.object.ensureStartOffsets();
    });

    globalTimeline.sort((a, b) => a.startOffset.compareTo(b.startOffset));
    eachWithIndex(globalTimeline, (index, element) => element.position = index + 1);
    return globalTimeline;
  }

  void addElements(elements) {
    elements.forEach((element) {
      var localIndex = element.timelineIndex;
      if (modeTracks.length < propCount)
        localIndex = localPropIndexFromGlobalPropIndex(element.timelineIndex);
      modeTracks[localIndex].add(element.dup());
    });
  }

  void removeAudioElement(element) {
    _audioElements.remove(element);
  }

  TimelineElement addAudioElement(song) {
    var element = TimelineElement(
      duration: song.duration,
      object: song,
    );
    _audioElements.add(element);
    return element;
  }




  String get durationString => twoDigitString(duration);

  void setDuration(duration) {
    _duration = duration;
  }

  Duration _duration;
  Duration get duration {
    if (_duration != null) return _duration;
    if (audioElements.length == 0 && modeTracks.length == 0) return Duration(minutes: 1);
    if (songDuration == Duration() && modeDuration == Duration()) return Duration(minutes: 1);
    return maxDuration(songDuration, modeDuration);
  }

  Duration get songDuration {
    var songDurations = audioElements.map((song) => song.duration);
    if (songDurations.length == 0) return Duration();
    return songDurations.reduce((a, b) => a+b); 
  }

  Duration get modeDuration {
    var max = Duration.zero;
    modeTracks.forEach((track) {
      if (track.isNotEmpty)
        max = maxDuration(max, track.last.endOffset);
    });
    return max;
  }

  Future<void> downloadSongs() {
    return Future.wait(audioElements.map((element) {
      return element.object?.downloadFile() ?? Future.value(true);
    }));
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
      return Mode.fromMap(elementData.unwrap().attributes);
    }).toList();


    Show show = Show(
      songs: songs,
      modes: modes,

      id: resource.attributes['id'],
      name: resource.attributes['name'],
      trackType: resource.attributes['track_type'],
      propCounts: resource.attributes['prop_counts'],
      modeTimeline: resource.attributes['mode_timeline'],
      audioTimeline: resource.attributes['audio_timeline'],
      audioByteSize: resource.attributes['audio_byte_size'],
    );


    // show.reloadModeElements();
    // show.attachNestedElements();
    return show;
  }

  int get byteSize => audioByteSize + (toMap().toString().length);

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
    return Show.fromResource(data.unwrap(), included: data.included);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'track_type': trackType,
      'prop_counts': propCounts,
      'audio_byte_size': audioByteSize,
      'mode_timeline': modeTimelineAsJson,
      'audio_timeline': audioTimelineAsJson,
    };
  }

  factory Show.create() {
    return Show(
      modeTimeline: [],
      audioTimeline: [],
      trackType: 'global',
      propCounts: Group.currentGroups.map((group) => group.props.length).toList(),
    );
  }

  bool get isPersisted => id != null;

  void setEditMode(editMode) {
    if (editMode == trackType) return;
    print("SETING EDIT MODE: ${editMode} ... from ${trackType}");

    if (trackType == 'global')
      if (editMode == 'props')
        splitGlobalTrackIntoProps();
      else {
        setEditMode('props');
        setEditMode('groups');
      }
    else if (editMode == 'global') {
      setEditMode('props');
      combineTracksToGlobal();
    } else if (trackType == 'groups')
      splitGroupsIntoProps();
    else combineTrackToGroups();

    trackType = editMode;
    ensureStartOffsets();

    // reloadModeElements();
  }

  List<TimelineElement> get globalElements => groupIntoSingleTrack(modeTracks);

  void combineTracksToGlobal() {
    _modeTracks = [groupIntoSingleTrack(modeTracks)];
  }

  void combineTrackToGroups() {
    int trackOffset = 0;
    _modeTracks = mapWithIndex(propCounts, (index, trackCount) {
      print("Truning props into groups: group #${index} sublisting:(${trackOffset} ${trackCount}");
      var tracksToCombine = modeTracks.sublist(trackOffset, trackOffset + trackCount);
      trackOffset += trackCount;
      return groupIntoSingleTrack(tracksToCombine);
    }).toList();
  }


  void splitGlobalTrackIntoProps() {
    if (trackType != 'global') return;
    var trackCount = propCount;
    List<List<TimelineElement>> tracks = List.generate(trackCount, (index) => []);
    List.generate(trackCount, (timelineIndex) {
      modeTracks.first.forEach((element) {
        if (element.objectType == 'Show') {
          element.object.setEditMode('props');
          element.localNestedModeTracks[timelineIndex].forEach((nestedElement) {
            tracks[timelineIndex].add(nestedElement.dup());
          });
        } else tracks[timelineIndex].add(element.dup());
      });
    });
    _modeTracks = tracks;
  }

  void stretchBy(ratio) {
    modeTracks.forEach((track) {
      track.forEach((element) => element.duration *= ratio);
    });
    ensureStartOffsets();
  }

  void splitGroupsIntoProps() {
    if (trackType != 'groups') return;
    List<List<TimelineElement>> propTracks = List.generate(propCount, (index) => []);
    var timelineIndex = 0;
    print("before splitting groups.... ${propCounts}");
    eachWithIndex(propCounts, (groupIndex, count) {
      List.generate(count, (propIndex) {
        modeTracks[groupIndex].forEach((element) {
          if (element.objectType == 'Show') {
            // element.object.setEditMode('props'); // should be already props, I think
            element.object.modeTracks[propIndex].forEach((nestedElement) {
              propTracks[propIndex + timelineIndex].add(nestedElement.dup());
            });
          } else propTracks[propIndex + timelineIndex].add(element.dup());
        });
      });
      timelineIndex += count;
    });
    _modeTracks = propTracks;
  }

  List<Map<String, dynamic>> get audioTimelineAsJson {
    return audioElements.map((element) {
      return element.asJson();
    }).toList();
  }

  List<List<Map<String, dynamic>>> get modeTimelineAsJson {
    print("Mode Tracks: ${modeTracks}");
    return modeTracks.map((track) {
      return track.map((element) {
        return element.asJson();
      }).toList();
    }).toList();
  }

  bool get savedToCloud => _history.isEmpty || (_historicalIndex == 0 && _history.first['saved'] == true);

  void generateTimeline(modes, modeDuration) {
    var elementCount = durationRatio(duration, modeDuration);
    var lastElementRatio = elementCount.remainder(1);
    this.modes = modes;
    double modeRatio;
    _modeTracks = [
      List.generate(elementCount.ceil(), (index) {
        modeRatio = (index+1 == elementCount.ceil() ? lastElementRatio : 1.0);
        return TimelineElement(
          object: modes[index % modes.length],
          duration: modeDuration * modeRatio,
        );
      }),
    ];
  }

  Show dup() {
    var attributes = toMap();
    return Show(
      propCounts: attributes['prop_counts'],
      modeTimeline: attributes['mode_timeline'],
      audioTimeline: attributes['audio_timeline'],
      audioByteSize: attributes['audio_byte_size'],
      trackType: attributes['track_type'],
      songs: songs,
      modes: modes,
    );
  }

  Future<Map<dynamic, dynamic>> save() {
    var method = isPersisted ? Client.updateShow : Client.createShow;
    var attributes = toMap();

    _history = _history.sublist(_historicalIndex);
    _historicalIndex = 0;
    _history.insert(0, {
      'trackType': trackType,
      'datetime': DateTime.now(),
      'modes': modeTimelineAsJson,
      'audio': audioTimelineAsJson,
    });
    return method(attributes).then((response) {
      _history.first['saved'] = response['success'];
    });
  }

}



