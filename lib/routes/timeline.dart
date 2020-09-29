import 'package:flutter_hsvcolor_picker/flutter_hsvcolor_picker.dart';
import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:app/models/mode_list.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:quiver/iterables.dart' hide max, min;
import 'package:flutter/material.dart';
import 'package:app/models/mode.dart';
import 'package:flutter/physics.dart';






import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';






class Timeline extends StatelessWidget {
  Timeline({this.id});

  final String id; 

  @override
  Widget build(BuildContext context) {
    return TimelinePage(id: id);
  }
}

class TimelinePage extends StatefulWidget {
  TimelinePage({Key key, this.id}) : super(key: key);
  final String id;

  @override
  _TimelinePageState createState() => _TimelinePageState(id);
}

class _TimelinePageState extends State<TimelinePage> with TickerProviderStateMixin {
  _TimelinePageState(this.id);

  final String id;

  Map<int, dynamic> chunkedData = {};
  Map<int, int> maxValues = {};
  List<num> data = [];
  Timer computeDataTimer;

  double futureScale = 20;
  double scale = 20;
  double lengthInSeconds;
  int maxVisibleBands = 1200;
  int visibleBands;
  int localMinValue = 1;
  int localMaxValue = 1;
  double localMedianValue = 1;
  double playHeadWidth = 20.0;

  AnimationController startOffset;
  AnimationController playOffset;

  AssetsAudioPlayer audioPlayer = AssetsAudioPlayer();
  bool isPlaying = false;

  @override initState() {
    visibleBands = maxVisibleBands;
    super.initState();
    loadFile().then((_) {
      startOffset = AnimationController(
        upperBound: lengthInMiliseconds,
        lowerBound: 0,
        vsync: this
      );
      playOffset = AnimationController(
        upperBound: lengthInMiliseconds,
        lowerBound: 0,
        vsync: this
      );
    });
  }

  // int get SecondOffset {
  //   if (data.length == 0) return 0;
  //   startOffset.value.toInt().clamp(0, scaledData.length - visibleBands);
  // }




  // double get samplesPerBand => scale * maxVisibleBands; 
  // int get chunkSize => (data.length / samplesPerBand).toInt().clamp(1, 1000000);
  //
  int samplesPerSecond = 44410; // This gets updated
  //
  // double get bandsPerSecond => samplesPerBand / samplesPerSecond.toDouble();
  //
  double get lengthInMiliseconds => lengthInSeconds * 1000.0;
  double get visibleMiliseconds => (lengthInMiliseconds / scale);

  // We use min(now, future) here because zooming out and zooming in use two different strategies.
  // Zooming out keeps the same number of bands and shrinks ther widths,
  // Zooming in grows the widths by decreasing visible bands.
  double get milisecondsPerBand => min(visibleMiliseconds, futureVisibleMiliseconds) / visibleBands;
  double get futureVisibleMiliseconds => (lengthInMiliseconds / futureScale);

  // double get bandsPerVisibleMiliseconds => visibleBands / visibleMiliseconds;
  //
  // int get bandOffset => (startOffset.value / bandsPerVisibleMilisecond).toInt().clamp(0, scaledData.length - visibleBands);
  double get remainingMiliseconds => lengthInMiliseconds - playOffset.value;



  int get bandOffset => data.length == 0 ? 0 : (startOffset.value / milisecondsPerBand).toInt().clamp(0, scaledData.length - visibleBands);
  // int get milisecondOffset => data.length == 0 ? 0 : startOffset.value.toInt().clamp(0, scaledData.length - visibleBands);

  double get samplesPerBand => scale * maxVisibleBands; 
  int get chunkSize => (data.length / samplesPerBand).toInt().clamp(1, 1000000);
  int chunkSizeWas;

  double maxScale = 20000.0;

  List<int> get scaledData {
    var chunkKey = min(11, chunkSize);
    if (data.length == 0) return [];
    if (chunkSize < 11) {
      if (chunkedData[chunkKey] != null)
        return chunkedData[chunkKey];
    } else if (chunkSizeWas == chunkSize)
      return chunkedData[chunkKey];

    chunkSizeWas = chunkSize;

    if (chunkSize <= 1.0) return data;

    var partitionedData = partition(data, chunkSize.clamp(1, data.length));
    chunkedData[chunkKey] = List<int>.from(partitionedData.map((chunk) {
      return (chunk.fold(0, (a, b) => a + b) / chunkSize).toInt();
    }));

    return chunkedData[chunkKey];
  }

