import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quiver/iterables.dart' hide max, min;
import 'package:flutter/foundation.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';

import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';

class WaveformController {
  WaveformController({ this.path });
  final String path;

  int index;
  int samplesPerSecond = 44410;
  AssetsAudioPlayer player;
  Duration startOffset = Duration();
  List<num> data = [];
  Duration duration;

  factory WaveformController.open(path) {
    var controller = WaveformController(path: path);
    controller.analyzeSong();
    return controller;
  }

  void analyzeSong() async {
    var song = await loadSong();
      data = song.buffer.asUint8List();
      if (listEquals(data.sublist(0, 4), [82, 73, 70, 70])) {
        var bytesOf32 = song.buffer.asUint32List();
        // print(bytesOf32);
        var fileSize = bytesOf32[1];
        var bitrate = bytesOf32[7];
        samplesPerSecond = bytesOf32[6];
        duration = Duration(milliseconds: (1000.0 * fileSize / bitrate).toInt());
        data = data.sublist(44, data.length);
      } else print("THIS IS NOT A RIFF (wav) FILE");
  }

  int chunkSizeWas;
  Map<int, dynamic> chunkedData = {};

  List<int> chunkedDataFor({bool cache, int chunkSize, int totalChunksForSong}) {
    chunkSize = chunkSize ?? (data.length / totalChunksForSong).toInt().clamp(1, 1000000);

    if (data.length == 0) return [];
    if (chunkSize <= 1.0) return data;

    if (chunkedData[chunkSize] != null)
      return chunkedData[chunkSize];

    print("RECOMPUTING ${startOffset.inSeconds} chunkSize: ${chunkSize} Memory: ${chunkedData.toString().length / 1000000} MB  keys: ${chunkedData.keys.length}");

    var partitionedData = partition(data, chunkSize.clamp(1, data.length));
    chunkedData[chunkSize] = List<int>.from(partitionedData.map((chunk) {
      return (chunk.fold(0, (a, b) => a + b) / chunkSize).toInt();
    }));
    return chunkedData[chunkSize];
  }

  Future<ByteData> loadSong() async {
    return await rootBundle.load(path);
  }
}

class Waveform extends StatefulWidget {
  Waveform({
    @required this.startOffset,
    @required this.controller,
    this.visibleDuration,
    this.visibleBands,
    this.futureScale,
    this.color,
    this.scale,
  });

  final Duration startOffset;
  final Duration visibleDuration;
  final WaveformController controller;
  final double futureScale;
  final double visibleBands;
  final double scale;
  final Color color;

  @override
  State<Waveform> createState() => new _WaveformState();
}

class _WaveformState extends State<Waveform> {
  Duration get startOffset => widget.startOffset;
  double get futureVisibleMiliseconds => visibleMiliseconds * futureScale / scale;
  double get visibleMiliseconds => widget.visibleDuration.inMilliseconds.toDouble();
  double get futureScale => widget.futureScale;
  double get scale => widget.scale;
  Color get color => widget.color;

  WaveformController get controller => widget.controller;

  List<int> get data => controller.data;
  double get visibleBands => widget.visibleBands;
  int get durationInMilliseconds => controller.duration.inMilliseconds;
  double get visibleRatio => (visibleMiliseconds / durationInMilliseconds);
  int get totalChunksForSong => (visibleBands / visibleRatio).ceil();
  int get milisecondsPerBand => (durationInMilliseconds / totalChunksForSong).ceil();
  int get bandOffset => data.length == 0 ? 0 : max(0, (startOffset.inMilliseconds / milisecondsPerBand).toInt());//.clamp(0, scaledData.length - visibleBands);


  int chunkSizeWas;

  int nearVisibleDataStart;
  int nearVisibleDataEnd;

  List<int> nearVisibleData;
  List<int> visibleData;

  int localMedianValue = 1;
  int localMinValue = 1;
  int localMaxValue = 1;

  int globalMedianValue = 1;
  int globalMinValue = 1;
  int globalMaxValue = 1;


  List<int> get scaledData {
    return controller.chunkedDataFor(totalChunksForSong: totalChunksForSong, cache: visibleRatio == 1);
  }

