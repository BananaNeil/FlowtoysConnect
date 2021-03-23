import 'package:rxdart/rxdart.dart';
import 'dart:async';

class FilterController {
  BehaviorSubject<Map<String, dynamic>> streamController = BehaviorSubject<Map<String, dynamic>>();
  Map<dynamic, dynamic> filters = {};
  StreamSink get sink => streamController.sink;
  Stream get stream => streamController.stream;

  bool isOn = false;

  bool get filtersArePresent => filters.values.any((value) => value != null && value.length > 0);
  bool get filtersAreBlank => !filtersArePresent;

  void setFilters(newFilters) {
    filters = newFilters;
    isOn = filtersArePresent;
    sink.add(newFilters);
  }

  void off() {
    isOn = false;
    sink.add(Map<String, dynamic>());
  }

  void on() {
    isOn = true;
    sink.add(filters);
  }

}