  List<int> getVisibleData() {
    //
    // You can optimize quite a bit here by keeping a slightly larger sublist in memory...
    // print('dealing with ${scaledData.length}, but sublisting with ${bandOffset}...${(bandOffset + visibleBands).clamp(0, scaledData.length)}');
    //
    return scaledData.sublist(bandOffset, (bandOffset + visibleBands).clamp(0, scaledData.length));
  }


  loadFile() async {
    audioPlayer = AssetsAudioPlayer.newPlayer();
    audioPlayer.open(Audio('assets/audio/test.wav',
      metas: Metas(
        title:  "Insert Show Name",
        artist: "Username",
        album: "Flowtoys App",
        image: MetasImage.asset("assets/images/logo.png"), //can be MetasImage.network
      ),
    ), autoStart: false, showNotification: true);


    var song = await loadSong();
    setState(() {
      data = song.buffer.asUint8List();
      if (listEquals(data.sublist(0, 4), [82, 73, 70, 70])) {
        var bytesOf32 = song.buffer.asUint32List();
        print(bytesOf32);
        var fileSize = bytesOf32[1];
        var bitrate = bytesOf32[7];
        samplesPerSecond = bytesOf32[6];
        lengthInSeconds = fileSize / bitrate;
        data = data.sublist(44, data.length);
      } else print("THIS IS NOT A RIFF (wav) FILE");
    });
  }

  Future<ByteData> loadSong() async {
    return await rootBundle.load('assets/audio/test.wav');
  }

  List<int> visibleData;
  double containerWidth = 0;
  double scrollbarWidth;

  double get scrollContainerWidth => containerWidth * 0.98;

  bool get timelineContainsEnd => startOffset.value + futureVisibleMiliseconds >= lengthInMiliseconds;

  List<int> prepareSublist() {
    visibleData = getVisibleData();
    var minimum = 1000000000;
    var maximum = 0;
    var sum = 0;
    visibleData.forEach((value) {
      sum += value;
      if (value < minimum)
        minimum = value;
      if (value > maximum)
        maximum = value;
    });

    localMinValue = minimum.clamp(1, 1000000000);
    localMaxValue = maximum.clamp(1, 1000000000);
    localMedianValue = visibleData[(visibleData.length / 2).toInt()].toDouble();
    setScrollBarWidth();
    return visibleData;
  }

  void setScrollBarWidth() {
    scrollbarWidth = (scrollContainerWidth / futureScale).clamp(10, scrollContainerWidth).toDouble();
  }

