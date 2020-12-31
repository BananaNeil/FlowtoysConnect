import 'package:flutter_hsvcolor_picker/flutter_hsvcolor_picker.dart';
import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:quiver/iterables.dart' hide max, min;
import 'package:app/components/timeline_track.dart';
import 'package:app/models/timeline_element.dart';
import 'package:app/helpers/duration_helper.dart';
import 'package:app/components/mode_widget.dart';
import 'package:app/components/show_widget.dart';
import 'package:app/components/waveform.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:app/models/group.dart';
import 'package:app/models/mode.dart';
import 'package:flutter/physics.dart';
import 'package:app/models/show.dart';
import 'package:app/client.dart';
import 'dart:typed_data';
import 'dart:async';
import 'dart:math';
import 'dart:io';

class TimelineWidget extends StatefulWidget {
  TimelineWidget({Key key, this.show}) : super(key: key);
  final Show show;

  @override
  _TimelineState createState() => _TimelineState(show);
}

class _TimelineState extends State<TimelineWidget> with TickerProviderStateMixin {
  _TimelineState(this.show);

  Show show;
  String editMode;
  Timer computeDataTimer;

  Map<TimelineElement, AssetsAudioPlayer> audioPlayers = {};
  List<TimelineTrackController> modeTimelineControllers = [];
  TimelineTrackController waveformTimelineController = TimelineTrackController(elements: <TimelineElement>[]);

  List<TimelineTrackController> get timelineControllers => [
    ...modeTimelineControllers,
    waveformTimelineController,
  ].where((controller) => controller != null).toList();


  bool showModeImages = true; 
  bool selectMultiple = false;
  bool snapping = true;
  List<Mode> selectedModes = [];
  bool slideModesWhenStretching = false;
  bool get oneElementSelected => selectedElements.length == 1;
  bool get oneModeSelected => oneElementSelected && selectedElements.first.objectType == 'Mode';
  List<String> get selectedElementIds => selectedElements.map((element) => element.id);
  List<TimelineElement> get selectedElements => timelineControllers.map((controller) {
    return controller.selectedElements;
  }).expand((e) => e).toList();

  List<TimelineElement> get selectedModeElements => modeTimelineControllers.map((controller) {
    return controller.selectedElements;
  }).expand((e) => e).toList();

  List<TimelineTrackController> get selectedModeControllers => modeTimelineControllers.where((controller) {
    return controller.selectedElements.isNotEmpty;
  }).toList();

  List<TimelineTrackController> get selectedElementControllers => timelineControllers.where((controller) {
    return controller.selectedElements.isNotEmpty;
  }).toList();

  List<int> get selectedElementTimelineIndexes => selectedElementControllers.map((controller) => controller.timelineIndex).toList();

  List<TimelineElement> _allElements;
  List<TimelineElement> get allElements {
    return _allElements ??= show.modeTracks.expand((track) => track).toList();
  }

  List<Duration> _inflectionPoints;
  List<Duration> get inflectionPoints {
    return _inflectionPoints ??= allElements.map<List<Duration>>((el) {
      if (el.objectType == 'Show')
        return el.localNestedModeTracks.expand<TimelineElement>((List<TimelineElement> nestedEl) => nestedEl)
            .map<Duration>((TimelineElement nestedEl) => nestedEl.endOffset + el.startOffset).toList();
      else return [el.endOffset];
    }).expand((dur) => dur).toSet().toList();
  }

  double scale;
  double futureScale;
  double get maxScale => max(1, duration.inSeconds / 5);

  bool isPlaying = false;

  Duration duration;
  int get lengthInMicroseconds => duration.inMicroseconds;
  Duration get visibleDuration => duration * (1 / scale);
  Duration get futureVisibleDuration => duration * (1 / futureScale);
  double get visibleMicroseconds => (lengthInMicroseconds / scale);
  double get remainingMicroseconds => lengthInMicroseconds - playOffset.value;
  double get futureVisibleMicroseconds => (lengthInMicroseconds / futureScale);


  AnimationController startOffset;
  AnimationController playOffset;

  Duration get playOffsetDuration => Duration(microseconds: playOffset.value.toInt());


  double scrollbarWidth = 0;
  double containerWidth = 0;
  double containerHeight = 0;
  double playHeadWidth = 20.0;

  void setContainerHeight(_height) {
    if (this.containerHeight != _height) {
      this.containerHeight = _height;
    }
  }

  void setContainerWidth(_width) {
    if (this.containerWidth != _width) {
      this.containerWidth = _width;
      setScrollBarWidth();
    }
  }

  Future save() {
    return show.save().then((_) => setState((){}));
  }

  double get scrollContainerWidth => containerWidth * 0.97;
  bool get timelineContainsStart => startOffset.value <= 0;
  bool get timelineContainsEnd => startOffset.value + futureVisibleMicroseconds >= lengthInMicroseconds;
  double get microsecondsPerPixel => visibleMicroseconds / containerWidth;

  bool modesLoaded = false;
  bool loading = false;


  double timelineGestureStartPointX;


  Map<TimelineElement, WaveformController> waveforms = {};
  // List<Duration> get songDurations => waveforms.map((song) => song.duration).toList();

  Duration get windowStart => Duration(microseconds: startOffset.value.toInt());
  Duration get windowEnd => windowStart + Duration(microseconds: visibleMicroseconds.toInt());

  visibleDurationOf(object) {
    var objectVisibleDuration;
    if (object.startOffset < windowStart)
      objectVisibleDuration = minDuration(visibleDuration, object.endOffset - windowStart);
    else if (object.endOffset > windowEnd)
      objectVisibleDuration = minDuration(visibleDuration, windowEnd - object.startOffset);
    else objectVisibleDuration = object.duration;

    return minDuration(objectVisibleDuration, object.duration);
  }



  @override dispose() {
    startOffset.dispose();
    playOffset.dispose();
    audioPlayers.values.forEach((player) => player.dispose());
    super.dispose();
  }

  @override initState() {
    startOffset = AnimationController(vsync: this);
    playOffset = AnimationController(vsync: this);

    editMode = 'global';
    super.initState();
  }

  List<TimelineElement> get currentElements => timelineControllers.map((controller) {
    return controller.elementAtTime(playOffsetDuration);
  }).toList();

  TimelineElement get currentAudioElement {
    return waveformTimelineController.elementAtTime(playOffsetDuration);
  }

