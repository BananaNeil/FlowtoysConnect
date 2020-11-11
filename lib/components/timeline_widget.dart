import 'package:flutter_hsvcolor_picker/flutter_hsvcolor_picker.dart';
import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:quiver/iterables.dart' hide max, min;
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

  List<AssetsAudioPlayer> audioPlayers = [];



  bool showModeImages = true; 
  bool selectMultiple = false;
  List<Mode> selectedModes = [];
  bool slideModesWhenStretching = false;
  bool get oneModeSelected => selectedModes.length == 1;

  Duration dragDelta = Duration();


  bool isReordering = false;


  double scale = 1;
  double futureScale = 1;
  double maxScale = 20000.0;

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

  bool playersLoaded = false;
  bool modesLoaded = false;
  bool loading = true;


  double timelineGestureStartPointX;


  List<WaveformController> waveforms = [];
  List<Duration> get songDurations => waveforms.map((song) => song.duration).toList();

  Duration get windowStart => Duration(milliseconds: startOffset.value.toInt());
  Duration get windowEnd => windowStart + Duration(milliseconds: visibleMiliseconds.toInt());



  @override dispose() {
    startOffset.dispose();
    playOffset.dispose();
    audioPlayers.forEach((player) => player.dispose());
    super.dispose();
  }

  @override initState() {
    startOffset = AnimationController(vsync: this);
    playOffset = AnimationController(vsync: this);

    super.initState();
  }

  void updateDragDelta() {
    var prevIndex = selectedModeIndexes.first - 1;
    var nextIndex = selectedModeIndexes.last + 1;

    if (nextIndex != show.modes.length && selectedModes.last.endOffset + dragDelta > show.modes.elementAt(nextIndex).midPoint) {
      var nextMode = show.modes.elementAt(nextIndex);
      nextMode.startOffset -= selectedDuration;
      dragDelta -= nextMode.duration;
      selectedModes.forEach((mode) => mode.startOffset += nextMode.duration);
      show.modes.insert(selectedModeIndexes.first, show.modes.removeAt(nextIndex));
    } 
    if (prevIndex != -1 && selectedModes.first.startOffset + dragDelta < show.modes.elementAt(prevIndex).midPoint) {
      var prevMode = show.modes.elementAt(prevIndex);
      prevMode.startOffset += selectedDuration;
      dragDelta += prevMode.duration;
      selectedModes.forEach((mode) => mode.startOffset -= prevMode.duration);
      show.modes.insert(selectedModeIndexes.last, show.modes.removeAt(prevIndex));
    }
  }

  List<Mode> get consecutivelySelectedModes {
    if (selectedModesAreConsecutive) return selectedModes;
    else return [];
  }

  List<int> get selectedModeIndexes {
    return selectedModes.map((mode) => show.modes.indexOf(mode)).toList()..sort();
  }

  bool get selectedModesAreConsecutive {
    int index;
    int lastIndex;
    bool isConsecutive;
    return selectedModeIndexes.every((index) {
      isConsecutive = lastIndex == null || (index - lastIndex).abs() == 1;
      lastIndex = index;
      return isConsecutive;
    });
  }

  Duration startOfSongAtIndex(index) {
    return songDurations.sublist(0, index).reduce((a, b) => a + b);
  }


  List<Mode> get visibleModes {
    return show.modes.where((mode) {
      return mode.startOffset <= windowEnd &&
        mode.endOffset >= windowStart;
    }).toList();
  }

  List<WaveformController> get visibleWaveforms {
    return waveforms.where((waveform) {
      return waveform.startOffset <= windowEnd &&
        waveform.endOffset >= windowStart;
    }).toList();
  }

  Mode get currentMode {
    return modeAtTime(playOffsetDuration);
  }

  Mode modeAtTime(time) {
    return show.modes.firstWhere((mode) {
       return mode.startOffset <= time &&
           mode.endOffset > time;
    });
  }

  WaveformController get currentWaveform {
    return waveforms.firstWhere((waveform) {
       return waveform.startOffset <= playOffsetDuration &&
           waveform.endOffset > playOffsetDuration;
    });
  }

  AssetsAudioPlayer get currentPlayer {
    return audioPlayers[waveforms.indexOf(currentWaveform)];
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
    show.modes.forEach((mode) {
      mode.startOffset = Duration() + offset;
      offset += mode.duration;
    });

    var remainingTime = show.duration - offset;
    if (remainingTime > Duration()) {
      var emptySpaceAtEnd;

      if (show.modes.isNotEmpty && show.modes.last.isBlackMode)
        show.modes.last.duration += remainingTime;
      else {
        if (show.modes.isEmpty)
          emptySpaceAtEnd = show.createNewMode();
        else emptySpaceAtEnd = show.modes.last.dup();

        emptySpaceAtEnd.duration = remainingTime;
        emptySpaceAtEnd.startOffset = offset;
        emptySpaceAtEnd.setAsBlack();
        show.modes.add(emptySpaceAtEnd);
      }
    }

    if (!loading)
      scale *= show.duration.inMilliseconds / duration.inMilliseconds;
    duration = show.duration;
    scale = max(1, scale);
    futureScale = scale;
    setScrollBarWidth();
    setAnimationControllers();
  }

  void loadPlayers() {
    if (playersLoaded) return;
    playersLoaded = true;
    loadSongs().then((_) {
      var lengthInMiliseconds = 0.1;
      var index = 0;
      audioPlayers.forEach((player) {
        waveforms[index].startOffset = Duration(milliseconds: lengthInMiliseconds.toInt());
        lengthInMiliseconds += player.current.value.audio.duration.inMilliseconds;
        index += 1;
      });
      setState(() {
        reloadModes();
        setAnimationControllers();
      });
    });
  }

  Future<dynamic> loadSongs() {
    if (show == null) return Future.value(null);
    return show.downloadSongs().then((_) {
      print("Okay, done downloading files... ");
      setState(() {
        waveforms = show.songs.map((song) => WaveformController.open(song.localPath)).toList();
        loading = false;
      });

      AssetsAudioPlayer player;
      return Future.wait(show.songs.map((song) {
        player = AssetsAudioPlayer.newPlayer();
        audioPlayers.add(player);
        return player.open(Audio.file(song.localPath,
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
      audioPlayers.forEach((player) => player.pause());
      playOffset.stop();
    }
  }

  void removeSelectedModes({growFrom, replaceWithBlack}) {
    var replacedModeIndexes = [];
    selectedModes.reversed.forEach((mode) {
      var index = show.modes.indexOf(mode);
      var sibling;

      if (replacedModeIndexes.contains(index+1)) {
        replaceWithBlack = false;
        growFrom = 'right';
      }

      if (growFrom == 'right')
        if (index < show.modes.length - 1)
          sibling = show.modes[index + 1];
        else replaceWithBlack = true;
      else if (growFrom == 'left')
        if (index > 0)
          sibling = show.modes[index - 1];
        else replaceWithBlack = true;
      else sibling = show.modes.last;

      setState(() {
        if (replaceWithBlack == true) {
          replacedModeIndexes.add(show.modes.indexOf(mode));
          mode.setAsBlack();
          mode.save();
        } else {
          sibling.duration += mode.duration;
          show.modes.remove(mode);

          // Maybe do something here to make sure this succeeds?
          sibling.save();
          show.save();
        }
      });
    });
    selectedModes = [];
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

                  audioPlayers.forEach((player) => player.pause());
                  currentPlayer.seek(Duration(milliseconds: playOffset.value.toInt()) - currentWaveform.startOffset);
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
        audioPlayers.forEach((player) => player.pause());
        currentPlayer.seek(Duration(milliseconds: playOffset.value.toInt()) - currentWaveform.startOffset);
      },
      onPanUpdate: (details) {
        playOffset.value = startOffset.value + (visibleMiliseconds * details.localPosition.dx / containerWidth);
        audioPlayers.forEach((player) => player.pause());
        currentPlayer.seek(Duration(milliseconds: playOffset.value.toInt()) - currentWaveform.startOffset);
        // audioPlayer.currentPosition.value = Duration(milliseconds: playOffset.value.toInt());
      },
      onPanEnd: (details) {
        updatePlayIndicatorAnimation();
      },
      child:Container(
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

  visibleDurationOf(object) {
    var objectVisibleDuration;
    if (object.startOffset < windowStart)
      objectVisibleDuration = minDuration(visibleDuration, object.endOffset - windowStart);
    else if (object.endOffset > windowEnd)
      objectVisibleDuration = minDuration(visibleDuration, windowEnd - object.startOffset);
    else objectVisibleDuration = object.duration;

    return minDuration(objectVisibleDuration, object.duration);
  }

  Duration get invisibleDurationOfLastVisibleWaveform {
    if (audioPlayers.isEmpty || futureScale == scale) return Duration();
    var waveform = visibleWaveforms.last;
    return waveform.endOffset - windowEnd;
  }

  Widget _ModeContainer() {
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
          child:Stack(
            children: [
              _Modes(),
              _SelectedModeHandles(),
            ]
          )
        )
      )
    );
  }

  Mode get stretchedSibling {
    var index;
    if (!isStretching) return null;
    if (stretchedSide == 'left')
      index = show.modes.indexOf(selectedModes.first) - 1;
    else
      index = show.modes.indexOf(selectedModes.last) + 1;
    return show.modes.elementAt(index);
  }

  String get stretchedSide => selectionStretch.keys.firstWhere((key) => selectionStretch[key] != 1 );
  double get stretchedValue => selectionStretch[stretchedSide];

  Map<String, double> selectionStretch = {
    'left': 1.0,
    'right': 1.0,
  };

  void _stretchSelectedModes(stretchedValue, {overwrite, insertBlack, growFrom}) {
    Duration newDuration = selectedDuration * stretchedValue;
    var durationDifference = newDuration - selectedDuration;
    if (insertBlack == 'right') {
      var blackMode = selectedModes.last.dup();
      blackMode.duration = durationDifference * -1;
      blackMode.setAsBlack();
      blackMode.position += 1;
      blackMode.save();
      show.modes.insert(blackMode.position - 1, blackMode);
    } else if (insertBlack == 'left') {
      var blackMode = selectedModes.first.dup();
      blackMode.duration = durationDifference * -1;
      blackMode.setAsBlack();
      blackMode.position -= 1;
      blackMode.save();
    } else if (growFrom != null) {
      var sibling;
      if (growFrom == 'left')
        sibling = show.modes[show.modes.indexOf(selectedModes.first) - 1];
      else sibling = show.modes[show.modes.indexOf(selectedModes.last) + 1];

      // There is some sort of bug here where the first visible mode won't show a resize and another bug where it's dropping to zero if stretch < 1

      sibling.duration -= durationDifference;
      sibling.save();
    } else if (overwrite == 'left') {
      show.modes.sublist(0, selectedModeIndexes.first).reversed.forEach((mode) {
        var newStart = selectedModes.first.startOffset - durationDifference;
        if (mode.startOffset >= newStart) {
          Client.removeMode(mode);
          show.modes.remove(mode);
        } else if (mode.endOffset > newStart)
          mode.duration -= mode.endOffset - newStart;
      });
    } else if (overwrite == 'right') {
      show.modes.sublist(selectedModeIndexes.last + 1).forEach((mode) {
        var newEnd = selectedModes.last.endOffset + durationDifference;
        if (mode.endOffset <= newEnd) {
          Client.removeMode(mode);
          show.modes.remove(mode);
        } else if (mode.startOffset < newEnd)
          mode.duration -= newEnd - mode.startOffset;
      });
    }
    selectedModes.forEach((mode) {
      mode.duration *= stretchedValue;
      if (mode.duration == Duration()) {
        Client.removeMode(mode);
        show.modes.remove(mode);
      } else mode.save();
    });
    selectedModes.removeWhere((mode) => mode.duration == Duration());
    reloadModes();
  }

  void _afterStretch() {
    // if (stretchedValue == 0) return _afterDelete();

    if (slideModesWhenStretching)
      _stretchSelectedModes(stretchedValue);
    else if (stretchedValue > 1)
			_stretchSelectedModes(stretchedValue, overwrite: stretchedSide);
    else if (stretchedValue < 1)
			_stretchSelectedModes(stretchedValue, growFrom: stretchedSide); 

    setState(() {
      selectionStretch[stretchedSide] = 1.0;
    });
  }

  void _afterDelete() {
    AppController.openDialog("How would you like to delete?", "",
      buttonText: 'Cancel',
      buttons: [{
        'text': 'Replace with black mode',
        'color': Colors.white,
        'onPressed': () {
          removeSelectedModes(replaceWithBlack: true); 
        },
      }, oneModeSelected && selectedModes == [show.modes.last] ? null : {
        'text': 'Expand mode from the right',
        'color': Colors.white,
        'onPressed': () {
          removeSelectedModes(growFrom: 'right'); 
        },
      }, oneModeSelected && selectedModes == [show.modes.first] ? null : {
        'text': 'Expand mode from the left',
        'color': Colors.white,
        'onPressed': () {
          removeSelectedModes(growFrom: 'left'); 
        },
      }, {
        'text': 'Slide modes to the Left',
        'color': Colors.red,
        'onPressed': () {
          removeSelectedModes(); 
        },
      }]
    );
  }

  Duration get selectedDuration => consecutivelySelectedModes.map((mode) {
    return mode.duration;
  }).reduce((a, b) => a+b);

  bool get isStretching => selectionStretch['right'] != 1 || selectionStretch['left'] != 1;
  bool get isActingOnSelected => isStretching || isReordering;
  Timer dragScrollTimer;


  void triggerDragScroll(movementAmount) {
    dragScrollTimer?.cancel();
    dragScrollTimer = Timer(Duration(milliseconds: 50), () => setState(() {
      dragDelta += movementAmount;
    }));
  }

  Widget _SelectedModeHandles() {
    if (consecutivelySelectedModes.isEmpty)
      return Container();

    var firstMode = consecutivelySelectedModes.first;
    var lastMode = consecutivelySelectedModes.last;
    var visibleSelectedDuration;
    var end;
    var start;

    if (isReordering) {
      visibleSelectedDuration = selectedDuration;
      start = maxDuration(Duration(), firstMode.startOffset - windowStart + dragDelta);
      start = minDuration(start, visibleDuration - selectedDuration);
      end = start + selectedDuration;

      // This is a bunch of logic that auto scrolls the timeline
      // when dragging modes close to the start or end
      var triggerPoint = visibleDuration * 0.05;
      var movementAmount = minDuration(Duration(seconds: 5), duration * 0.01);

      if (start <= triggerPoint) {
        movementAmount *= -1;
        startOffset.value += minDuration(movementAmount, start).inMilliseconds;
        if (startOffset.value > 0)
          triggerDragScroll(movementAmount);

      } else if (end >= visibleDuration - triggerPoint) {
        startOffset.value += movementAmount.inMilliseconds;
        if (windowStart < (duration - visibleDuration))
          triggerDragScroll(movementAmount);
      }
    } else { // if !isReordering
      visibleSelectedDuration = consecutivelySelectedModes.map((mode) {
        return visibleDurationOf(mode);
      }).reduce((a, b) => a+b);

      end = maxDuration(Duration(), (firstMode.startOffset - windowStart)) +
          (visibleSelectedDuration * max(0, selectionStretch['right']));

      start = visibleDuration - maxDuration(Duration(), windowEnd - lastMode.endOffset) -
          (visibleSelectedDuration * max(0, selectionStretch['left']));

      start = maxDuration(start, Duration());
      end = minDuration(end, visibleDuration);
    }


    var startWidth = (start.inMilliseconds / milisecondsPerPixel);
    var endWidth = (visibleDuration - end).inMilliseconds / milisecondsPerPixel;

		var visiblySelectedRatio = (visibleSelectedDuration.inMilliseconds / visibleDuration.inMilliseconds);
    var selectedModesVisibleInWindow = lastMode.endOffset + dragDelta > windowStart && firstMode.startOffset + dragDelta < windowEnd;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Visibility(
          visible: firstMode.startOffset + dragDelta > windowStart && selectedModesVisibleInWindow,
          child: Flexible(
            flex: start.inMilliseconds,
            child: Container(
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanEnd: (details) {
                    _afterStretch();
                  },
                  onPanStart: (details) {
                    selectionStretch['left'] = 1;
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      var maxStretch = end.inMilliseconds / visibleSelectedDuration.inMilliseconds;
                      selectionStretch['left'] -= 3 * (details.delta.dx / containerWidth) / visiblySelectedRatio;
                      selectionStretch['left'] = selectionStretch['left'].clamp(0.0, maxStretch);
                    });
                  },
                  child: Container(
                    width: start <= Duration() ? 0 : 30,
                    child: Transform.translate(
                      offset: Offset(2 - max(30 - startWidth, 0.0), 0),
                      child: Icon(Icons.arrow_left, size: 40),
                    )
                  )
                ),
              )
            )
          ),
        ),
        Flexible(
          flex: max(1, (end - start).inMilliseconds),
          child: Opacity(
            opacity: isActingOnSelected ? 1 : 0,
            child: Container(
              height: isActingOnSelected ? null : 0,
							decoration: BoxDecoration(
								boxShadow: [
									BoxShadow(
										color: Colors.black.withOpacity(0.5),
										spreadRadius: 5,
										blurRadius: 7,
										offset: Offset(0, 3), // changes position of shadow
									),
								],
							),
              child: Row(
                children: selectedModes.map((mode) {
                  return Flexible(
                    flex: mode.duration.inMilliseconds,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: _ModeColumn(mode: mode),
                    )
                  );
                }).toList(),
              )
            )
          )
        ),
        Visibility(
          visible: lastMode.endOffset + dragDelta < windowEnd && selectedModesVisibleInWindow,
          child: Flexible(
            flex: (visibleDuration - end).inMilliseconds,
            child: Visibility(
              visible: endWidth > 0,
              child: Container(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanEnd: (details) {
                      _afterStretch();
                    },
                    onPanStart: (details) {
                      selectionStretch['right'] = 1;
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        var maxStretch = (visibleDuration - start).inMilliseconds / visibleSelectedDuration.inMilliseconds;
                        selectionStretch['right'] += 3 * (details.delta.dx / containerWidth) / visiblySelectedRatio;
                        selectionStretch['right'] = selectionStretch['right'].clamp(0, maxStretch);
                      });
                    },
                    child: Container(
                      width: 30,
                      child: Transform.translate(
                        offset: Offset(-12, 0),
                        child: Icon(Icons.arrow_right, size: 40),
                      )
                    )
                  )
                )
              )
            )
          )
        ),
      ]
    );
  }

  void toggleSelected(mode, {only}) {
    setState(() {
      var isSelected = selectedModes.contains(mode);
      if (isSelected && only != 'select') 
        selectedModes.remove(mode);
      else if (selectMultiple)
        selectedModes.add(mode);
      else
        selectedModes = [mode];

      selectedModes.sort((a, b) => a.startOffset.compareTo(b.startOffset));
    });
  }

  Map<Type, GestureRecognizerFactory> get timelineGestures => {
    ForcePressGestureRecognizer: GestureRecognizerFactoryWithHandlers<ForcePressGestureRecognizer>(() => new ForcePressGestureRecognizer(),
      (ForcePressGestureRecognizer instance) {
        instance..onStart = (details) {
          print("FORCE START: ${details}");
        };
        instance..onUpdate = (details) {
          print("FORCE UPDATE: ${details}");
        };
      }
    ),
    DelayedMultiDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<DelayedMultiDragGestureRecognizer>(() => new DelayedMultiDragGestureRecognizer(),
      (DelayedMultiDragGestureRecognizer instance) {
        instance..onStart = (Offset offset) {
          var mode = modeAtTime(windowStart + visibleDuration * (offset.dx / containerWidth));
          toggleSelected(mode, only: 'select');
          if (!selectedModesAreConsecutive) selectedModes = [mode];
          setState(() => isReordering = true);
          return LongPressDraggable(
            onUpdate: (details) {
              setState(() {
                dragDelta += Duration(milliseconds: (details.delta.dx * milisecondsPerPixel).toInt());
                updateDragDelta();
              });
            },
            onEnd: (details) {
              dragDelta = Duration();
              setState(() => isReordering = false);
              reloadModes();
              eachWithIndex(show.modes, (index, mode) => mode.position = index + 1);
              selectedModes.forEach((mode) => mode.save());
            }
          );
        };
      },
    ),
    TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(() => TapGestureRecognizer(),
      (TapGestureRecognizer instance) {
        instance
          ..onTapUp = (details) {
            var mode = modeAtTime(windowStart + visibleDuration * (details.localPosition.dx / containerWidth));
            toggleSelected(mode);
            setState(() {
              dragDelta = Duration();
              isReordering = false;
            });
        };
      },
    ),
  };

  Widget _Modes() {
    return RawGestureDetector(
      gestures: timelineGestures,
      child:  Row(
        children: mapWithIndex(visibleModes, (index, mode) {
          var isSelected = selectedModes.contains(mode);
          Duration modeVisibleDuration = visibleDurationOf(mode);
          if (isSelected && isReordering)
            if (mode == selectedModes[0])
              modeVisibleDuration = selectedDuration;
            else modeVisibleDuration = Duration();
          var widget =  Flexible(
            flex: ((modeVisibleDuration.inMilliseconds / futureVisibleMiliseconds).clamp(0.0, 1.0) * 1000.0).ceil(),
              child: Container(
                decoration: BoxDecoration(
                  border: (isSelected && !isActingOnSelected) ? Border.all(color: Colors.white, width: 2) : 
                    Border(
                      top: BorderSide(color: Color(0xFF555555), width: 2),
                      bottom: BorderSide(color: Color(0xFF5555555), width: 2),
                    )
                ),
                child: Stack(
                  children: (isSelected && isActingOnSelected) ? [
                    isStretching && !slideModesWhenStretching ? _ModeColumn(mode: stretchedSibling) : Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          const BoxShadow(
                            color: Color(0xAA000000),
                          ),
                          const BoxShadow(
                            color: Color(0xFF333333),
                            spreadRadius: -4.0,
                            blurRadius: 4.0,
                          ),
                        ],
                      ),
                    )
                  ] : [
                    _ModeColumn(mode: mode),
                     Container(
                       width: stretchedSibling == mode ? 0 : 1,
                       decoration: BoxDecoration(
                          color: Color(0xBBFFFFFF),
                          border: Border(
                            top: BorderSide(color: Color(0x00000000), width: 2),
                            bottom: BorderSide(color: Color(0x00000000), width: 2),
                          )
                       ),
                     )
                  ]
                )
              )
          );
          return widget;
        }).toList() + [Flexible(
          flex: ((!timelineContainsEnd ? 0 : invisibleDurationOfLastVisibleWaveform.inMilliseconds / futureVisibleMiliseconds) * 1000).toInt(),
          child: Container(),
        )]
      )
    );
  }

  Widget _Waveforms() {
    var visibleSongs = visibleWaveforms;
    if (audioPlayers.isEmpty)
      return Container();

    return Container(
      height: 150,
      child: SizedBox.expand(
        child: FractionallySizedBox(
          alignment: timelineContainsEnd && !timelineContainsStart ? FractionalOffset.centerRight : FractionalOffset.centerLeft,
          widthFactor: (futureScale / scale),//.clamp(0.0, 1.0),
          child: Row(
            children: mapWithIndex(visibleSongs, (index, waveform) {
              Duration waveVisibleDuration = visibleDurationOf(waveform);
              var widget =  Flexible(
                flex: ((waveVisibleDuration.inMilliseconds / futureVisibleMiliseconds).clamp(0.0, 1.0) * 1000.0).ceil(),
                child: Waveform(
                  controller: waveform,
                  visibleDuration: waveVisibleDuration,
                  startOffset: maxDuration(windowStart - waveform.startOffset, Duration()),
                  scale: scale * (waveform.duration.inMilliseconds / lengthInMiliseconds),
                  futureScale: futureScale * (waveform.duration.inMilliseconds / lengthInMiliseconds),
                  visibleBands: 1200 * (waveVisibleDuration.inMilliseconds / visibleMiliseconds).clamp(0.0, 1.0),
                  color: [Colors.blue, Colors.red][waveforms.indexOf(waveform) % 2],
                )
              );
              return widget;
            }).toList() + [
              Flexible(
                flex: ((max(0, (windowEnd - waveforms.last.endOffset).inMilliseconds) / futureVisibleMiliseconds).clamp(0.0, 1.0) * 1000.0).ceil(),
                child: Container(),
              ),
            ]
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
              min: 1/maxScale,
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
          visible: selectedModes != show.modes.length,
          child: GestureDetector(
            onTap: () {
              setState(() => selectedModes = List.from(show.modes));
            },
            child: Container(
               padding: EdgeInsets.all(2),
               child: Text("Select All"),
             )
           )
        ),
        Visibility(
          visible: selectedModes.isNotEmpty,
          child: GestureDetector(
            onTap: () {
              setState(() => selectedModes = []);
            },
            child: Container(
               padding: EdgeInsets.all(2),
               child: Text("Deselect All"),
             )
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
                 Text("Slide Modes When Expanding "),
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
            selectedModes = [selectedModes.last];
            setState(() => selectMultiple = !selectMultiple);
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
            var current = currentMode;
            var newMode = current.dup();
            var index = show.modes.indexOf(current);

            newMode.position += 1;
            newMode.startOffset = playOffsetDuration;
            newMode.duration = current.duration - (playOffsetDuration - current.startOffset);
            current.duration -= newMode.duration;
            setState(() {
              show.modes.insert(index+1, newMode);
            });
            current.save();
            newMode.save();
            if (selectMultiple)
              selectedModes = [current, newMode];
            else selectedModes = [newMode];
          },
          child: Container(
            padding: EdgeInsets.all(2),
             child: Text("Split at playhead"),
           )
        ),
        Visibility(
          visible: selectedModes.isNotEmpty,
          child: GestureDetector(
            onTap: () {
              _afterDelete();
            },
            child: Container(
              padding: EdgeInsets.all(2),
                child: Text("Delete (${selectedModes.length})"),
             )
          ),
        ),
        Visibility(
          visible: selectedModes.isNotEmpty,
          child: GestureDetector(
            onTap: () {
              var replacement = selectedModes.first.dup();
              Navigator.pushNamed(context, "/modes/${replacement.id}",
                arguments: {
                  'mode': replacement,
                  'autoUpdate': false,
                  'saveMessage': oneModeSelected ? "SAVE" : "REPLACE (${selectedModes.length})"
                }
              ).then((saved) {
                if (saved == true) {
                  selectedModes.forEach((mode) {
                    mode.updateFromCopy(replacement);
                  });
                }
              });
            },
            child: Container(
              padding: EdgeInsets.all(2),
              child: Text(oneModeSelected ? "Edit Mode" : "Replace (${selectedModes.length})")
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


class LongPressDraggable extends Drag {
  final GestureDragUpdateCallback onUpdate;
  final GestureDragEndCallback onEnd;

  LongPressDraggable({this.onUpdate, this.onEnd});

  @override
  void update(DragUpdateDetails details) {
    super.update(details);
    onUpdate(details);
  }

  @override
  void end(DragEndDetails details) {
    super.end(details);
    onEnd(details);
  }
}