  void updatePlayIndicatorAnimation() {
    if (isPlaying) {
      audioPlayer.play();
      playOffset.animateTo(lengthInMiliseconds,
        duration: Duration(milliseconds: remainingMiliseconds.toInt()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // startOffset.value = 1.0;
    return Scaffold(
      backgroundColor: AppController.darkGrey,
      appBar: AppBar(
        title: Text(_getTitle()), backgroundColor: Color(0xff222222),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.content_paste),
          ),
        ],
      ),
      body: Center(
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
              if (data.length == 0)
                return Container();

              return Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() => isPlaying = !isPlaying);
                      updatePlayIndicatorAnimation();
                      if (!isPlaying) {
                        audioPlayer.pause();
                        playOffset.stop();
                      }
                    },
                    child: Text(isPlaying ? 'Pause' : 'Play')
                  ),
                  // Timeline:
                  AnimatedBuilder(
                    animation: startOffset,
                    builder: (ctx, w) {
                      visibleData = visibleData ?? prepareSublist();
                      visibleData = getVisibleData();
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
      ),
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

                  audioPlayer.pause();
                  audioPlayer.seek(Duration(milliseconds: playOffset.value.toInt()));
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
        audioPlayer.pause();
        audioPlayer.seek(Duration(milliseconds: playOffset.value.toInt()));
      },
      onPanUpdate: (details) {
        playOffset.value = startOffset.value + (visibleMiliseconds * details.localPosition.dx / containerWidth);
        audioPlayer.pause();
        audioPlayer.seek(Duration(milliseconds: playOffset.value.toInt()));
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
            _Waveform(),
          ],
        ),
        behavior: HitTestBehavior.translucent,
        onScaleStart: (details) {
          timelineGestureStartPointX = details.localFocalPoint.dx;
        },
        onScaleEnd: (details) {
          setState(() {
            visibleBands = maxVisibleBands;
            scale = futureScale;

            var oldOffset = startOffset;
            startOffset = AnimationController(
                upperBound: lengthInMiliseconds - visibleMiliseconds,
                value: oldOffset.value,
                lowerBound: 0,
                vsync: this,
            );

            // This can be slow at times
            // print("Current Offest: ${startOffset.value}");
            prepareSublist();
          });
          startOffset.animateWith(
             // The bigger the first parameter, the less friction is applied
            FrictionSimulation(0.2, startOffset.value,
              details.velocity.pixelsPerSecond.dx * -1 * milisecondsPerBand// <- Velocity of inertia
            )
          ).then((_) => setState(() => visibleData = getVisibleData() ));



          // if (details.horizontalScale != 1.0)
        },
        onScaleUpdate: (details) {

          setState(() {
            var scrollSpeed = 2;
            var milisecondOffsetValue = (startOffset.value + (timelineGestureStartPointX - details.localFocalPoint.dx) * milisecondsPerBand * scrollSpeed) ;
            if (timelineGestureStartPointX != details.localFocalPoint.dx || startOffset.value != milisecondOffsetValue) {
              timelineGestureStartPointX = details.localFocalPoint.dx;
              // print("VALUE: ${startOffset.value}");
              startOffset.value = milisecondOffsetValue.clamp(0.0, lengthInMiliseconds - visibleMiliseconds);
              prepareSublist();
            }
          }); 


          // print("HHHH scale: ${scale * details.horizontalScale}");
          if (details.horizontalScale != 1.0) {
            setState(() {
              // Scaling:
              futureScale = (scale * details.horizontalScale).clamp(1.0, maxScale);
              visibleBands = (maxVisibleBands * scale / futureScale).toInt();
              visibleBands = min(maxVisibleBands, visibleBands);
              setScrollBarWidth();
            });
          }
        },
      )
    );
  }

  Widget _Waveform() {
    return Container(
      height: 150,
      child: SizedBox.expand(
        child: FractionallySizedBox(
          alignment: timelineContainsEnd ? FractionalOffset.centerRight : FractionalOffset.centerLeft,
          widthFactor: (futureScale / scale).clamp(0.0, 1.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: visibleData.map((value) {
              return _WaveformBand(value);
            }).toList(),
          )
        )
      )
    );
  }

  Widget _WaveformBand(value) {
    double ratio = value / localMaxValue.toDouble();
    double minRatio = localMinValue / localMaxValue.toDouble();
    double visibleMedianRatio = localMedianValue / localMaxValue.toDouble();

    double visibleMinRatio = max(0.01, minRatio);
    double maxRatio = 1;

    ratio = max(ratio, visibleMinRatio);
    double visibleValue = ((ratio - visibleMinRatio) / (maxRatio - visibleMinRatio));


    if (scale < 100)
      visibleValue = pow(visibleValue,  min(pow(visibleMedianRatio / visibleMinRatio, 0.8), 15));


    // The end values are shooting to infinity... seems wrong?

    visibleValue = visibleValue.clamp(0.01, 1.0);

    return Expanded(
      child: FractionallySizedBox(
        heightFactor: visibleValue,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
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
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          var unseenBands = scaledData.length - visibleBands;
          var milisecondsNotVisible = unseenBands * milisecondsPerBand;
          var mmilisecondsNotVisible = lengthInMiliseconds - visibleMiliseconds;

          var offsetValue =  details.delta.dx * milisecondsNotVisible;
          startOffset.value = startOffset.value + (offsetValue/(scrollContainerWidth - scrollbarWidth));
          startOffset.value = startOffset.value.clamp(0.0, milisecondsNotVisible).toDouble();
          prepareSublist();
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
            left: ((containerWidth - scrollContainerWidth)/2 + scrollContainerWidth * bandOffset / scaledData.length).clamp(5.0, max(5.0, containerWidth - scrollbarWidth - 5)),
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
                  visibleBands = (maxVisibleBands * scale / futureScale).toInt();
                  visibleBands = min(maxVisibleBands, visibleBands);
                  setScrollBarWidth();
                });
                computeDataTimer?.cancel();
                computeDataTimer = Timer(Duration(milliseconds: 250), () {
                  setState(() {
                    visibleBands = maxVisibleBands;
                    scale = futureScale;

                    var oldOffset = startOffset;
                    startOffset = AnimationController(
                      upperBound: lengthInMiliseconds - visibleMiliseconds,
                      value: oldOffset.value,
                      lowerBound: 0,
                      vsync: this,
                    );

                    // This can be slow at times
                    prepareSublist();
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


