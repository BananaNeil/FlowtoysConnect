import 'package:app/helpers/duration_helper.dart';
import 'package:app/app_controller.dart';
import 'package:app/models/group.dart';
import 'package:app/models/mode.dart';
import 'dart:math';

class ModeParam {
  DateTime animationStartedAt;
  List<ModeParam> childParams;
  bool multiValueEnabled;
  double _animationSpeed;
  bool hasChildValues;
  String childType;
  String paramName;
  int parentIndex;
  int childIndex;
  num value;
  Mode mode;

  ModeParam({
    this.multiValueEnabled,
    this.hasChildValues,
    this.childParams,
    this.parentIndex,
    this.childIndex,
    this.childType,
    this.paramName,
    animationSpeed,
    this.value,
    this.mode,
  }) {
    _animationSpeed = animationSpeed;
  }

  static final maxAnimationDuration = Duration(seconds: 5);

  set animationSpeed(speed) {
    _animationSpeed = speed;
    startAnimation();
  }
  double get animationSpeed => _animationSpeed ?? 0.0;
  bool get isAnimating => animationSpeed != 0;

  startAnimation() {
    if (isAnimating)
      animationStartedAt = DateTime.now();
  }

  Group get currentGroup =>
    Group.currentGroupAt(groupIndex);

  int get childCount => {
        'prop': currentGroup?.props?.length,
        'group': Group.currentGroups.length,
      }[childType] ?? 0;

  String get nextChildType => {
        'group': 'prop',
      }[childType];

  List<ModeParam> get presentChildParams {
    if (!multiValueEnabled) return [];
    return List.generate(childCount, (index) => childParamAt(index)).toList();
  }

  List<num> get presentChildValues =>
      presentChildParams.map((param) => param.getValue()).toList();

  bool get presentChildValuesAreEqual {
    var values = presentChildValues;

    return values.every((val) => val.toStringAsFixed(2) == values[0].toStringAsFixed(2)) ||
      values.every((val) => val.toStringAsFixed(3) == values[0].toStringAsFixed(3));
  }
  bool get childValuesAreEqual {
    var values = childParams.map((param) => param.value).toList();

    return values.every((val) => val.toStringAsFixed(2) == values[0].toStringAsFixed(2)) ||
      values.every((val) => val.toStringAsFixed(3) == values[0].toStringAsFixed(3));
  }

  void recursivelySetMultiValue() {
    childParams.forEach((param) => param.recursivelySetMultiValue());
    multiValueEnabled = !recurisiveChildValuesAreEqual;
  }

  bool get multiValueActive =>
      multiValueEnabled && (!recurisiveChildValuesAreEqual);

  bool get recurisiveChildValuesAreEqual =>
    childValuesAreEqual && !childParams.map((param) => param.recurisiveChildValuesAreEqual).contains(false)
      && (childParams.isEmpty || childParams.first.value == value);

  bool hasMultiValueChildren() {
    return multiValueEnabled &&
      presentChildParams.firstWhere((child) => child.multiValueActive, orElse: () => null) != null;
  }

  ModeParam newChildParam(index) {
    return ModeParam.fromMap({
        'parentIndex': childIndex,
        'childIndex': index,
        'value': value,
      },
      childType: nextChildType,
      paramName: paramName,
      mode: mode,
    );
  }

  int get groupIndex {
    if (childType == 'group')
      return null;
    else if (childType == 'prop')
      return childIndex;
    else if (childType == null)
      return parentIndex;
  }

  int get propIndex {
    if (childType == null)
      return childIndex;
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
    var counted = childParams.fold({}, (counts, param) {
      counts[param.getValue()] = (counts[param.getValue()] ?? 0) + param.childCount;
      return counts;
    }) as Map<dynamic, dynamic>;

    // Sort the keys (your values) by its occurrences
    final sortedValues = counted.keys
        .toList()
        ..sort((a, b) { return counted[b].compareTo(counted[a]); });

    return sortedValues.first;
  }

  void reverseAnimationSpeed() {
    animationSpeed *= -1;
  }

  num getMultiValueAverage() {
    if (presentChildValues.isEmpty) return 0.5;
    return presentChildValues.reduce((a, b) => a + b) / presentChildValues.length;
  }

  ModeParam childParamAt(int index) {
    while (childParams.length <= index)
      childParams.add(newChildParam(index));
    return childParams[index];
  }

  ModeParam getSiblingParam(paramName) {
    return mode.getParam(paramName, groupIndex: groupIndex, propIndex: propIndex);
  }

  num get animatedValue {
    if (isAnimating) {
      var fullCycleDuration = maxAnimationDuration * (2 / animationSpeed);
      var fullCycleValue = (value + durationRatio(DateTime.now().difference(animationStartedAt), fullCycleDuration)) % 2.0;
      print("FFFFFFF: ${fullCycleDuration} VVVVVV: ${fullCycleValue}");

      if (fullCycleValue > 1.0)
        return 2 - fullCycleValue;
      else return fullCycleValue;
    } else return value;
  }

  num getValue({indexes}) {
    indexes = (indexes ?? [])..removeWhere((index) => index == null);
    if (Group.currentProps.length == 0) return animatedValue;
    if (!multiValueEnabled) return animatedValue;

    if (indexes.length == 0)
      return getMultiValueAverage();

    if (childType == 'prop' && indexes.length == 2)
      indexes.removeAt(0);
    var childParam = presentChildParams[indexes[0]];
    return childParam.getValue(indexes: indexes.sublist(1));
  }

  void setValue(newValue) {
    newValue = num.parse(newValue.toStringAsFixed(3));
    newValue = newValue.clamp(0.0, paramName == 'hue' ? 2.0 : 1.0);
    if (multiValueEnabled) {
      childParams = presentChildParams;
      var delta = newValue - getValue();
      childParams.forEach((param) {
        param.setValue(param.getValue() + delta);
      });
    } else
      value = max(0.0, newValue);
  }

  factory ModeParam.fromModeMap(dynamic data, paramName, mode) {
    return ModeParam.fromMap(data[paramName], childType: 'group', paramName: paramName, mode: mode);
  }

  factory ModeParam.fromMap(dynamic data, {childType, paramName, mode}) {
    Map<String, dynamic> json;

    if (data is num)
      json = {'value': data};
    json = data ?? {};

    var childrenChildType = childType == 'group' ? 'prop' : null;
    List<ModeParam> childParams = List<ModeParam>.from(mapWithIndex(json['childValues'] ?? [], (index, childData) {
      childData['childIndex'] = index;
      childData['parentIndex'] = json['childIndex'];
      return ModeParam.fromMap(childData,
        childType: childrenChildType,
        paramName: paramName,
        mode: mode
      );
    }).toList());

    return ModeParam(
      mode: mode,
      paramName: paramName,
      childType: childType,
      value: json['value'] ?? 0.0,
      childIndex: json['childIndex'],
      parentIndex: json['parentIndex'],
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
      'parentIndex': parentIndex,
      'hasChildValues': hasChildValues,
      'multiValueEnabled': multiValueEnabled,
      'childValues': childParams.map((param) => param.toMap()).toList(),
    };
  }
}
