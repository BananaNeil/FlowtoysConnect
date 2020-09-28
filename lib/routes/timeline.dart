import 'package:flutter_hsvcolor_picker/flutter_hsvcolor_picker.dart';
import 'package:app/models/mode_list.dart';
import 'package:app/app_controller.dart';
import 'package:quiver/iterables.dart' hide max, min;
import 'package:flutter/material.dart';
import 'package:app/models/mode.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/foundation.dart';



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

class _TimelinePageState extends State<TimelinePage> with SingleTickerProviderStateMixin {
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
  double localMeanValue = 1;
  AnimationController startOffset;

  @override initState() {
    visibleBands = maxVisibleBands;
    super.initState();
    loadFile();
    startOffset = AnimationController.unbounded(vsync: this);
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
  // double get lengthInMiliseconds => lengthInSeconds / 1000.0;
  // double get visibleMiliseconds => (lengthInMiliseconds * scale);
  // double get bandsPerVisibleMiliseconds => visibleBands / visibleMiliseconds;
  //
  // int get bandOffset => (startOffset.value / bandsPerVisibleMilisecond).toInt().clamp(0, scaledData.length - visibleBands);




  int get bandOffset => data.length == 0 ? 0 : startOffset.value.toInt().clamp(0, scaledData.length - visibleBands);
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
    print("CHUNK: ${chunkSize}");

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

    // use this package to play it: https://pub.dev/packages/just_audio
    var song = await loadSong();
    setState(() {
      data = song.buffer.asUint8List();
      if (listEquals(data.sublist(0, 4), [82, 73, 70, 70])) {
        var bytesOf32 = song.buffer.asUint32List();
        print(bytesOf32);
        var fileSize = bytesOf32[2];
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

  double get scrollContainerWidth => containerWidth - 4;

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
    localMeanValue = sum / visibleData.length;
    setScrollBarWidth();
    return visibleData;
  }

  void setScrollBarWidth() {
    scrollbarWidth = (scrollContainerWidth / futureScale).clamp(10, scrollContainerWidth).toDouble();
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
              width: 6,
            )
          ),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints box) {
              containerWidth = box.maxWidth;
              // Timeline:
              if (data.length == 0)
                return Container();
              return AnimatedBuilder(
                animation: startOffset,
                builder: (ctx, w) {
                  visibleData = visibleData ?? prepareSublist();
                  visibleData = getVisibleData();
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _Timestamps(),
                      _TimelineViewer(),
                      _ScrollBar(),
                      _ScaleSlider(),
                    ],
                  );
                }
              );
            }
          )
        )
      ),
    );
  }

  Widget _Timestamps() {
    return Row(
      children: [
        Text("0 sec"),
      ],
    );
  }

  double timelineGestureStartPointX;

  Widget _TimelineViewer() {
    return GestureDetector(
      child: _Waveform(),
      behavior: HitTestBehavior.translucent,
      onScaleStart: (details) {
        timelineGestureStartPointX = details.localFocalPoint.dx;
        // _baseScaleFactor = _scaleFactor;
      },
      onScaleEnd: (details) {
        setState(() {
          visibleBands = maxVisibleBands;
          startOffset.value = startOffset.value * (futureScale / scale);
          scale = futureScale;

          // This can be slow at times
          // print("Current Offest: ${startOffset.value}");
          prepareSublist();
        });
        startOffset.animateWith(
           // The bigger the first parameter, the less friction is applied
          FrictionSimulation(0.2, startOffset.value,
            details.velocity.pixelsPerSecond.dx * -2 // <- Velocity of inertia
          )
        ).then((_) => setState(() => visibleData = getVisibleData() ));



        // if (details.horizontalScale != 1.0)
      },
      onScaleUpdate: (details) {

        setState(() {
          var offsetValue = (bandOffset + (timelineGestureStartPointX - details.localFocalPoint.dx) * 2);
          if (timelineGestureStartPointX != details.localFocalPoint.dx || startOffset.value != offsetValue) {
            timelineGestureStartPointX = details.localFocalPoint.dx;
            // print("VALUE: ${startOffset.value}");
            startOffset.value = offsetValue;
            prepareSublist();
          }
        }); 


        if (details.horizontalScale != 1.0) {
          setState(() {
            // Scaling:
            futureScale = (futureScale *  pow(details.horizontalScale, 0.2)).clamp(1.0, maxScale);
            visibleBands = (maxVisibleBands * scale / futureScale).toInt();
            visibleBands = min(maxVisibleBands, visibleBands);
            setScrollBarWidth();
          });
          // The following is duplicated below
          // computeDataTimer?.cancel();
          // computeDataTimer = Timer(Duration(milliseconds: 250), () {
          //   setState(() {
          //     visibleBands = maxVisibleBands;
          //     startOffset.value = startOffset.value * (futureScale / scale);
          //     scale = futureScale;
          //
          //     // This can be slow at times
          //     // print("Current Offest: ${startOffset.value}");
          //     prepareSublist();
          //   });
          // });
        }
      },
      // onPanUpdate: (details) {
      //     print("Focal Point: ${details.delta.dx}");
      // }
      //   setState(() {
      //     var offsetValue = (bandOffset - details.delta.dx * 2);
      //     startOffset.value = offsetValue;
      //     prepareSublist();
      //   });
      // },
      // onPanEnd: (details) {
      //   print("PX PER SEC ${details.velocity.pixelsPerSecond.dx * -2}"); 
      //   startOffset.animateWith(
      //      // The bigger the first parameter, the less friction is applied
      //     FrictionSimulation(0.2, startOffset.value,
      //       details.velocity.pixelsPerSecond.dx * -2 // <- Velocity of inertia
      //     )
      //   ).then((_) => setState(() => visibleData = getVisibleData()));
      // },
    );
  }

  Widget _Waveform() {
    return Container(
      height: 150,
      child: FractionallySizedBox(
        widthFactor: (futureScale / scale).clamp(0.0, 1.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: visibleData.map((value) {
            return _WaveformBand(value);
          }).toList(),
        )
      )
    );
  }

  Widget _WaveformBand(value) {
    double ratio = value / localMaxValue.toDouble();
    double minRatio = localMinValue / localMaxValue.toDouble();
    double visibleMeanRatio = localMeanValue / localMaxValue.toDouble();;

    double visibleMinRatio = max(0.01, minRatio);
    double maxRatio = 1;

    ratio = max(ratio, visibleMinRatio);
    double visibleValue = ((ratio - visibleMinRatio) / (maxRatio - visibleMinRatio));


    if (scale < 100)
      visibleValue = pow(visibleValue,  pow(visibleMeanRatio / visibleMinRatio, 0.6));


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

  Widget _ScrollBar() {
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          var offsetValue =  details.delta.dx * (scaledData.length - visibleBands);
          startOffset.value = (startOffset.value + (offsetValue/(scrollContainerWidth - scrollbarWidth))).clamp(0.0, scaledData.length - visibleBands).toDouble();
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
            left: (2 + scrollContainerWidth * bandOffset / scaledData.length).clamp(0.0, containerWidth - scrollbarWidth),
            child: Container(
              width: scrollbarWidth,
              height: 16,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Color(0xFF333333),
              )
            )
          )
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
                    startOffset.value = startOffset.value * (futureScale / scale);
                    scale = futureScale;
                    
                    // This can be slow at times
                    print("Current Offest: ${startOffset.value}");
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


