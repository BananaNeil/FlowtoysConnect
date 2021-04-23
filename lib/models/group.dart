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
  String groupId;

  Group({
    name,
    this.groupId,
    this.props,
  }) {
    this.name = name;
  }

  static Group _currentQuickGroup;
  static Group get currentQuickGroup => _currentQuickGroup ?? quickGroups.first;
  static void set currentQuickGroup (group) => _currentQuickGroup = group;

  static String unclaimedName = "Unclaimed Group";

  String get name {
    if (_name != null) return _name;
    return unclaimedName;
  }

  String get nameWithCount {
    if (props.length > 1)
      return name + " (${props.length})";
    else return name;
  }

  void set name(name) => _name = name;

  static List<Group> get quickGroups {
    if (_quickGroups != null) return _quickGroups;

    _quickGroups = List.generate(5, (index) {
      return Group(
        groupId: "QG-${index}",
        name: "Quick Group ${index}",
        props: index == 0 ? connectedProps : [],
      );
    });
    return _quickGroups;
  }

  static void setCurrentProps(mode) {
    currentGroups.forEach((group) => group.currentMode = mode );
  }

  static Map<String, Timer> animationUpdaters = {};
  Mode _currentMode;
  Mode get currentMode {
    // if (props.any((prop) => prop.currentModeId != props.first.currentModeId))
    //   return null;
    return _currentMode;
  }

  DateTime _currentModeSetAt;
  Mode get internalMode => currentMode;
  void set internalMode(mode) {
    _currentMode = mode;
    props.forEach((prop) => prop.internalMode = mode);
  }
  void set currentMode(mode) {
    if (props.length == 0) return;
    _currentMode = mode;
    animationUpdaters[groupId]?.cancel();

    // at the moment, props can only enter adjustRandomized if currently adjusting.
    //
    // To simulate the randomize effect on the props we are randomizing
    // the adjust value in the Prop.currentMode=  method to work
    // with the new props (via 1 BLE->radio call per prop)
    if (mode.isMultivalue || (mode.adjustRandomized && !mode.adjusting))
      return props.forEach((prop) => prop.currentMode = mode);
    else
      props.forEach((prop) => prop.internalMode = mode);

    if (mode.isAnimating)
      animationUpdaters[groupId] = Timer(Bridge.animationDelay * 1.02, () {
        this.currentMode = _currentMode;
      });

    // print("AD.USTED params: ${props.first.adjustedModeParamValues}");
    if (_currentModeSetAt == null || DateTime.now().difference(_currentModeSetAt) > Bridge.animationDelay) {
      _currentModeSetAt = DateTime.now();
      currentGroups.forEach((group) {
        Bridge.setGroup(
          groupId: group.groupId,
          page: currentMode.page,
          number: currentMode.number,
          params: props.first.adjustedModeParamValues, 
        );
      });
    }
  }

  bool _isCyclingPage;
  bool get isCyclingPage => _isCyclingPage;
  void set isCyclingPage (value) {
    props.forEach((prop) => prop.isCyclingPage = value);
    _isCyclingPage = value;
  }

  bool _isCheckingBattery;
  bool get isCheckingBattery => _isCheckingBattery;
  void set isCheckingBattery(value) {
    props.forEach((prop) => prop.isCheckingBattery = value);
    _isCheckingBattery = value;
    if (value == true)
      Timer(Duration(seconds: 4), () {
        isCheckingBattery = false;
      });
  }


  bool possiblyOn = false;
  bool _isOn = true;
  bool get isOn => _isOn;
  void set isOn(value) {
    _isOn = value;
    if (value == false) possiblyOn = false;
    props.forEach((prop) => prop.isOn = value);
  }


  static List<Prop> get possibleProps {
    return possibleGroups.map((group) => group.props).expand((g) => g).toList();
  }

  static List<Group> get unclaimedGroups {
    return connectedGroups.where((group) {
      return group.props.any((prop) => prop.userId == null);
    }).toList();
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
        groupId: group.groupId,
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
    Set<String> userPropIds = Authentication.currentAccount?.connectedPropIds ?? Set<String>();
    // print("THIIS: ${userPropIds}");
    return Bridge.isConnected && group.props.any((prop) => userPropIds.contains(prop.id));
  }).toList();

  static Group findOrInitializeById(String groupId) {
    return possibleGroups.firstWhere((group) => group.groupId == groupId, orElse: () {
      return Group(
        groupId: groupId,
        props: [],
      );
    });
  }

  static Group findOrCreateById(String groupId) {
    print("FIND OR CREATE group BY ID ${groupId}");
    return possibleGroups.firstWhere((group) => group.groupId == groupId, orElse: () {
      Group newGroup = Group(
        groupId: groupId,
        props: [],
      );
      possibleGroups.add(newGroup);
      newGroup.addVirtualProp();

			var propIds = newGroup.props.map((prop) => prop.uid).toList();
      Client.fetchProps(propIds).then((response) {
        if (response['success'])
          response['body']['data'].forEach((data) {
            Prop prop = newGroup.props.firstWhere((prop) => prop.id == data['id'], orElse: () {
              return Prop.fromMap(data);
            });
            prop.setAttributes(data['attributes']);
          });
      });


      print("ADDED NEW POSSIBLE GROUP: ${Authentication.currentAccount.propIds} CONTAINS????? ${newGroup.props.first.id}");
      if (Authentication.currentAccount.propIds.contains(newGroup.props.first.id)) {
        currentQuickGroup.props.add(newGroup.props.first); 
      } else {
        unseenGroups.add(newGroup);
        Bridge.changeStream.add(null);
      }
      return newGroup;
    });
  }

  bool get hasVirtualProps => virtualProps.length > 1; 
  List<Prop> get virtualProps => props.where((prop) => prop.virtual == true).toList();

  void addVirtualProp() {
    String userId = props.length > 0 ? props.first.userId : null;
    var prop = Prop(id: "${groupId}-${props.length + 1}", groupId: groupId, virtual: true, userId: userId);
    props.add(prop);
  }

  void removeVirtualProp() {
    if (hasVirtualProps)
      props.remove(virtualProps.first);
  }

  static List<String> savedGroupIds = [];
  static List<Group> unseenGroups = [];

  static List<Group> get unconnectedGroups => unconnected;

  static List<Group> get unconnected => possibleGroups.where((group) => !Group.connectedGroups.contains(group)).toList();
  static List<Group> get connected => connectedGroups;
  static List<Group> get possible => possibleGroups;
  static List<Group> get current => currentGroups;

  static List<Group> _possibleGroups;
  static List<Group> get possibleGroups {
    return _possibleGroups ??= [
      // Group(
      //     id: "1",
      //     name: "Neil's Clubs",
      //     props: List.generate(1, (index) => Prop(id: index.toString(), groupId: '1', index: index, groupIndex: 0)),
      // ),
      // Group(
      //     id: "2",
      //     name: "Ben's Clubs",
      //     props: List.generate(1, (index) => Prop(id: (200 + index).toString(), groupId: '2', index: index, groupIndex: 1)),
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