  List<int> getNearVisibleData() {
    if (bandOffset >= scaledData.length) return [];
    if (nearVisibleDataStart != null && bandOffset > nearVisibleDataStart &&
        nearVisibleDataEnd != null  && bandOffset + visibleBands < nearVisibleDataEnd)
      return nearVisibleData;

    nearVisibleDataStart = max(0, bandOffset - visibleBands.ceil());
    nearVisibleDataEnd = min((bandOffset + (visibleBands * 2).ceil()), scaledData.length-1);
    return scaledData.sublist(nearVisibleDataStart, nearVisibleDataEnd);
  }

  List<int> getVisibleData() {

    if (bandOffset >= scaledData.length) return [];
    return scaledData.sublist(bandOffset, (bandOffset + visibleBands.ceil()).clamp(0, scaledData.length-1));
  }

  void setVisibleData() {
    nearVisibleData = getNearVisibleData();
    visibleData = getVisibleData();
    normalizeLocalData();
  }

  void computeOrGetVisibleData() {
    if (visibleData == null)
      prepareVisibleData();
    else setVisibleData();
  }

  void prepareVisibleData() {
    setVisibleData();
    normalizeData();
  }

  void normalizeLocalData() {
    if (scale < 2) return;
    var minimum = 1000000000;
    var maximum = 0;
    var sum = 0;
    nearVisibleData.forEach((value) {
      sum += value;
      if (value < minimum)
        minimum = value;
      if (value > maximum)
        maximum = value;
    });

    localMinValue = minimum.clamp(1, 1000000000);
    localMaxValue = maximum.clamp(1, 1000000000);
    if (nearVisibleData.length > 0)
      localMedianValue = nearVisibleData[(nearVisibleData.length / 2).toInt()];
  }

  void normalizeData() {
    var minimum = 1000000000;
    var maximum = 0;
    var sum = 0;
    scaledData.forEach((value) {
      sum += value;
      if (value < minimum)
        minimum = value;
      if (value > maximum)
        maximum = value;
    });

    globalMinValue = minimum.clamp(1, 1000000000);
    globalMaxValue = maximum.clamp(1, 1000000000);
    if (scaledData.length > 0)
      globalMedianValue = scaledData[(scaledData.length / 2).toInt()];
  }

  @override initState() {
    super.initState();
  }

  double scaleWas; 
  double futureScaleWas; 

  @override
  Widget build(BuildContext context) {
    if (visibleMiliseconds <= 0)
      return Container();

    if (scaleWas != scale)
      prepareVisibleData();

    if (futureScaleWas != futureScale)
      setVisibleData();

    futureScaleWas = futureScale;
    scaleWas = scale;

    computeOrGetVisibleData();
    return  Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: (visibleData ?? []).map((value) {
        return _WaveformBand(value);
      }).toList(),
    );
  }

  Widget _WaveformBand(value) {
    double ratio;
    double minRatio;
    double visibleMedianRatio;


    if (scale >= 2) {
      ratio = value / localMaxValue.toDouble();
      minRatio = localMinValue / localMaxValue.toDouble();
      visibleMedianRatio = localMedianValue / localMaxValue.toDouble();
    } else {
      ratio = value / globalMaxValue.toDouble();
      minRatio = globalMinValue / globalMaxValue.toDouble();
      visibleMedianRatio = globalMedianValue / globalMaxValue.toDouble();
    }

    double visibleMinRatio = max(0.01, minRatio);
    double maxRatio = 1;

    ratio = max(ratio, visibleMinRatio);
    double visibleValue = ((ratio - visibleMinRatio) / (maxRatio - visibleMinRatio));


    if (scale < 100)
      visibleValue = pow(visibleValue,  min(pow(visibleMedianRatio / visibleMinRatio, 0.8), 15));


    visibleValue = visibleValue.clamp(0.01, 0.9);

    return Expanded(
      child: FractionallySizedBox(
        heightFactor: visibleValue,
        child: Container(
          decoration: BoxDecoration(
            color: widget.color ?? Colors.blue,
          )
        )
      )
    );
  }
}
