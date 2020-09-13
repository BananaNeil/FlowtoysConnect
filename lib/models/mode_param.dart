import 'package:app/models/group.dart';
import 'package:app/app_controller.dart';
import 'dart:math';

class ModeParam {
  List<ModeParam> childParams;
  bool multiValueEnabled;
  bool hasChildValues;
  String childType;
  int childIndex;
  num value;

  ModeParam({
    this.multiValueEnabled,
    this.hasChildValues,
    this.childParams,
    this.childIndex,
    this.childType,
    this.value,
  });

  Group get currentGroup =>
      Group.currentGroupAt(childIndex);

  int get presentChildCount => {
        'prop': currentGroup?.props?.length,
        'group': Group.currentGroups.length,
      }[childType] ?? 0;

  String get nextChildType => {
        'group': 'prop',
      }[childType];

  List<ModeParam> get presentChildParams {
      return List.generate(presentChildCount, (index) => childParamAt(index)).toList();
  }

  List<num> get presentChildValues =>
      presentChildParams.map((param) => param.getValue()).toList();

  bool get presentChildValuesAreEqual {
    var values = presentChildValues;

    return values.every((val) => val.toStringAsFixed(2) == values[0].toStringAsFixed(2)) ||
      values.every((val) => val.toStringAsFixed(3) == values[0].toStringAsFixed(3));
  }

  bool get multiValueActive =>
      multiValueEnabled && (!presentChildValuesAreEqual || presentChildParams.map((param) => param.presentChildValuesAreEqual).contains(false));

  bool hasMultiValueChildren() {
    return multiValueEnabled &&
      presentChildParams.firstWhere((child) => child.multiValueActive, orElse: () => null) != null;
  }

  ModeParam newChildParam(index) {
    return ModeParam.fromMap({
      'childIndex': index,
      'value': value,
    }, childType: nextChildType);
  }

  void toggleMultiValue() {
    multiValueEnabled = !multiValueEnabled;
    if (!hasChildValues) {
      hasChildValues = true;
      setValue(value);
    }

    if (!multiValueEnabled)
      setValue(mostCommonChildValue);
  }

  num get mostCommonChildValue {
    var counted = presentChildParams.fold({}, (counts, param) {
      counts[param.getValue()] = (counts[param.getValue()] ?? 0) + param.presentChildCount;
      return counts;
    }) as Map<dynamic, dynamic>;

    // Sort the keys (your values) by its occurrences
    final sortedValues = counted.keys
        .toList()
        ..sort((a, b) { print("${b} -- ${a}"); return counted[b].compareTo(counted[a]); });

    return sortedValues.first;
  }

  num getMultiValueAverage() {
    return presentChildValues.reduce((a, b) => a + b) / presentChildValues.length;
  }

  ModeParam childParamAt(int index) {
    while (childParams.length <= index)
      childParams.add(newChildParam(index));
    return childParams[index];
  }

  num getValue({indexes}) {
    indexes = (indexes ?? [])..removeWhere((index) => index == null);
    if (!multiValueEnabled) return value;

    if (indexes.length == 0)
      return getMultiValueAverage();

    var childParam = presentChildParams[indexes[0]];
    return childParam.getValue(indexes: indexes.sublist(1));
  }

  void setValue(newValue) {
    newValue = num.parse(newValue.toStringAsFixed(3));
    childParams = presentChildParams;
    if (multiValueEnabled) {
      var delta = newValue - getValue();
      childParams.forEach((param) {
        param.setValue(param.getValue() + delta);
      });
    } else
      value = max(0.0, min(newValue, 1.0));
  }

  factory ModeParam.fromMap(dynamic data, {childType}) {
    Map<String, dynamic> json;

    if (data is num)
      json = {'value': data};
    json = data ?? {};

    List<ModeParam> childParams = List<ModeParam>.from(mapWithIndex(json['childValues'] ?? [], (index, childData) {
      return ModeParam.fromMap(childData, childType: 'prop') ..childIndex = index;
    }).toList());

    return ModeParam(
      childType: childType,
      value: json['value'] ?? 0.0,
      childIndex: json['childIndex'],
      hasChildValues: json['hasChildValues'] ?? false,
      multiValueEnabled: json['multiValueEnabled'] ?? false,
      childParams: childParams ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'value': value,
      'childType': childType,
      'childIndex': childIndex,
      'hasChildValues': hasChildValues,
      'multiValueEnabled': multiValueEnabled,
      'childValues': childParams.map((param) => param.toMap()).toList(),
    };
  }
}