  AssetsAudioPlayer get currentPlayer {
    return audioPlayers[currentAudioElement];
  }

  void _selectionUpdate(_controller) {
    if (!selectMultiple && _controller.selectedElements.isNotEmpty)
      timelineControllers.forEach((controller) {
        if (controller.timelineIndex != _controller.timelineIndex)
          controller.deselectAll();
      });
    setState(() {});
  }

  void reloadModes() {
    setState(() {
      loadModes(force: true);
    });
  }

  void loadModes({force}) {
    if (modesLoaded && force != true) return;
    modesLoaded = true;

    if (duration != null)
      scale *= show.duration.inMicroseconds / duration.inMicroseconds;

    _inflectionPoints = null;
    _allElements = null;

    duration = show.duration;
    if (scale == null)
      scale = show.modeTracks.length / 12.0;
    scale = scale.clamp(1.0, maxScale);
    futureScale = scale;
    setAnimationControllers();

    modeTimelineControllers = mapWithIndex(show.modeTracks, (index, trackElements) {
      return TimelineTrackController(
        onSelectionUpdate: _selectionUpdate,
        selectMultiple: selectMultiple,
        elements: trackElements,
        timelineIndex: index,
      );
    }).toList();
    setScrollBarWidth();
    waveformTimelineController.timelineIndex = modeTimelineControllers.length;
  }

  void loadPlayers() {
    var waveformLengthWas = waveforms.keys.length;
    List.from(waveforms.keys).forEach((element) {
      if (!show.audioElements.contains(element))
        waveforms.remove(element);
    });

    if (waveformLengthWas == waveforms.keys.length)
      if (waveforms.keys.length == show.audioElements.length)
        return setState(() => loading = false);

    waveformTimelineController.elements = show.audioElements;
    var offset = Duration();
    show.audioElements.forEach((element) {
      element.startOffset = Duration() + offset;
      offset += element.duration;
    });

    loadAudioPlayers().then((_) {
      var lengthInMicroseconds = 0.1;
      var index = 0;
      mapWithIndex(show.audioElements, (index, element) {
        waveforms[element].startOffset = element.startOffset;
      });
      waveformTimelineController = TimelineTrackController(
        timelineIndex: modeTimelineControllers.length,
        onSelectionUpdate: _selectionUpdate,
        selectMultiple: selectMultiple,
        elements: show.audioElements,
      );
      setState(() {
        reloadModes();
        setAnimationControllers();
      });
    });
  }

  Future<dynamic> loadAudioPlayers() {
    if (show == null) return Future.value(null);
    return show.downloadSongs().then((_) {
      print("Okay, done downloading files... ");
      setState(() {
        show.audioElements.forEach((element) => waveforms[element] = WaveformController.open(element.object?.localPath));
        loading = false;
      });

      audioPlayers = {};
      AssetsAudioPlayer player;
      return Future.wait(show.audioElements.map((element) {
        player = AssetsAudioPlayer.newPlayer();
        audioPlayers[element] = player;
        if (element.object == null)
          return Future.value(true);

        return player.open(Audio.file(element.object.localPath,
          metas: Metas(
            title:  "Insert Show Name",
            artist: "Username",
            album: "Flowtoys App",
            // image: MetasImage.asset("assets/images/logo.png"), //can be MetasImage.network
          ),
        ), autoStart: false, showNotification: true);
      }));
    });
  }

  void setAnimationControllers() {
    setStartOffset();
    setPlayOffset();
  }

  void setStartOffset() {
    var currentOffsetValue = startOffset?.value ?? 0;
    startOffset?.dispose();
    startOffset = AnimationController(
      upperBound: lengthInMicroseconds - visibleMicroseconds,
      value: currentOffsetValue,
      lowerBound: 0,
      vsync: this
    );
  }

  void setPlayOffset() {
    var value = playOffset?.value ?? 0;
    playOffset = AnimationController(
      upperBound: lengthInMicroseconds.toDouble(),
      lowerBound: 0,
      vsync: this
    );
    playOffset.value = value;
  }

  void setScrollBarWidth() {
    if (scrollContainerWidth > 0)
      scrollbarWidth = (scrollContainerWidth / futureScale).clamp(10.0, scrollContainerWidth).toDouble();
  }

  void updatePlayIndicatorAnimation() {
    if (currentAudioElement?.object != null) {
      var startOffset = currentAudioElement.startOffset - (currentAudioElement.contentOffset ?? Duration.zero);
      currentPlayer.seek(Duration(microseconds: playOffset.value.toInt()) - startOffset);
    }

    if (isPlaying) {
      currentPlayer.play();
      playOffset.animateTo(lengthInMicroseconds.toDouble(),
        duration: Duration(microseconds: remainingMicroseconds.toInt()),
      );
    } else {
      audioPlayers.values.forEach((player) => player.pause());
      playOffset.stop();
    }

    setState((){});
  }

  void removeSelected({growFrom, replaceWithBlack}) {
    timelineControllers.forEach((controller) {
      var replacedIndexes = [];
      controller.selectedElements.reversed.forEach((element) {
        var index = controller.elements.indexOf(element);
        var sibling;

        if (replacedIndexes.contains(index+1)) {
          replaceWithBlack = false;
          growFrom = 'right';
        }

        if (growFrom == 'right')
          if (index < controller.elements.length - 1)
            sibling = controller.elements[index + 1];
          else replaceWithBlack = true;
        else if (growFrom == 'left')
          if (index > 0)
            sibling = controller.elements[index - 1];
          else replaceWithBlack = true;
        // else sibling = show.modes.last;

        setState(() {
          if (replaceWithBlack == true) {
            replacedIndexes.add(index);
            element.object = null;
          } else {
            sibling?.duration += element.duration;
            controller.elements.remove(element);
            show.elementTracks[controller.timelineIndex].remove(element);
          }
        });
      });
      controller.selectedElements = [];
    });
    show.ensureStartOffsets();
    show.ensureFilledEndSpace();
    save();
    reloadModes();
  }

