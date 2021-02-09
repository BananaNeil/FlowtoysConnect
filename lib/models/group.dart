import 'package:app/models/bridge.dart';
import 'package:app/models/prop.dart';
import 'package:app/models/mode.dart';
import 'dart:async';

class Group {
  static List<Group> _quickGroups;

  List<Prop> props;
  String name;
  String id;

  Group({
    this.id,
    this.name,
    this.props,
  });

  static Group _currentQuickGroup;
  static Group get currentQuickGroup => _currentQuickGroup ?? quickGroups.first;
  static void set currentQuickGroup (group) => _currentQuickGroup = group;

  static List<Group> get quickGroups {
    if (_quickGroups != null) return _quickGroups;

    _quickGroups = List.generate(5, (index) {
      return Group(
        id: "QG-${index}",
        name: "Quick Group ${index}",
        props: index == 0 ? connectedProps : [],
      );
    });
    return _quickGroups;
  }

  static void setCurrentProps(mode) {
    currentGroups.forEach((group) => group.currentMode = mode );
  }

  Timer animationUpdater;
  Mode _currentMode;
  Mode get currentMode {
    if (props.any((prop) => prop.currentModeId != props.first.currentModeId))
      return null;
    return _currentMode;
  }

  void set currentMode(mode) {
    _currentMode = mode;
    animationUpdater?.cancel();
    if (mode.isMultivalue)
      return props.forEach((prop) => prop.currentMode = mode);
    else
      props.forEach((prop) => prop.internalMode = mode);

    if (mode.isAnimating)
      animationUpdater = Timer.periodic(Duration(milliseconds: 100), (_) {
        this.currentMode = _currentMode;
      });
    Bridge.setGroup(
      groupId: 0,
      page: currentMode.page,
      number: currentMode.number,
      params: props.first.currentModeParamValues, 
    );
  }

  static List<Prop> get connectedProps {
    return connectedGroups.map((group) => group.props).expand((g) => g).toList();
  }

  static List<Prop> get currentProps {
    return currentGroups.map((group) => group.props).expand((g) => g).toList();
  }

  static Group currentGroupAt(index) {
    if ((currentGroups ?? []).length > 0 && index != null)
      return currentGroups[index % currentGroups.length];
  }

  static List<Group> get currentGroups {
    // I think this can be cached:
    var currentPropIds = currentQuickGroup.propIds;
    var groups = connectedGroups.map((group) {
      return Group(
        id: group.id,
        name: group.name,
        props: group.props.where((prop) {
          return currentPropIds.contains(prop.id);
        }).toList()
      );
    }).toList();
    groups.removeWhere((group) => group.props.isEmpty);
    return groups;
  }

  static List<Group> get connectedGroups => possibleGroups;

  static List<Group> _possibleGroups;
  static List<Group> get possibleGroups {
    return _possibleGroups ??= [
      Group(
          id: "1",
          name: "Neil's Clubs",
          props: List.generate(3, (index) => Prop(id: index.toString(), index: index, groupIndex: 0)),
      ),
      // Group(
      //     id: "2",
      //     name: "Ben's Clubs",
      //     props: List.generate(2, (index) => Prop(id: (200 + index).toString(), index: index, groupIndex: 1)),
      // ),
      // Group(
      //     id: "3",
      //     name: "Seans's Props",
      //     props: List.generate(8, (index) => Prop(id: (300 + index).toString(), index: index, groupIndex: 2)),
      // ),
      // Group(
      //     id: "4",
      //     name: "G's Props",
      //     props: List.generate(4, (index) => Prop(id: (400 + index).toString(), index: index, groupIndex: 3)),
      // ),
    ];
  }

  List<String> get propIds => props.map((prop) => prop.id).toList();

}
