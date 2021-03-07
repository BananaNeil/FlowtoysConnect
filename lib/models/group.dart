import 'package:app/authentication.dart';
import 'package:app/models/bridge.dart';
import 'package:app/models/prop.dart';
import 'package:app/models/mode.dart';
import 'package:app/client.dart';
import 'dart:async';


import 'package:app/native_storage.dart'
  if (dart.library.html) 'package:app/web_storage.dart';

class Group {
  static List<Group> _quickGroups;

  List<Prop> props;
  String _name;
  String id;

  Group({
    name,
    this.id,
    this.props,
  }) {
    this.name = name;
  }

  static Group _currentQuickGroup;
  static Group get currentQuickGroup => _currentQuickGroup ?? quickGroups.first;
  static void set currentQuickGroup (group) => _currentQuickGroup = group;

  String get name => _name ?? "Unclaimed Group (${props.length})";
  void set name(name) => _name = name;

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
    print("GROUP.currentMode = ");
    if (props.any((prop) => prop.currentModeId != props.first.currentModeId))
      return null;
    return _currentMode;
  }

  Mode get internalMode => currentMode;
  void set internalMode(mode) {
    _currentMode = mode;
    props.forEach((prop) => prop.internalMode = mode);
  }
  void set currentMode(mode) {
    if (props.length == 0) return;
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
    currentGroups.forEach((group) {
      Bridge.setGroup(
        groupId: group.id,
        page: currentMode.page,
        number: currentMode.number,
        params: props.first.adjustedModeParamValues, 
      );
    });
  }

  static List<Prop> get possibleProps {
    return possibleGroups.map((group) => group.props).expand((g) => g).toList();
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

  static List<Group> get connectedGroups => possibleGroups.where((group) {
    List<String> userPropIds = Authentication.currentAccount.propIds ?? [];
    return group.props.any((prop) => userPropIds.contains(prop.id));
  }).toList();

  static Group findOrCreateById(String groupId) {
    return possibleGroups.firstWhere((group) => group.id == groupId, orElse: () {
      var prop = Prop(id: "${groupId}-${1}", groupId: groupId);
      var props = [prop];
      Group newGroup = Group(
        id: groupId,
        props: props,
      );

      Client.fetchProps(props).then((response) {
        if (response['success'])
          response['body']['props'].forEach((data) {
            Prop prop = props.firstWhere((prop) => prop.uid == data['uid'], orElse: () {});
            prop.setAttributes(data);
          });
      });


      possibleGroups.add(newGroup);
      if (savedGroupIds.contains(groupId)) {
        currentQuickGroup.props.add(prop); 
      } else {
        unseenGroups.add(newGroup);
      }
      return newGroup;
    });
  }

  static List<String> savedGroupIds = [];
  static List<Group> unseenGroups = [];

  static List<Group> get unclaimedGroups => possibleGroups.where((group) => !Group.connectedGroups.contains(group)).toList();

  static List<Group> _possibleGroups;
  static List<Group> get possibleGroups {
    return _possibleGroups ??= [
      // Group(
      //     id: "1",
      //     name: "Neil's Clubs",
      //     props: List.generate(3, (index) => Prop(id: index.toString(), groupId: '1', index: index, groupIndex: 0)),
      // ),
      // Group(
      //     id: "2",
      //     name: "Ben's Clubs",
      //     props: List.generate(2, (index) => Prop(id: (200 + index).toString(), groupId: '2', index: index, groupIndex: 1)),
      // ),
      // Group(
      //     id: "3",
      //     name: "Seans's Props",
      //     props: List.generate(8, (index) => Prop(id: (300 + index).toString(), groupId: '3', index: index, groupIndex: 2)),
      // ),
      // Group(
      //     id: "4",
      //     name: "G's Props",
      //     props: List.generate(4, (index) => Prop(id: (400 + index).toString(), groupId: '4', index: index, groupIndex: 3)),
      // ),
    ];
  }

  List<String> get propIds => props.map((prop) => prop.id).toList();

}
