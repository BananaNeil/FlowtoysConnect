import 'package:rxdart/rxdart.dart';
import 'dart:async';
import 'dart:math';
// import 'package:flutter/services.dart';
// import 'package:fluttertoast/fluttertoast.dart';
// import 'package:osc/osc.dart';
// import 'package:osc/src/convert.dart';
// import 'package:osc/src/message.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart';
// import 'package:validators/validators.dart';
// import 'package:multicast_dns/multicast_dns.dart';

// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:network_info_plus/network_info_plus.dart';
// import 'package:app/models/sync_packet.dart';
// import 'package:app/models/bridge.dart';
//
// import 'package:quiver/iterables.dart' hide max, min;
import 'package:app/app_controller.dart';
import 'package:mic_stream/mic_stream.dart';

// import 'package:app/native_storage.dart'
//   if (dart.library.html) 'package:app/web_storage.dart';

import 'package:quiver/iterables.dart' hide max, min;
class AudioManager {

  StreamSubscription inputSubscription;
  List<int> currentSamples = [];
  Stream<List<int>> inputStream;
  List<int> maxValues = [];
  List<int> minValues = []; 
  int numOfOutliers = 25;
  int minThreshold = 5;
  int samplesPerSecond;
  int bytesPerSample;

  // Using the fifth to last place here,
  // because we frequently remove the maximum
  // values, and so the last place is not
  // a fair representation of an extremity
  int get localMin => minValues.length < 5 ? 0 : minValues[minValues.length - 5];
  int get localMax => maxValues.length < 5 ? 0 : maxValues[maxValues.length - 5];

  void resetStream() {
    inputSubscription?.cancel();
    inputSubscription = null;
    print("RESSET:");
    sampleCount = 0;
    maxValues = [];
    minValues = []; 
  }

  Future<Stream<List<int>>> startStream() async {
    maxValues = [];
    minValues = []; 
    // if (inputStream != null) return Future.value(inputStream);
    inputStream ??= await MicStream.microphone();
    bytesPerSample = (await MicStream.bitDepth / 8).toInt();
    samplesPerSecond = (await MicStream.sampleRate).toInt();

    inputSubscription ??= inputStream.listen(_calculateIntensity);
  }

  int sampleCount = 0;
  void _calculateIntensity(List<int> samples) {
    int currentSample = 0;
    eachWithIndex(samples, (i, sample) {
      currentSample += sample;
      if ((i % bytesPerSample) == bytesPerSample-1) {
        currentSamples.add(currentSample);
        currentSample = 0;
      }
    });

    if (currentSamples.length >= samplesPerSecond/10) {
      currentSample = currentSamples.reduce((a, b) => a+b);
      sampleCount += 1;
      // visibleSamples.add();
      // localMaxes = max(localMax ?? currentSample, currentSample);
      // localMins = min(localMin ?? currentSample, currentSample);

      if ((minValues.length < numOfOutliers || minValues.last >= currentSample) && currentSample > minThreshold) { 
        minValues.insert(0, currentSample);
        minValues.sort();
        minValues = minValues.sublist(0, min(minValues.length, numOfOutliers));
      }
      if (maxValues.length < numOfOutliers || maxValues.last <= currentSample) {
        maxValues.insert(0, currentSample);
        maxValues.sort();
        maxValues = maxValues.reversed.toList().sublist(0, min(maxValues.length, numOfOutliers));
      }

      if (sampleCount % 50 == 0) {
        minValues.removeAt(0);
        maxValues.removeAt(0);
      }



      currentSamples = [];
      if (minValues.length > numOfOutliers - 5 && localMax != localMin) {
        var adjustedSample = max(0, currentSample - localMin);
        var ratio = min(1.0, pow(adjustedSample / (localMax - localMin), 5));
        // print("(sample: ${currentSample})\t (min: ${localMin})\tSAMPLE: ${adjustedSample}\t/\t(${localMax - localMin})\t =>  ${(ratio * 1000).round() / 1000}");
        intensityController.sink.add(min(1.0, pow(adjustedSample / (localMax - localMin), 5)));
      }
    }
  }

  BehaviorSubject<double> intensityController = BehaviorSubject<double>();
  Stream<double> get intensityStream => intensityController.stream;

}

