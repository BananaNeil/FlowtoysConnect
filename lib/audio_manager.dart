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

class AudioManager {

  StreamSubscription inputSubscription;
  List<int> currentSamples = [];
  Stream<List<int>> inputStream;
  int samplesPerSecond;
  int bytesPerSample;
  int localMax;
  int localMin; 

  void resetStream() {
    localMax = null;
    localMin = null; 
  }

  Future<Stream<List<int>>> startStream() async {
    localMax = null;
    localMin = null; 
    if (inputStream != null) return Future.value(inputStream);
    inputStream ??= await MicStream.microphone();
    bytesPerSample = (await MicStream.bitDepth / 8).toInt();
    samplesPerSecond = (await MicStream.sampleRate).toInt();

    inputSubscription = inputStream.listen(_calculateIntensity);
  }

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
      // visibleSamples.add();
      localMax = max(localMax ?? currentSample, currentSample);
      localMin = min(localMin ?? currentSample, currentSample);
      currentSamples = [];
      if (localMax != localMin)
        intensityController.sink.add(pow((localMax - currentSample) / (localMax - localMin), 5));
    }
  }

  BehaviorSubject<double> intensityController = BehaviorSubject<double>();
  Stream<double> get intensityStream => intensityController.stream;

}

