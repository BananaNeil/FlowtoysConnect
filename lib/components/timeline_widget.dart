import 'package:flutter_hsvcolor_picker/flutter_hsvcolor_picker.dart';
import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:quiver/iterables.dart' hide max, min;
import 'package:app/helpers/duration_helper.dart';
import 'package:app/components/waveform.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
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

  Timer computeDataTimer;
  Show show;

  List<String> songs;
  List<AssetsAudioPlayer> audioPlayers = [];

  List<WaveformController> waveforms = [];
  List<Duration> get songDurations => waveforms.map((song) => song.duration).toList();

  Duration startOfSongAtIndex(index) {
    return songDurations.sublist(0, index).reduce((a, b) => a + b);
  }

  Duration get windowStart => Duration(milliseconds: startOffset.value.toInt());
  Duration get windowEnd => windowStart + Duration(milliseconds: visibleMiliseconds.toInt());


  List<WaveformController> get visibleWaveforms {
    return waveforms.where((waveform) {
      return waveform.startOffset <= windowEnd &&
        waveform.startOffset + waveform.duration >= windowStart;
    }).toList();
  }

  WaveformController get currentWaveform {
    return waveforms.firstWhere((waveform) {
       return waveform.startOffset <= playOffsetDuration &&
           waveform.startOffset + waveform.duration > playOffsetDuration;
    });
  }

  //
  //   var playerStartingPoint = Duration(seconds: 0);
  //   var currentOffset = Duration(milliseconds: playOffset.value.toInt());
  //   return audioPlayers.firstWhere((player) {
  //     var playerDuration = player.current.value.audio.duration;
  //     if (playerStartingPoint <= currentOffset && playerStartingPoint + playerDuration > currentOffset)
  //       return true;
  //     playerStartingPoint += playerDuration;
  //     return false;
  //   });
  // }

  double scale = 20;
  double futureScale = 20;
  double maxScale = 20000.0;

  bool isPlaying = false;

  double lengthInMiliseconds = 1;
  Duration get visibleDuration => Duration(milliseconds: (lengthInMiliseconds / scale).toInt());
  Duration get futureVisibleDuration => Duration(milliseconds: (lengthInMiliseconds / futureScale).toInt());
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
  bool get timelineContainsEnd => startOffset.value + futureVisibleMiliseconds >= lengthInMiliseconds;
  double get milisecondsPerPixel => visibleMiliseconds / containerWidth;

  bool playersLoaded = false;
  bool loading = true;



  @override dispose() {
    startOffset.dispose();
    playOffset.dispose();
    waveforms.forEach((waveform) => waveform.player.dispose());
    super.dispose();
  }

  @override initState() {
    songs = ['assets/audio/test.wav','assets/audio/test2.wav', 'assets/audio/test.wav', 'assets/audio/test.wav'];

    startOffset = AnimationController(vsync: this);
    playOffset = AnimationController(vsync: this);

    super.initState();

  }

  void loadPlayers() {
    if (playersLoaded) return;
    playersLoaded = true;
    loadSongs().then((_) {
      lengthInMiliseconds = 0.1;
      var index = 0;
      audioPlayers.forEach((player) {
        waveforms[index].player = player;
        waveforms[index].startOffset = Duration(milliseconds: lengthInMiliseconds.toInt());
        lengthInMiliseconds += player.current.value.audio.duration.inMilliseconds;
        index += 1;
      });
      setState(() {
        setAnimationControllers();
      });
    });
  }

  fetchShow() {
    Client.getShow(show.id).then((response) {
      setState(() {
        if (response['success']) {
          show = response['show'];
        }
      });
    });
  }

  Future<void> downloadSongs() {
    return Future.wait(show.songs.map((song) {
			return song.downloadFile();
    }));
  }

  Future<dynamic> loadSongs() {
    if (show == null) return Future.value(null);
    return downloadSongs().then((_) {
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
    playOffset = AnimationController(
      upperBound: lengthInMiliseconds,
      lowerBound: 0,
      vsync: this
    );
  }

  void prepareTimeline() {
    setScrollBarWidth();
  }

  void setScrollBarWidth() {
    scrollbarWidth = (scrollContainerWidth / futureScale).clamp(10, scrollContainerWidth).toDouble();
  }

  void updatePlayIndicatorAnimation() {
    if (isPlaying) {
      currentWaveform.player.play();
      playOffset.animateTo(lengthInMiliseconds,
        duration: Duration(milliseconds: remainingMiliseconds.toInt()),
      );
    } else {
      waveforms.forEach((waveform) => waveform.player.pause());
      playOffset.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    show = (ModalRoute.of(context).settings.arguments as Map)['show']; 
    loadPlayers();
    // startOffset.value = 1.0;
    return Center(
      child: loading ?
        SpinKitCircle(color: AppController.blue) : Container(
        padding: EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.black,
          )
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) {
            containerWidth = box.maxWidth;
            if (audioPlayers.length == 0)
              return Container();

            return Column(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() => isPlaying = !isPlaying);
                    updatePlayIndicatorAnimation();
                  },
                  child: Text(isPlaying ? 'Pause' : 'Play')
                ),
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
    // var left;
    // var right;
    // if (timelineContainsEnd)
    //   right = (((lengthInMiliseconds - playOffset.value) / futureVisibleMiliseconds) * containerWidth) - (playHeadWidth / 2);
    // else
    //   left = (((playOffset.value - startOffset.value) / futureVisibleMiliseconds) * containerWidth) - (playHeadWidth / 2);
    return AnimatedBuilder(
      animation: playOffset,
      builder: (ctx, w) {
        return Positioned(
          top: 3,
          bottom: 0,
          left: timelineContainsEnd ? null : (((playOffset.value - startOffset.value) / futureVisibleMiliseconds) * containerWidth) - (playHeadWidth / 2),// ((containerWidth + playHeadWidth)) - (playHeadWidth / 2),
          right: !timelineContainsEnd ? null : (((lengthInMiliseconds - playOffset.value) / futureVisibleMiliseconds) * containerWidth) - (playHeadWidth / 2),
          child: Column(
            children: [
              GestureDetector(
                onPanUpdate: (details) {
                  var offsetValue = details.delta.dx * (visibleMiliseconds/(containerWidth + playHeadWidth));
                  playOffset.value += offsetValue;

                  waveforms.forEach((waveform) => waveform.player.pause());
                  currentWaveform.player.seek(Duration(milliseconds: playOffset.value.toInt()) - currentWaveform.startOffset);
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

  Widget _Timestamps() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("${(startOffset.value/1000).toStringAsFixed(1)} sec"),
        Text("${((startOffset.value + visibleMiliseconds)/1000).toStringAsFixed(1)} sec"),
      ],
    );
  }

  double timelineGestureStartPointX;

  Widget _TimelineContainer() {
    return Stack(
      children: [
        _TimelineViewer(),
        _PlayIndicatorTrack(),
        _PlayIndicator(),
      ]
    );
  }

  Widget _PlayIndicatorTrack() {
    return GestureDetector(
      onPanStart: (details) {
        playOffset.value = startOffset.value + (visibleMiliseconds * details.localPosition.dx / containerWidth);
        waveforms.forEach((waveform) => waveform.player.pause());
        currentWaveform.player.seek(Duration(milliseconds: playOffset.value.toInt()) - currentWaveform.startOffset);
      },
      onPanUpdate: (details) {
        playOffset.value = startOffset.value + (visibleMiliseconds * details.localPosition.dx / containerWidth);
        waveforms.forEach((waveform) => waveform.player.pause());
        currentWaveform.player.seek(Duration(milliseconds: playOffset.value.toInt()) - currentWaveform.startOffset);
        // audioPlayer.currentPosition.value = Duration(milliseconds: playOffset.value.toInt());
      },
      onPanEnd: (details) {
        updatePlayIndicatorAnimation();
      },
      child:Container(
        height: 16,
        decoration: BoxDecoration(
          color: Colors.black
        )
      )
    );
  }

  Widget _TimelineViewer() {
    return Container(
      margin: EdgeInsets.only(top: 18),
      child: GestureDetector(
        child: Column(
          children: [
            _Modes(),
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

  visibleDurationOf(object, {isFirst, isLast}) {
    var objectVisibleDuration;
    if (isFirst == true)
      objectVisibleDuration = minDuration(visibleDuration, (object.duration + object.startOffset) - windowStart);
    else if (isLast == true)
      objectVisibleDuration = minDuration(visibleDuration, windowEnd - object.startOffset);
    else objectVisibleDuration = object.duration;

    return minDuration(objectVisibleDuration, object.duration);
  }

  Duration get invisibleDurationOfLastVisibleWaveform {
    if (futureScale == scale) return Duration();
    var waveform = visibleWaveforms.last;
    return (waveform.startOffset + waveform.duration) - windowEnd;
  }

  Widget _Modes() {
    // Just change this to visible modes, and done! ;)
    var modes = waveforms;
    var currentModes = visibleWaveforms;
    return Container(
      height: 150,
      child: SizedBox.expand(
        child: FractionallySizedBox(
          // alignment: FractionalOffset.centerLeft,
          alignment: timelineContainsEnd ? FractionalOffset.centerRight : FractionalOffset.centerLeft,
          widthFactor: (futureScale / scale),//.clamp(0.0, 1.0),
          child: Row(
            children: mapWithIndex(currentModes, (index, mode) {
              Duration modeVisibleDuration = visibleDurationOf(mode,
                isLast: index == currentModes.length - 1,
                isFirst: index == 0,
              );
              var widget =  Flexible(
                flex: ((modeVisibleDuration.inMilliseconds / futureVisibleMiliseconds).clamp(0.0, 1.0) * 1000.0).ceil(),
                child: Container(
                    decoration: BoxDecoration(
                  color: [Colors.blue, Colors.red][modes.indexOf(mode) % 2],
                    )
                )
              );

              // waveformStart += waveform.duration;
              return widget;
            }).toList() + [Flexible(
              flex: ((!timelineContainsEnd ? 0 : invisibleDurationOfLastVisibleWaveform.inMilliseconds / futureVisibleMiliseconds) * 1000).toInt(),
              child: Container(),
            )]
          )
        )
      )
    );
  }

  Widget _Waveforms() {
    var visibleSongs = visibleWaveforms;
    return Container(
      height: 150,
      child: SizedBox.expand(
        child: FractionallySizedBox(
          // alignment: FractionalOffset.centerLeft,
          alignment: timelineContainsEnd ? FractionalOffset.centerRight : FractionalOffset.centerLeft,
          widthFactor: (futureScale / scale),//.clamp(0.0, 1.0),
          child: Row(
            children: mapWithIndex(visibleSongs, (index, waveform) {
              Duration waveVisibleDuration = visibleDurationOf(waveform,
                isLast: index == visibleSongs.length - 1,
                isFirst: index == 0,
              );
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

              // waveformStart += waveform.duration;
              return widget;
            }).toList() + [Flexible(
              flex: ((!timelineContainsEnd ? 0 : invisibleDurationOfLastVisibleWaveform.inMilliseconds / futureVisibleMiliseconds) * 1000).toInt(),
              child: Container(),
            )]
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
                    var oldOffset = startOffset;
                    startOffset = AnimationController(
                      upperBound: lengthInMiliseconds - visibleMiliseconds,
                      value: oldOffset.value,
                      lowerBound: 0,
                      vsync: this,
                    );

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


  String _getTitle() {
    return 'Timeline';
  }

}



