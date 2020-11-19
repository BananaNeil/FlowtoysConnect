import 'package:flutter_hsvcolor_picker/flutter_hsvcolor_picker.dart';
import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:quiver/iterables.dart' hide max, min;
import 'package:app/components/timeline_track.dart';
import 'package:app/models/timeline_element.dart';
import 'package:app/helpers/duration_helper.dart';
import 'package:app/components/mode_widget.dart';
import 'package:app/components/waveform.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
  Timer computeDataTimer;

  Map<TimelineElement, AssetsAudioPlayer> audioPlayers = {};
  List<TimelineTrackController> modeTimelineControllers = [];
  TimelineTrackController waveformTimelineController = TimelineTrackController(elements: <TimelineElement>[]);

  List<TimelineTrackController> get timelineControllers => [
    waveformTimelineController,
    ...modeTimelineControllers,
  ].where((controller) => controller != null).toList();


  bool showModeImages = true; 
  bool selectMultiple = false;
  List<Mode> selectedModes = [];
  bool slideModesWhenStretching = false;
  bool get oneModeSelected => selectedElements.length == 1;
  List<TimelineElement> get selectedElements => timelineControllers.map((controller) {
    return controller.selectedElements;
  }).expand((e) => e).toList();


  double scale = 1;
  double futureScale = 1;
  double get maxScale => max(1, duration.inSeconds / 5);

  bool isPlaying = false;

  Duration duration = Duration(milliseconds: 1);
  int get lengthInMiliseconds => duration.inMilliseconds;
  Duration get visibleDuration => duration * (1 / scale);
  Duration get futureVisibleDuration => duration * (1 / futureScale);
  double get visibleMiliseconds => (lengthInMiliseconds / scale);
  double get remainingMiliseconds => lengthInMiliseconds - playOffset.value;
  double get futureVisibleMiliseconds => (lengthInMiliseconds / futureScale);


  AnimationController startOffset;
  AnimationController playOffset;

  Duration get playOffsetDuration => Duration(milliseconds: playOffset.value.toInt());


  double scrollbarWidth = 0;
  double containerWidth = 0;
  double playHeadWidth = 20.0;
  double get scrollContainerWidth => containerWidth * 0.97;
  bool get timelineContainsStart => startOffset.value <= 0;
  bool get timelineContainsEnd => startOffset.value + futureVisibleMiliseconds >= lengthInMiliseconds;
  double get milisecondsPerPixel => visibleMiliseconds / containerWidth;

  bool modesLoaded = false;
  bool loading = true;


  double timelineGestureStartPointX;


  Map<TimelineElement, WaveformController> waveforms = {};

  Duration get windowStart => Duration(milliseconds: startOffset.value.toInt());
  Duration get windowEnd => windowStart + Duration(milliseconds: visibleMiliseconds.toInt());

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

    super.initState();
  }


  TimelineElement get currentAudioElement {
    return waveformTimelineController.elementAtTime(playOffsetDuration);
  }

  AssetsAudioPlayer get currentPlayer {
    return audioPlayers[currentAudioElement];
  }

  void reloadModes() {
    setState(() {
      loadModes(force: true);
    });
  }

  void loadModes({force}) {
    if (modesLoaded && force != true) return;
    modesLoaded = true;
    Duration offset = Duration();
    show.modeElements.forEach((element) {
      element.startOffset = Duration() + offset;
      offset += element.duration;
    });



    if (!loading)
      scale *= show.duration.inMilliseconds / duration.inMilliseconds;
    duration = show.duration;
    scale = max(1, scale);
    futureScale = scale;
    setScrollBarWidth();
    setAnimationControllers();

    // timelineControllers = timelineControllers.isNotEmpty ? timelineControllers : [
    modeTimelineControllers =  [
      TimelineTrackController(
        onSelectionUpdate: (() => setState(() {})),
        selectMultiple: selectMultiple,
        elements: show.modeElements,
      )
    ];

  }

  void loadPlayers() {
    var waveformLengthWas = waveforms.keys.length;
    List.from(waveforms.keys).forEach((element) {
      if (!show.songElements.contains(element))
        waveforms.remove(element);
    });

    if (waveformLengthWas == waveforms.keys.length)
      if (waveforms.keys.length == show.songElements.length)
        return;

    waveformTimelineController.elements = show.songElements;
    var offset = Duration();
    show.songElements.forEach((element) {
      element.startOffset = Duration() + offset;
      offset += element.duration;
    });

    loadAudioPlayers().then((_) {
      var lengthInMiliseconds = 0.1;
      var index = 0;
      mapWithIndex(show.songElements, (index, element) {
        waveforms[element].startOffset = element.startOffset;
      });
      waveformTimelineController = TimelineTrackController(
        onSelectionUpdate: (() => setState(() {})),
        selectMultiple: selectMultiple,
        elements: show.songElements,
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
        show.songElements.forEach((element) => waveforms[element] = WaveformController.open(element.object?.localPath));
        loading = false;
      });

      audioPlayers = {};
      AssetsAudioPlayer player;
      return Future.wait(show.songElements.map((element) {
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
      upperBound: lengthInMiliseconds - visibleMiliseconds,
      value: currentOffsetValue,
      lowerBound: 0,
      vsync: this
    );
  }

  void setPlayOffset() {
    var value = playOffset?.value ?? 0;
    playOffset = AnimationController(
      upperBound: lengthInMiliseconds.toDouble(),
      lowerBound: 0,
      vsync: this
    );
    playOffset.value = value;
  }

  void prepareTimeline() {
    setScrollBarWidth();
  }

  void setScrollBarWidth() {
    if (scrollContainerWidth > 0)
      scrollbarWidth = (scrollContainerWidth / futureScale).clamp(10.0, scrollContainerWidth).toDouble();
  }

  void updatePlayIndicatorAnimation() {
    if (isPlaying) {
      currentPlayer.play();
      playOffset.animateTo(lengthInMiliseconds.toDouble(),
        duration: Duration(milliseconds: remainingMiliseconds.toInt()),
      );
    } else {
      audioPlayers.values.forEach((player) => player.pause());
      playOffset.stop();
    }
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

        setState(() {
          if (replaceWithBlack == true) {
            replacedIndexes.add(index);
            element.object = null;
            element.save();
          } else {
            sibling?.duration += element.duration;
            print("Removing ${element}");
            controller.elements.remove(element);
            show.timelineElements.remove(element);
            Client.removeTimelineElement(element);

            // Maybe do something here to make sure this succeeds?
            sibling?.save();
          }
        });
      });
      controller.selectedElements = [];
    });
    reloadModes();
  }

  @override
  Widget build(BuildContext context) {
    show = (ModalRoute.of(context).settings.arguments as Map)['show']; 
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
            containerWidth = box.maxWidth;

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
                        _ScaleSlider(),
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

  _PlayIndicator() {
    return AnimatedBuilder(
      animation: playOffset,
      builder: (ctx, w) {
        return Positioned(
          top: 3,
          bottom: 0,
          left: timelineContainsEnd ? null : (((playOffset.value - startOffset.value) / futureVisibleMiliseconds) * containerWidth) - (playHeadWidth / 2),
          right: !timelineContainsEnd ? null : (((lengthInMiliseconds - playOffset.value) / futureVisibleMiliseconds) * containerWidth) - (playHeadWidth / 2),
          child: Column(
            children: [
              GestureDetector(
                onPanUpdate: (details) {
                  var offsetValue = details.delta.dx * (visibleMiliseconds/(containerWidth + playHeadWidth));
                  playOffset.value += offsetValue;

                  audioPlayers.values.forEach((player) => player.pause());
                  if (currentAudioElement.object != null)
                    currentPlayer.seek(Duration(milliseconds: playOffset.value.toInt()) - currentAudioElement.startOffset);
                  // audioPlayer.currentPosition.value = Duration(milliseconds: playOffset.value.toInt());
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
      children: [
        Text("${(startOffset.value/1000).toStringAsFixed(1)} sec"),
        Text("${((startOffset.value + visibleMiliseconds)/1000).toStringAsFixed(1)} sec"),
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
        playOffset.value = startOffset.value + (visibleMiliseconds * details.localPosition.dx / containerWidth);
        audioPlayers.values.forEach((player) => player.pause());
        if (currentAudioElement.object != null)
          currentPlayer.seek(Duration(milliseconds: playOffset.value.toInt()) - currentAudioElement.startOffset);
      },
      onPanUpdate: (details) {
        playOffset.value = startOffset.value + (visibleMiliseconds * details.localPosition.dx / containerWidth);
        audioPlayers.values.forEach((player) => player.pause());
        if (currentAudioElement.object != null)
          currentPlayer.seek(Duration(milliseconds: playOffset.value.toInt()) - currentAudioElement.startOffset);
        // audioPlayer.currentPosition.value = Duration(milliseconds: playOffset.value.toInt());
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
            prepareTimeline();
          });
          startOffset.animateWith(
             // The bigger the first parameter, the less friction is applied
            FrictionSimulation(0.2, startOffset.value,
              details.velocity.pixelsPerSecond.dx * -1 * milisecondsPerPixel// <- Velocity of inertia
            )
          );
        },

        onScaleUpdate: (details) {
          setState(() {
            var scrollSpeed = 2;
            var milisecondOffsetValue = (startOffset.value + (timelineGestureStartPointX - details.localFocalPoint.dx) * milisecondsPerPixel * scrollSpeed) ;
            if (timelineGestureStartPointX != details.localFocalPoint.dx || startOffset.value != milisecondOffsetValue) {
              timelineGestureStartPointX = details.localFocalPoint.dx;
              startOffset.value = milisecondOffsetValue.clamp(0.0, lengthInMiliseconds - visibleMiliseconds);
              prepareTimeline();
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
          height: 150,
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
                    startOffset.value = windowStart.inMilliseconds.toDouble();
                  });
                },
                onReorder: () {
                  eachWithIndex(controller.elements, (index, element) => element.position = index + 1);
                  controller.selectedElements.forEach((element) => element.save());
                  reloadModes();
                },
                slideWhenStretching: slideModesWhenStretching,
                buildElement: (element) {
                  return _ModeColumn(mode: element.object);
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

  void _stretchSelectedModes(stretchedValue, {overwrite, insertBlack, growFrom}) {
    timelineControllers.forEach((controller) {
      List<int> selectedIndexes = controller.selectedElementIndexes;
      Duration selectedDuration = controller.selectedDuration;
      Duration newDuration = selectedDuration * stretchedValue;
      var durationDifference = newDuration - selectedDuration;
      if (insertBlack == 'right') {
        var blackMode = controller.selectedElements.last.dup();
        blackMode.duration = durationDifference * -1;
        blackMode.object.setAsBlack();
        blackMode.position += 1;
        blackMode.save();
        show.timelineElements.add(blackMode);
      } else if (insertBlack == 'left') {
        var blackMode = controller.selectedElements.first.dup();
        blackMode.duration = durationDifference * -1;
        blackMode.object.setAsBlack();
        blackMode.position -= 1;
        blackMode.save();
        show.timelineElements.add(blackMode);
      } else if (growFrom != null) {
        var sibling;
        if (growFrom == 'left')
          sibling = controller.elements[controller.elements.indexOf(controller.selectedElements.first) - 1];
        else sibling = controller.elements[controller.elements.indexOf(controller.selectedElements.last) + 1];

        // There is some sort of bug here where the first visible mode won't show a resize and another bug where it's dropping to zero if stretch < 1

        sibling.duration -= durationDifference;
        sibling.save();
      } else if (overwrite == 'left') {
        controller.elements.sublist(0, controller.selectedElementIndexes.first).reversed.forEach((element) {
          var newStart = controller.selectedElements.first.startOffset - durationDifference;
          if (element.startOffset >= newStart) {
            Client.removeMode(element.object);
            Client.removeTimelineElement(element);
            show.timelineElements.remove(element);
          } else if (element.endOffset > newStart)
            element.duration -= element.endOffset - newStart;
            element.save();
        });
      } else if (overwrite == 'right') {
        controller.elements.sublist(controller.selectedElementIndexes.last + 1).forEach((element) {
          var newEnd = controller.selectedElements.last.endOffset + durationDifference;
          if (element.endOffset <= newEnd) {
            Client.removeMode(element.object);
            Client.removeTimelineElement(element);
            show.timelineElements.remove(element);
          } else if (element.startOffset < newEnd) {
            element.duration -= newEnd - element.startOffset;
            element.save();
          }
        });
      }
      controller.selectedElements.forEach((element) {
        element.duration *= stretchedValue;
        if (element.duration == Duration()) {
          Client.removeMode(element.object);
          Client.removeTimelineElement(element);
          show.timelineElements.remove(element);
        } else element.save();
      });
      controller.selectedElements.removeWhere((element) => element.duration == Duration());
      reloadModes();
    });
  }

  void _afterStretch(side, value) {
    // if (stretchedValue == 0) return _afterDelete();

    if (slideModesWhenStretching)
      _stretchSelectedModes(value);
    else if (value > 1)
			_stretchSelectedModes(value, overwrite: side);
    else if (value < 1)
			_stretchSelectedModes(value, growFrom: side); 

    setState(() { reloadModes(); });
  }

  void _afterDelete() {
    AppController.openDialog("How would you like to delete?", "",
      buttonText: 'Cancel',
      buttons: [{
        'text': 'Replace with empty space',
        'color': Colors.white,
        'onPressed': () {
          removeSelected(replaceWithBlack: true);
        },
      }, oneModeSelected && selectedModes == [show.modeElements.last] ? null : {
        'text': 'Expand from the right',
        'color': Colors.white,
        'onPressed': () {
          removeSelected(growFrom: 'right');
        },
      }, oneModeSelected && selectedModes == [show.modeElements.first] ? null : {
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


  Widget _Waveforms() {
    if (audioPlayers.values.isEmpty || waveforms.values.isEmpty)
      return Container();


    waveformTimelineController?.setWindow(
      futureVisibleDuration: futureVisibleDuration,
      visibleDuration: visibleDuration,
      timelineDuration: duration,
      windowStart: windowStart,
    );

    return Container(
      height: 150,
      child: waveformTimelineController == null ? SpinKitCircle(color: Colors.blue) : SizedBox.expand(
        child: FractionallySizedBox(
          alignment: timelineContainsEnd && !timelineContainsStart ? FractionalOffset.centerRight : FractionalOffset.centerLeft,
          widthFactor: (futureScale / scale),//.clamp(0.0, 1.0),
          child: TimelineTrackWidget(
            controller: waveformTimelineController,
            onScrollUpdate: (windowStart) {
              setState(() {
                startOffset.value = windowStart.inMilliseconds.toDouble();
              });
            },
            onReorder: () {
              eachWithIndex(waveformTimelineController.elements, (index, element) => element.position = index + 1);
              waveformTimelineController.selectedElements.forEach((element) => element.save());
            },
            slideWhenStretching: slideModesWhenStretching,
            buildElement: (element) {
              Duration waveVisibleDuration = visibleDurationOf(element);
              return Waveform(
                controller: waveforms[element],
                visibleDuration: waveVisibleDuration,
                startOffset: maxDuration(windowStart - element.startOffset, Duration()),
                scale: scale * (element.duration.inMilliseconds / lengthInMiliseconds),
                futureScale: futureScale * (element.duration.inMilliseconds / lengthInMiliseconds),
                visibleBands: 1200 * (waveVisibleDuration.inMilliseconds / visibleMiliseconds).clamp(0.0, 1.0),
                color: [Colors.blue, Colors.red][waveforms.keys.toList().indexOf(element) % 2],
              );
            },
            onStretchUpdate: (side, value) {
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
          left: ((scrollContainerWidth) * playOffset.value / lengthInMiliseconds),
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
          var milisecondsNotVisible = lengthInMiliseconds - visibleMiliseconds;

          var offsetValue =  details.delta.dx * milisecondsNotVisible;
          startOffset.value = startOffset.value + (offsetValue/(scrollContainerWidth - scrollbarWidth));
          startOffset.value = startOffset.value.clamp(0.0, milisecondsNotVisible).toDouble();
          prepareTimeline();
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
            left: (horizontalPadding + scrollContainerWidth * startOffset.value / lengthInMiliseconds).clamp(horizontalPadding, max(horizontalPadding, containerWidth - scrollbarWidth - horizontalPadding)),
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

  Widget _ScaleSlider() {
    return Container(
      width: 150,
      decoration: BoxDecoration(
        color: Colors.grey
      ),
      margin: EdgeInsets.only(top: 10, left: 10),
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
                computeDataTimer = Timer(Duration(milliseconds: 250), () {
                  setState(() {
                    scale = futureScale;
                    setStartOffset();
                    prepareTimeline();
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
      child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Visibility(
          visible: timelineControllers.any((controller) => !controller.allElementsSelected),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
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
                child: Container(
                   padding: EdgeInsets.all(2),
                   child: Icon(Icons.arrow_drop_down),
                 )
               )
            ]
          )
        ),
        Visibility(
          visible: selectedElements.isNotEmpty,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
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
                child: Container(
                   padding: EdgeInsets.all(2),
                   child: Icon(Icons.arrow_drop_down),
                 )
               )
            ]
          )
        ),
        GestureDetector(
          onTap: () {
            setState(() => slideModesWhenStretching = !slideModesWhenStretching);
          },
          child: Container(
            padding: EdgeInsets.all(2),
            child: Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 Text("Push Mode "),
                 Icon(slideModesWhenStretching ? Icons.check_circle : Icons.circle, size: 16),
               ]
             )
           )
        ),
        GestureDetector(
          onTap: () {
            setState(() => showModeImages = !showModeImages);
          },
          child: Container(
            padding: EdgeInsets.all(2),
            child: Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 Text("Show Mode Images "),
                 Icon(showModeImages ? Icons.check_circle : Icons.circle, size: 16),
               ]
             )
           )
        ),
        GestureDetector(
          onTap: () {
            timelineControllers.forEach((controller) {
              if (controller.selectedElements.isNotEmpty)
                controller.selectedElements = [controller.selectedElements.last];
            });
            setState(() => selectMultiple = !selectMultiple);
            setState(() => timelineControllers.forEach((controller) => controller.toggleSelectMultiple()));
          },
          child: Container(
            padding: EdgeInsets.all(2),
            child: Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 Text("Select Multiple "),
                 Icon(selectMultiple ? Icons.check_circle : Icons.circle, size: 16),
               ]
             )
           )
        ),
        GestureDetector(
          onTap: () {
            timelineControllers.forEach((controller) {
              var current = controller.elementAtTime(playOffsetDuration);
              if (current.startOffset == playOffsetDuration) return;
              var index = controller.elements.indexOf(current);
              var newElement = current.dup();

              controller.elements.sublist(index+1).forEach((element) => element.position += 1);

              newElement.position += 1;
              newElement.startOffset = playOffsetDuration;
              newElement.duration = current.duration - (playOffsetDuration - current.startOffset);
              current.duration -= newElement.duration;
              show.timelineElements.add(newElement);
              newElement.save();
              current.save();
            });
            reloadModes();
            timelineControllers.forEach((controller) {
              controller.deselectAll();
              controller.toggleSelected(controller.elementAtTime(playOffsetDuration));
            });
          },
          child: Container(
            padding: EdgeInsets.all(2),
             child: Text("Split at playhead"),
           )
        ),
        Visibility(
          visible: selectedElements.isNotEmpty,
          child: GestureDetector(
            onTap: () {
              _afterDelete();
            },
            child: Container(
              padding: EdgeInsets.all(2),
                child: Text("Delete (${selectedElements.length})"),
             )
          ),
        ),
        Visibility(
          visible: modeTimelineControllers.any((controller) => controller.selectedElements.isNotEmpty),
          child: GestureDetector(
            onTap: () {
              var replacement = selectedElements.first.object.dup();
              Navigator.pushNamed(context, "/modes/${replacement.id}",
                arguments: {
                  'mode': replacement,
                  'autoUpdate': false,
                  'saveMessage': oneModeSelected ? "SAVE" : "REPLACE (${selectedElements.length})"
                }
              ).then((saved) {
                if (saved == true) {
                  selectedElements.forEach((element) {
                    element.object.updateFromCopy(replacement);
                  });
                }
              });
            },
            child: Container(
              padding: EdgeInsets.all(2),
              child: Text(oneModeSelected ? "Edit Mode" : "Replace (${selectedElements.length})")
            )
          )
        ),
        GestureDetector(
          onTap: () {
            setState(() => isPlaying = !isPlaying);
            updatePlayIndicatorAnimation();
          },
          child: Text(isPlaying ? 'Pause' : 'Play')
        ),
      ]
    )
    );
  }

  Widget _ModeColumn({mode}) {
    return ModeColumn(
      showImages: showModeImages,
      mode: mode,
    ); 
  }


  String _getTitle() {
    return 'Timeline';
  }

}

