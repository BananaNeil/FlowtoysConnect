// import 'package:app/models/mode_param.dart';
// import 'package:app/models/base_mode.dart';
// import 'package:app/app_controller.dart';
// import 'package:json_api/document.dart';
// import 'package:app/models/group.dart';
// import 'package:flutter/material.dart';
// import 'package:app/preloader.dart';
// import 'package:app/client.dart';
import 'dart:convert';

class TimelineElement {

  Duration startOffset;
  Duration duration;
  dynamic object;
  // String id;

  TimelineElement({
    this.startOffset,
    this.duration,
    this.object,
    // this.id,
  });

  Duration get endOffset => startOffset + duration;
  Duration get midPoint => startOffset + (duration * 0.5);

  Map<String, dynamic> toMap() {
    return {
      'duration': duration?.inMilliseconds,
      'startOffset': startOffset?.inMilliseconds,
      // 'id': id,
    } as Map;
  }

  factory TimelineElement.fromObject(dynamic object) {
    return TimelineElement(
        object: object,
        duration: object.duration,
        startOffset: object.startOffset
    );
  }

  factory TimelineElement.fromMap(Map<String, dynamic> json) {
    return TimelineElement(
      duration: Duration(milliseconds: json['duration']?.floor() ?? 0),
    );
  }

  factory TimelineElement.fromJson(String body) {
    return TimelineElement.fromMap(jsonDecode(body));
  }

  static List<TimelineElement> fromList(List<dynamic> objects) {
    return objects.map((object) {
      return TimelineElement.fromObject(object);
    }).toList();
  }
}