  @override
  Widget build(BuildContext context) {
    show ??= (ModalRoute.of(context).settings.arguments as Map)['show']; 
    editMode = show.trackType;
    loadPlayers();
    loadModes();

    return Center(
      child: Container(
        padding: EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.black,
          )
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) {
            setContainerHeight(box.maxHeight);
            setContainerWidth(box.maxWidth);

            if (loading)
              return SpinKitCircle(color: AppController.blue);

            // if (audioPlayers.length == 0)
            //   return Container();

            return Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Controls(),
                // Timeline:
                AnimatedBuilder(
                  animation: startOffset,
                  builder: (ctx, w) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _Timestamps(),
                        _TimelineContainer(),
                        _ScrollBar(),
                        Container(
                          margin: EdgeInsets.only(right: 10, left: 10, top: 10),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            _EditModeButtons(),
                            _GroupingIconButtons(),
                            _IconButtonSettings(),
                          ]),
                        )
                      ],
                    );
                  }
                )
              ]
            );
          }
        )
      )
    );
  }

  double _playOffsetValue;
  _PlayIndicator() {
    return AnimatedBuilder(
      animation: playOffset,
      builder: (ctx, w) {
        return Positioned(
          top: 3,
          bottom: 0,
          left: timelineContainsEnd ? null : (((playOffset.value - startOffset.value) / futureVisibleMicroseconds) * containerWidth) - (playHeadWidth / 2),
          right: !timelineContainsEnd ? null : (((lengthInMicroseconds - playOffset.value) / futureVisibleMicroseconds) * containerWidth) - (playHeadWidth / 2),
          child: Column(
            children: [
              GestureDetector(
                onPanStart: (details) {
                  _playOffsetValue = playOffset.value;
                },
                onPanUpdate: (details) {
                  var offsetValue = details.delta.dx * (visibleMicroseconds/(containerWidth + playHeadWidth));
                  _playOffsetValue += offsetValue;

                  playOffset.value = inflectionPoints.firstWhere((offset) {
                    return snapping && (1.0 - (_playOffsetValue / offset.inMicroseconds)).abs() < 0.05;
                  }, orElse: () => null)?.inMicroseconds?.toDouble() ?? _playOffsetValue;

                  audioPlayers.values.forEach((player) => player.pause());
                  setState((){});
                },
                onPanEnd: (details) {
                  updatePlayIndicatorAnimation();
                },
                child: ClipPath(
                  clipper: TriangleClipper(),
                  child: Container(
                    width: playHeadWidth,
                    color: Colors.white,
                    height: 10,
                  ),
                )
              ),
              Expanded(
                child: Container(
                  width: 2,
                  decoration: BoxDecoration(
                    color: Color(0xFFFFFFFF),
                  )
                )
              )
            ]
          )
        );
      }
    );
  }

  Widget _Timestamps() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text("${(startOffset.value/Duration(seconds: 1).inMicroseconds).toStringAsFixed(1)} sec"),
        _PlayHeadTimestamp(),
        Text("${((startOffset.value + visibleMicroseconds)/Duration(seconds: 1).inMicroseconds).toStringAsFixed(1)} sec"),
      ],
    );
  }

  Widget _TimelineContainer() {
    return Container(
      child: Stack(
        children: [
          _TimelineViewer(),
          _PlayIndicatorTrack(),
          _PlayIndicator(),
        ]
      )
    );
  }

  Widget _PlayIndicatorTrack() {
    return GestureDetector(
      onPanStart: (details) {
        audioPlayers.values.forEach((player) => player.pause());
        _playOffsetValue = startOffset.value + (visibleMicroseconds * details.localPosition.dx / containerWidth);
        playOffset.value = _playOffsetValue;
      },
      onPanUpdate: (details) {
        // Attempt to animate it:
        // var moveTo = startOffset.value + (visibleMicroseconds * details.localPosition.dx / containerWidth);
        // Tween<double>(begin: 0, end: moveTo).animate(playOffset);
        _playOffsetValue = startOffset.value + (visibleMicroseconds * details.localPosition.dx / containerWidth);

        playOffset.value = inflectionPoints.firstWhere((offset) {
          return snapping && (1.0 - (_playOffsetValue / offset.inMicroseconds)).abs() < 0.05;
        }, orElse: () => null)?.inMicroseconds?.toDouble() ?? _playOffsetValue;

        audioPlayers.values.forEach((player) => player.pause());
        setState((){});
      },
      onPanEnd: (details) {
        updatePlayIndicatorAnimation();
      },
      child: Container(
        height: 16,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment(-0.9, 0.9),
            stops: [0.0, 0.5, 0.5, 1],
            colors: [
              Color(0xff333333),
              Color(0xff333333),
              Color(0xff222222),
              Color(0xff222222),
            ],
            tileMode: TileMode.repeated,
          ),
        )
      )
    );
  }

  Widget _TimelineViewer() {
    return Container(
      margin: EdgeInsets.only(top: 16),
      child: GestureDetector(
        child: Column(
          children: [
            _ModeContainer(),
            _Waveforms(),
          ],
        ),
        behavior: HitTestBehavior.translucent,
        onScaleStart: (details) {
          timelineGestureStartPointX = details.localFocalPoint.dx;
        },
        onScaleEnd: (details) {
          scale = futureScale;
          setState(() {
            setStartOffset();
            setScrollBarWidth();
          });
          startOffset.animateWith(
             // The bigger the first parameter, the less friction is applied
            FrictionSimulation(0.2, startOffset.value,
              details.velocity.pixelsPerSecond.dx * -1 * microsecondsPerPixel// <- Velocity of inertia
            )
          );
        },

        onScaleUpdate: (details) {
          setState(() {
            var scrollSpeed = 2;
            var milisecondOffsetValue = (startOffset.value + (timelineGestureStartPointX - details.localFocalPoint.dx) * microsecondsPerPixel * scrollSpeed) ;
            if (timelineGestureStartPointX != details.localFocalPoint.dx || startOffset.value != milisecondOffsetValue) {
              timelineGestureStartPointX = details.localFocalPoint.dx;
              startOffset.value = milisecondOffsetValue.clamp(0.0, lengthInMicroseconds - visibleMicroseconds);
              setScrollBarWidth();
            }
          }); 


          if (details.horizontalScale != 1.0) {
            setState(() {
              // Scaling:
              futureScale = (scale * details.horizontalScale).clamp(1.0, maxScale);
              setScrollBarWidth();
            });
          }
        },
      )
    );
  }

  double get trackHeight => (containerHeight / 600) * (editMode == 'global' ? 160 : (editMode == 'groups' ? 80 : 40));

  Widget _ModeContainer() {
    return Column(
      children: modeTimelineControllers.map((controller) {
        controller.setWindow(
          futureVisibleDuration: futureVisibleDuration,
          visibleDuration: visibleDuration,
          timelineDuration: duration,
          windowStart: windowStart,
        );
        return Container(
          height: trackHeight,
          padding: EdgeInsets.symmetric(vertical: 1),
          decoration: BoxDecoration(
             color: Color(0xFF555555),
          ),
          child: SizedBox.expand(
            child: FractionallySizedBox(
              alignment: timelineContainsEnd && !timelineContainsStart ? FractionalOffset.centerRight : FractionalOffset.centerLeft,
              widthFactor: (futureScale / scale),//.clamp(0.0, 1.0),
              child: TimelineTrackWidget(
                controller: controller,
                onScrollUpdate: (windowStart) {
                  setState(() {
                    startOffset.value = windowStart.inMicroseconds.toDouble();
                  });
                },
                onReorder: () {
                  eachWithIndex(controller.elements, (index, element) => element.position = index + 1);
                  save();
                  reloadModes();
                },
                snapping: snapping,
                inflectionPoints: inflectionPoints,
                slideWhenStretching: slideModesWhenStretching,
                buildElement: (element, {start, end}) {
                  var invisibleLeft = maxDuration(Duration.zero, windowStart - element.startOffset);
                  var invisibleRight = maxDuration(Duration.zero, element.endOffset - windowEnd);
                  if (element.objectType == 'Mode')
                    return _ModeColumn(
                      mode: element.object,
                      invisibleLeftRatio: durationRatio(invisibleLeft, element.duration),
                      invisibleRightRatio: durationRatio(invisibleRight, element.duration),
                      timelineIndex: controller.timelineIndex,
                    );
                  else if (element.objectType == 'Show')
                    return ShowPreview(
                      show: element.object,
                      duration: minDuration(element.duration, windowEnd - element.startOffset),
                      contentOffset: maxDuration(Duration.zero, windowStart - element.startOffset) + (element.contentOffset ?? Duration.zero),
                    );
                  else if (element.object == null)
                    return Container(decoration: BoxDecoration(color: Colors.black));
                },
                onStretchUpdate: (side, value) {
                  _afterStretch(side, value);
                }
              ),
            )
          )
        );
      }).toList()
    );
  }

  void _stretchSelectedElements(stretchedValue, {overwrite, insertBlack, growFrom}) {
    timelineControllers.forEach((controller) {
      List<int> selectedIndexes = controller.selectedElementIndexes;
      if (selectedIndexes.isEmpty) return;
      // List<Mode> selectedModes = controller.selectedObjects.map<Mode>((object) {
      //   return object;
      // }).toList();
      Duration selectedDuration = controller.selectedDuration;
      Duration newDuration = selectedDuration * stretchedValue;
      var durationDifference = newDuration - selectedDuration;
      var index;

      if (insertBlack == 'right') {
        // I don't think this is a thing anymore:
        var blackElement = controller.selectedElements.last.dup();
        index = controller.elements.indexOf(selectedElements.last);

        blackElement.duration = durationDifference * -1;
        blackElement.object = null;
        show.elementTracks[controller.timelineIndex].insert(index + 1, blackElement);
      } else if (insertBlack == 'left') {
        // I don't think this is a thing anymore:
        var blackElement = controller.selectedElements.first.dup();
        index = controller.elements.indexOf(selectedElements.first);

        blackElement.duration = durationDifference * -1;
        blackElement.object.setAsBlack();
        show.elementTracks[controller.timelineIndex].insert(index - 1, blackElement);
      } else if (growFrom != null) {
        var sibling;
        if (growFrom == 'left')
          sibling = controller.elements[controller.elements.indexOf(controller.selectedElements.first) - 1];
        else sibling = controller.elements[controller.elements.indexOf(controller.selectedElements.last) + 1];


        var siblingDurationRatio = durationRatio(sibling.duration - durationDifference, sibling.duration);
        sibling.stretchBy(siblingDurationRatio);
      } else if (overwrite == 'left') {
        controller.elements.sublist(0, controller.selectedElementIndexes.first).reversed.forEach((element) {
          var newStart = controller.selectedElements.first.startOffset - durationDifference;
          if (element.startOffset >= newStart) {
            controller.elements.remove(element);
            show.elementTracks[controller.timelineIndex].remove(element);
          } else if (element.endOffset > newStart)
            element.duration -= element.endOffset - newStart;
        });
      } else if (overwrite == 'right') {
        controller.elements.sublist(controller.selectedElementIndexes.last + 1).forEach((element) {
          var newEnd = controller.selectedElements.last.endOffset + durationDifference;
          if (element.endOffset <= newEnd) {
            controller.elements.remove(element);
            show.elementTracks[controller.timelineIndex].remove(element);
          } else if (element.startOffset < newEnd) {
            element.duration -= newEnd - element.startOffset;
          }
        });
      }
      controller.selectedElements.forEach((element) {
        element.stretchBy(stretchedValue);
      });

      Duration offset = Duration();
      controller.elements.forEach((element) {
        element.startOffset = Duration() + offset;
        offset += element.duration;
      });

      controller.selectedElements.removeWhere((element) {
        return element.duration == Duration();
      });
      save();
      reloadModes();
    });
  }

  void _afterStretch(side, value) {
    // if (stretchedValue == 0) return _afterDelete();

    if (slideModesWhenStretching)
      _stretchSelectedElements(value);
    else if (value > 1)
      _stretchSelectedElements(value, overwrite: side);
    else if (value < 1)
      _stretchSelectedElements(value, growFrom: side); 

    setState(() { reloadModes(); });
  }

  Future<dynamic> _afterDelete() {
    return AppController.openDialog("How would you like to delete?", "",
      buttonText: 'Cancel',
      buttons: [{
        'text': 'Replace with empty space',
        'color': Colors.white,
        'onPressed': () {
          removeSelected(replaceWithBlack: true); 
        },
                            // This logic needs to be re-written for controllers
      }, oneElementSelected && selectedModes == [selectedElementControllers.first.elements.last] ? null : {
        'text': 'Expand from the right',
        'color': Colors.white,
        'onPressed': () {
          removeSelected(growFrom: 'right'); 
        },
                            // This logic needs to be re-written for controllers
      }, oneElementSelected && selectedModes == [selectedElementControllers.first.elements.first] ? null : {
        'text': 'Expand from the left',
        'color': Colors.white,
        'onPressed': () {
          removeSelected(growFrom: 'left'); 
        },
      }, {
        'text': 'Slide everything left',
        'color': Colors.red,
        'onPressed': () {
          removeSelected(); 
        },
      }]
    );
  }

  _replaceSelectedModesWithCycleOfModes() {
    Navigator.pushNamed(context, '/modes',
      arguments: {
        'isSelecting': true,
        'canChangeCurrentList': true,
        'selectAction': 'Generate Cycle',
      }
    ).then((modes) {
      if (modes != null)
        Navigator.pushNamed(context, '/subshows/new', arguments: {
          'duration': (selectedModeControllers.map((controller) => controller.selectedDuration).toList()..sort()).last,
          'modes': modes,
          'bpm': show.bpm
        }).then((s) {
          if (s == false) return;
          Show _show = s;
          _show = _show.dup();
          _show.setEditMode('props');
          selectedModeControllers.forEach((controller) {
            var track = show.modeTracks[controller.timelineIndex];
            var index = controller.selectedElementIndexes.first;
            track.insert(index, TimelineElement(
              duration: controller.selectedDuration,
              object: _show,
            ));
            controller.selectedElements.forEach((element) => track.remove(element));
          });
          show.modes.addAll(_show.modes);
          show.ensureStartOffsets();
          reloadModes();
          save();
        });
    });
  }

  Future<dynamic> _replaceSelectedModesWithMode() {
    var replacement;
    if (selectedElements.first.objectType == 'Mode')
      replacement = selectedElements.first.object.dup();
    else replacement = show.createNewMode();
    if (selectedElementTimelineIndexes.toSet().length == 1) {
      var index = selectedElementTimelineIndexes.first;
      if (editMode == 'groups')
        replacement.setAsSubMode(groupIndex: index);
      else if (editMode == 'props')
        replacement.setAsSubMode(
          groupIndex: show.groupIndexFromGlobalPropIndex(index),
          propIndex: show.localPropIndexFromGlobalPropIndex(index),
        );
    }
    return Navigator.pushNamed(context, "/modes/${replacement.id}",
      arguments: {
        'mode': replacement,
        'autoUpdate': false,
        'saveMessage': oneElementSelected ? "SAVE" : "REPLACE (${selectedElements.length})"
      }
    ).then((saved) {
      if (saved == true) {
        if (replacement.groupIndex != null) {
          var partialReplacement = replacement;
          replacement = selectedElements.first.object.dup();
          replacement.modeParams.keys.forEach((paramName) {
            replacement.setParam(paramName, partialReplacement.modeParams[paramName],
              groupIndex: partialReplacement.groupIndex,
              propIndex: partialReplacement.propIndex,
            );
          });
          replacement.recursivelySetMultiValue();
        }
        selectedElements.forEach((element) => element.object = replacement);
        return replacement.save().then((response) {
          if (!response['success'])
            print("WARNING:     Object failed to save!!!!!!");
          else if (response['id'] == null)
            print("WARNING:     Object was successfully saved, but no ID was returned in the response. Please add an ID so timeline elements can be created");
        }).then((_) {
          show.modes.add(replacement);
          return save();
        });
      }
    });
  }


  Widget _Waveforms() {


    waveformTimelineController?.setWindow(
      futureVisibleDuration: futureVisibleDuration,
      visibleDuration: visibleDuration,
      timelineDuration: duration,
      windowStart: windowStart,
    );

    return Container(
      height: min(70 * containerHeight / 600, trackHeight),
      child: waveformTimelineController == null ? SpinKitCircle(color: Colors.blue) : SizedBox.expand(
        child: FractionallySizedBox(
          alignment: timelineContainsEnd && !timelineContainsStart ? FractionalOffset.centerRight : FractionalOffset.centerLeft,
          widthFactor: (futureScale / scale),//.clamp(0.0, 1.0),
          child: TimelineTrackWidget(
            controller: waveformTimelineController,
            onScrollUpdate: (windowStart) {
              setState(() {
                startOffset.value = windowStart.inMicroseconds.toDouble();
              });
            },
            onReorder: () {
              eachWithIndex(waveformTimelineController.elements, (index, element) => element.position = index + 1);
              save();
            },
            slideWhenStretching: slideModesWhenStretching,
            buildElement: (element) {
              Duration waveVisibleDuration = visibleDurationOf(element);
              var contentOffset = element.contentOffset ?? Duration.zero;
              if (element.object == null)
                return Container(decoration: BoxDecoration(color: Colors.black));
              else return Waveform(
                song: element.object,
                controller: waveforms[element],
                visibleDuration: waveVisibleDuration,
                scale: scale * (element.duration.inMicroseconds / lengthInMicroseconds),
                futureScale: futureScale * (element.duration.inMicroseconds / lengthInMicroseconds),
                startOffset: maxDuration(windowStart - element.startOffset, Duration()) + contentOffset,
                visibleBands: 1200 * (waveVisibleDuration.inMicroseconds / visibleMicroseconds).clamp(0.0, 1.0),
                color: [Colors.red, Colors.red][waveforms.keys.toList().indexOf(element) % 2],
              );
            },
            onStretchUpdate: (side, value) {
              // _afterStretch(side, value);
            }
          )
        )
      )
    );
  }

  Widget _ScrollBarPlayIndicator() {
    if (futureScale == 1) return Container();
    return AnimatedBuilder(
      animation: playOffset,
      builder: (ctx, w) {
        return Positioned(
          top: 0,
          bottom: 0,
          left: ((scrollContainerWidth) * playOffset.value / lengthInMicroseconds),
          child: Column(
            children: [
              ClipPath(
                clipper: TriangleClipper(),
                child: Container(
                  width: 10,
                  color: Colors.white,
                  height: 5,
                ),
              ),
              Expanded(
                child: Container(
                  width: 1,
                  decoration: BoxDecoration(
                    color: Color(0x88FFFFFF),
                  )
                )
              )
            ]
          )
        );
      }
    );
  }

  Widget _ScrollBar() {
    var horizontalPadding = (containerWidth - scrollContainerWidth)/2;
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          var microsecondsNotVisible = lengthInMicroseconds - visibleMicroseconds;

          var offsetValue =  details.delta.dx * microsecondsNotVisible;
          startOffset.value = startOffset.value + (offsetValue/(scrollContainerWidth - scrollbarWidth));
          startOffset.value = startOffset.value.clamp(0.0, microsecondsNotVisible).toDouble();
          setScrollBarWidth();
        });
      },
      child: Stack(
        children: [
          Container(
            height: 20,
            width: containerWidth,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Color(0xFF555555),
            )
          ),
          Positioned(
            top: 2,
            left: (horizontalPadding + scrollContainerWidth * startOffset.value / lengthInMicroseconds).clamp(horizontalPadding, max(horizontalPadding, containerWidth - scrollbarWidth - horizontalPadding)),
            child: Container(
              width: scrollbarWidth,
              height: 16,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Color(0xFF333333),
              )
            )
          ),
          _ScrollBarPlayIndicator(),
        ]
      )
    );
  }

  Widget _IconButtonSettings() {
    return Container(
      child: Row(
        children: [
          _ToggleButton(
            message: "Snappinig",
            active: snapping,
            onTap: () {
              snapping = !snapping;
              _showNoticeMessage("Snapping ${snapping ? 'Enabled' : 'Disabled'}");
            },
            padding: EdgeInsets.all(5),
            child: Image(
              image: AssetImage('assets/images/magnet.png'),
            )
          ),
          _ToggleButton(
            message: "Multi-Select",
            active: selectMultiple,
            onTap: () {
              selectMultiple = !selectMultiple;
              _showNoticeMessage("Multi-Select ${selectMultiple ? 'Enabled' : 'Disabled'}");
              timelineControllers.forEach((controller) {
                controller.selectMultiple = selectMultiple;
                if (controller.selectedElements.isNotEmpty)
                  controller.selectedElements = [controller.selectedElements.last];
              });
            },
            padding: EdgeInsets.all(3),
            child: Image(
              image: AssetImage('assets/images/multiselect.png'),
            )
          ),
          _ToggleButton(
            message: "Push Mode",
            active: slideModesWhenStretching,
            onTap: () {
              slideModesWhenStretching = !slideModesWhenStretching;
              _showNoticeMessage("Push-Mode ${slideModesWhenStretching ? 'Enabled' : 'Disabled'}");
            },
            padding: EdgeInsets.all(3),
            child: Image(
              image: AssetImage('assets/images/push-mode.png'),
            )
          ),
        ]
      )
    );
  }

  bool get _canSplitAtPlayhead => currentElements.any((element) => selectedElements.contains(element));
  bool get _canDelete => selectedElements.length > 0;
  bool get _canEdit => selectedElements.length > 0;

  Widget _EditModeButtons() {
    return Container(
      child: Row(
        children: [
          _ToggleButton(
            message: "Edit or Replace Element",
            active: _canEdit,
            onTap: () {
              if (!_canEdit) return Future.value(false);
              return _editSelectedModes();
            },
            padding: EdgeInsets.all(3),
            child: Image(
              image: AssetImage('assets/images/edit-params.png'),
            )
          ),
          _ToggleButton(
            message: "Split at Playhead",
            active: _canSplitAtPlayhead,
            onTap: () {
              if (!_canSplitAtPlayhead) return;
              _splitAtPlayhead();
              _showNoticeMessage("Split Elements at Playhead");
            },
            padding: EdgeInsets.all(5),
            child: Image(
              image: AssetImage('assets/images/cut.png'),
            )
          ),
          _ToggleButton(
            message: "Delete (${selectedElements.length})",
            active: _canDelete,
            onTap: () {
              if (!_canDelete) return;
              var elementCount = selectedElements.length;
              _afterDelete().then((_deleted) {
                if (_deleted == true)
                  elementCount == 1 ? _showNoticeMessage("1 Element Deleted") :
                    _showNoticeMessage("${elementCount} Elements Deleted");
              });
            },
            padding: EdgeInsets.all(3),
            child: Image(
              image: AssetImage('assets/images/delete.png'),
            )
          ),
        ]
      )
    );
  }

  Widget _GroupingIconButtons() {
    return Container(
      child: Row(
        children: [
          _ToggleButton(
            message: "Global Edit Mode",
            active: editMode == 'global',
            onTap: () {
              show.setEditMode('global');
              reloadModes();
              _showNoticeMessage("Editing Global");
            },
            padding: EdgeInsets.all(5),
            child: Image(
              image: AssetImage('assets/images/global-timeline.png'),
            )
          ),
          _ToggleButton(
            message: "Group Edit Mode",
            active: editMode == 'groups',
            onTap: () {
              show.setEditMode('groups');
              reloadModes();
              _showNoticeMessage("Editing Groups");
            },
            padding: EdgeInsets.all(3),
            child: Image(
              image: AssetImage('assets/images/group-timeline.png'),
            )
          ),
          _ToggleButton(
            message: "Prop Edit Mode",
            active: editMode == 'props',
            onTap: () {
              show.setEditMode('props');
              reloadModes();
              _showNoticeMessage("Editing Props");
            },
            padding: EdgeInsets.all(3),
            child: Image(
              image: AssetImage('assets/images/prop-timeline.png'),
            )
          ),
        ]
      )
    );
  }

  Widget _ToggleButton({active, child, padding, onTap, message}) {
    return Tooltip(
      message: message,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 35,
          width: containerWidth / 11,
          padding: padding,
          decoration: BoxDecoration(
            border: Border.all(color: active ? Color(0xff555555) : Color(0xff444444), width: 1),
            boxShadow: [
              const BoxShadow(
                color: Color(0xFF000000),
              ),
              const BoxShadow(
                color: Color(0xFF000000),
                spreadRadius: -10.0,
                blurRadius: 10.0,
              ),
            ],
            color: active ? Color(0xff22303c) : Color(0xff333333)
          ),
          child: Opacity(
            opacity: active ? 1.0 : 0.6,
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(active ? Colors.blue : Colors.grey, BlendMode.srcATop),
              child: child,
            )
          )
        )
      )
    );
  }

  Widget _ScaleSlider() {
    return Container(
      height: 35,
      width: containerWidth / 2.8,
      decoration: BoxDecoration(
        color: Colors.grey
      ),
      child: Row(
        children: [
          Icon(Icons.zoom_in, color: Colors.black),
          Expanded(
            child: SliderPicker(
              height: 20,
              max: 1.0,
              value: (1/pow(futureScale, 1/3)).clamp(1/maxScale, 1.0),
              min: 1/pow(maxScale, 1/3),
              onChanged: (value){
                setState(() {
                  futureScale = 1/pow(value, 3);
                  setScrollBarWidth();
                });
                computeDataTimer?.cancel();
                computeDataTimer = Timer(Duration(microseconds: 250), () {
                  setState(() {
                    scale = futureScale;
                    setStartOffset();
                    setScrollBarWidth();
                  });
                });
              },
              colors: [Colors.black, Colors.black],
            )
          ),
          Icon(Icons.zoom_out, color: Colors.black),
        ]
      )
    );
  }

  Widget _Controls() {
    return Expanded(
      child: Wrap(
        // mainAxisAlignment: MainAxisAlignment.spaceAround,
        // crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.symmetric(horizontal: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _UndoAndRedo(),
                _NoticeMesssage(),
                _SavedToCloudIndicator(),
              ]
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 20),
              _SelectAll(),
              Container(width: 10),
              _DeselectAll(),
            ]
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _EditModeControls(),
            ]
          ),
          // GestureDetector(
          //   onTap: () {
          //     setState(() => showModeImages = !showModeImages);
          //   },
          //   child: Container(
          //     padding: EdgeInsets.all(2),
          //     child: Row(
          //        mainAxisAlignment: MainAxisAlignment.center,
          //        children: [
          //          Text("Show Mode Images "),
          //          Icon(showModeImages ? Icons.check_circle : Icons.circle, size: 16),
          //        ]
          //      )
          //    )
          // ),
        ]
      )
    );
  }

  void _showNoticeMessage(message) {
    setState(() {
      _noticeMessage = message;
      _noticeMessageVisible = true;
    });
    _noticeMessageTimer?.cancel();
    _noticeMessageTimer = Timer(Duration(milliseconds: 1500), () {
      setState(() {
        _noticeMessageVisible = false;
      });
    });
  }

  String _noticeMessage;
  Timer _noticeMessageTimer;
  bool _noticeMessageVisible = false; 
  Widget _NoticeMesssage() {
    return AnimatedOpacity(
      duration: Duration(milliseconds: _noticeMessageVisible ? 0 : 500),
      opacity: _noticeMessageVisible ? 1.0 : 0.0,
      child: Text(_noticeMessage ?? "", style: TextStyle( color: Colors.green ))
    );
  }

  Widget _PlayHeadTimestamp() {
    return Container(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              playOffset.value = 0.0;
              currentPlayer.pause();
              updatePlayIndicatorAnimation();
            },
            child: Icon(Icons.skip_previous, size: 24),
          ),
          Container(
            margin: EdgeInsets.all(5),
            child: GestureDetector(
              onTap: () {
                setState(() => isPlaying = !isPlaying);
                updatePlayIndicatorAnimation();
              },
              child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, size: 24)
            )
          ),

          AnimatedBuilder(
            animation: playOffset,
            builder: (ctx, w) {
              var timestamp = twoDigitString(playOffsetDuration, includeMilliseconds: true);
              var leadingZeros = timestamp.replaceAll(RegExp(r'[1-9].*$'), '');
              timestamp = timestamp.replaceAll(RegExp(r'^[0:]+'), '');

              return Row(
                children: [
                  Text(leadingZeros,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 30,
                    )
                  ),
                  Text(timestamp,
                    style: TextStyle(
                      fontSize: 30,
                    )
                  ),
                ]
              );
            }
          )
        ]
      )
    );
  }
  Widget _MultiSelectButtons() {
    return Container(
      padding: EdgeInsets.all(2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(child: Text("Multi-Select"), margin: EdgeInsets.only(bottom: 6)),
          // Icon(slideModesWhenStretching ? Icons.check_circle : Icons.circle, size: 16),
          Container(
            decoration: BoxDecoration(color: Color(0x22FFFFFF)),
            child: ToggleButtons(
              isSelected: [!selectMultiple, selectMultiple],
              onPressed: (int index) {
                selectMultiple = (index == 1);

                timelineControllers.forEach((controller) {
                  controller.selectMultiple = selectMultiple;
                  if (controller.selectedElements.isNotEmpty)
                    controller.selectedElements = [controller.selectedElements.last];
                });

                setState(() {});
              },
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text("Off"),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text("On"),
                ),
              ]
            )
          ),
        ]
      )
    );
  }

  Widget _SnapingButtons() {
    return Container(
      padding: EdgeInsets.all(2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(child: Text("Snapping"), margin: EdgeInsets.only(bottom: 6)),
          Container(
            decoration: BoxDecoration(color: Color(0x22FFFFFF)),
            child: ToggleButtons(
              isSelected: [!snapping, snapping],
              onPressed: (int index) {
                snapping = (index == 1);
                setState(() {});
              },
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text("Off"),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text("On"),
                ),
              ]
            )
          ),
        ]
      )
    );
  }

  Widget _PushModeButtons() {
    return Container(
      padding: EdgeInsets.all(2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(child: Text("Push Mode"), margin: EdgeInsets.only(bottom: 6)),
          Container(
            decoration: BoxDecoration(color: Color(0x22FFFFFF)),
            child: ToggleButtons(
              isSelected: [!slideModesWhenStretching, slideModesWhenStretching],
              onPressed: (int index) {
                slideModesWhenStretching = (index == 1);
                setState(() {});
              },
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text("Off"),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text("On"),
                ),
              ]
            )
          ),
        ]
      )
    );
  }

  Widget _SavedToCloudIndicator() {
    return Container(
      width: 25,
      margin: EdgeInsets.only(right: 10),
      child: show.audioDownloadedPending ? SpinKitCircle(color: Colors.white, size: 20) :
        (show.savedToCloud ? 
          Icon(Icons.cloud_done, color: AppController.lightGrey) : Icon(Icons.cloud_off, color: AppController.darkGrey)
        ),
    );
  }

  Widget _UndoAndRedo() {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              show.undo();
            });
          },
          child: Container(
            padding: EdgeInsets.all(2),
            child: Icon(Icons.undo, color: show.canUndo ? AppController.lightGrey : AppController.darkGrey),
          )
        ),
        GestureDetector(
          onTap: () {
            setState(() {
              show.redo();
            });
          },
          child: Container(
            padding: EdgeInsets.all(2),
            child: Icon(Icons.redo, color: show.canRedo ? AppController.lightGrey : AppController.darkGrey),
          )
        ),
      ]
    );
  }

  Widget _SelectAll() {
    return Visibility(
      visible: timelineControllers.any((controller) => !controller.allElementsSelected),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RaisedButton(
            onPressed: () {
              setState(() {
                selectMultiple = true;
                timelineControllers.forEach((controller) => controller.selectAll());
              });
            },
            child: Container(
              padding: EdgeInsets.all(2),
              child: Text("Select All"),
            )
          ),
          GestureDetector(
            onTap: () {
              AppController.openDialog("Select All", "",
                buttons: [{
                  'text': 'After Playhead',
                  'color': Colors.white,
                  'onPressed': () {
                    timelineControllers.forEach((controller) {
                      controller.selectAll(after: playOffsetDuration);
                    });
                  },
                }, {
                  'text': 'Before Playhead',
                  'color': Colors.white,
                  'onPressed': () {
                    timelineControllers.forEach((controller) {
                      controller.selectAll(before: playOffsetDuration);
                    });
                  },
                }]
              );
            },
            child: ClipRRect(
               borderRadius: BorderRadius.circular(1.0),
               child: Container(
                 height: 36,
                 padding: EdgeInsets.all(2),
                 child: Icon(Icons.arrow_drop_down),
                 decoration: BoxDecoration(
                   color: Colors.blue,
                 )
               )
             )
           )
        ]
      )
    );
  }

  Widget _DeselectAll() {
    return Visibility(
      visible: selectedElements.isNotEmpty,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RaisedButton(
            onPressed: () {
              setState(() {
                timelineControllers.forEach((controller) => controller.deselectAll());
              });
            },
            child: Container(
              padding: EdgeInsets.all(2),
              child: Text("Deselect All"),
            )
          ),
          GestureDetector(
            onTap: () {
              AppController.openDialog("Deselect All", "",
                buttons: [{
                  'text': 'After Playhead',
                  'color': Colors.white,
                  'onPressed': () {
                    timelineControllers.forEach((controller) {
                      controller.deselectAll(after: playOffsetDuration);
                    });
                  },
                }, {
                  'text': 'Before Playhead',
                  'color': Colors.white,
                  'onPressed': () {
                    timelineControllers.forEach((controller) {
                      controller.deselectAll(before: playOffsetDuration);
                    });
                  },
                }]
              );
            },
            child: ClipRRect(
               borderRadius: BorderRadius.circular(1.0),
               child: Container(
                 height: 36,
                 padding: EdgeInsets.all(2),
                 child: Icon(Icons.arrow_drop_down),
                 decoration: BoxDecoration(
                   color: Colors.blue,
                 )
               )
             )
           )
        ]
      )
    );
  }

  Future<dynamic> _editSelectedModes() {
    if (selectedElementControllers.any((controller) => !controller.selectedElementsAreConsecutive))
      return _replaceSelectedModesWithMode();
    else
      return AppController.openDialog("How would you like to ${oneElementSelected ? "edit (1)" : "replace (${selectedElements.length})"}?", "",
        buttonText: 'Cancel',
        buttons: [{
          'text': oneModeSelected ? 'Edit Mode Details' : 'Replace with mode',
          'color': Colors.white,
          'onPressed': () {
            _replaceSelectedModesWithMode();
          },
        }, {
          'text': 'Replace with cycle of modes',
          'color': Colors.white,
          'onPressed': () {
            _replaceSelectedModesWithCycleOfModes();
          },
        }]
      );
  }

  Widget _EditButton() {
    return Visibility(
      visible: modeTimelineControllers.any((controller) => controller.selectedElements.isNotEmpty),
      child: Container(
        margin: EdgeInsets.all(5),
        child: RaisedButton(
          onPressed: () {
            _editSelectedModes();
          },
          child: Container(
            padding: EdgeInsets.all(2),
            child: Text(oneElementSelected ? "Edit (1)" : "Replace (${selectedElements.length})")
          )
        )
      )
    );
  }

  Widget _DeleteButton() {
    return Visibility(
      visible: selectedElements.isNotEmpty,
      child: Container(
        margin: EdgeInsets.all(5),
        child: RaisedButton(
          onPressed: () {
            _afterDelete();
          },
          child: Container(
            padding: EdgeInsets.all(2),
              child: Text("Delete (${selectedElements.length})"),
           )
        ),
      ),
    );
  }

  void _splitAtPlayhead() {
    var controllers = [];
    selectedElementControllers.forEach((controller) {
      var current = controller.elementAtTime(playOffsetDuration);
      if (current == null) return;
      if (current.startOffset == playOffsetDuration) return;
      if (!selectedElements.contains(current)) return;
      controllers.add(controller);
      var index = controller.elements.indexOf(current);
      var newElement = current.dup();

      newElement.startOffset = playOffsetDuration;
      newElement.duration = current.duration - (playOffsetDuration - current.startOffset);
      current.duration -= newElement.duration;
      newElement.contentOffset = current.duration;
      show.elementTracks[controller.timelineIndex].insert(index+1, newElement);
      
      save();
    });

    modeTimelineControllers.forEach((controller) {
      controller.deselectAll();
    });
    reloadModes();
    controllers.forEach((controller) {
      controller.toggleSelected(controller.elementAtTime(playOffsetDuration));
    });
  }

  Widget _SplitAtPlayHead() {
    if (currentElements.every((element) => !selectedElements.contains(element)))
      return Container();

    return Container(
      margin: EdgeInsets.all(5),
      child: RaisedButton(
        onPressed: () {
          _splitAtPlayhead();
        },
        child: Container(
          padding: EdgeInsets.all(2),
           child: Text("Split at playhead"),
         )
      ),
    );
  }

  Widget _EditModeControls() {
    return Container(
      padding: EdgeInsets.all(2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
        ]
      )
    );
  }

  Widget _ModeColumn({Mode mode, int timelineIndex, double invisibleLeftRatio, double invisibleRightRatio}) {
    var groupIndex; var propIndex;
    if (editMode == 'groups')
      groupIndex = timelineIndex;
    else if (editMode == 'props') {
      groupIndex = show.groupIndexFromGlobalPropIndex(timelineIndex);
      propIndex = show.localPropIndexFromGlobalPropIndex(timelineIndex);
    }
    return ModeColumnForShow(
      invisibleRightRatio: invisibleRightRatio,
      invisibleLeftRatio: invisibleLeftRatio,
      groupIndex: groupIndex,
      propIndex: propIndex,
      mode: mode,
    );
  }

  String _getTitle() {
    return 'Timeline';
  }

}

