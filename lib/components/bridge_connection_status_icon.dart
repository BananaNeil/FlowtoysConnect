import 'package:app/components/bridge_connection_status.dart';
import 'package:app/components/connection_icon.dart';
import 'package:app/components/edit_groups.dart';
import 'package:app/app_controller.dart';
import 'package:app/models/bridge.dart';
import 'package:flutter/material.dart';
import 'package:app/models/group.dart';
import 'package:app/models/prop.dart';
import 'package:badges/badges.dart';
import 'dart:async';

class BridgeConnectionStatusIcon extends StatefulWidget {
  BridgeConnectionStatusIcon();

  @override
  _BridgeConnectionStatusIcon createState() => _BridgeConnectionStatusIcon();
}

class _BridgeConnectionStatusIcon extends State<BridgeConnectionStatusIcon> {
  _BridgeConnectionStatusIcon();

  bool get isConnected => bleConnected || oscConnected;
  bool get bleConnected => Bridge.bleManager.isConnected;
  bool get oscConnected => Bridge.oscManager.isConnected;
  String get currentWifiNetworkName => Bridge.oscManager.currentWifiNetworkName;

  StreamSubscription propStateSubscription;
  StreamSubscription stateSubscription;
  int unseenItemCount = 0;

  @override
  initState() {
    super.initState();
    propStateSubscription = Prop.propUpdateStream.listen(_updateUnseenItems);
    stateSubscription = Bridge.stateStream.listen(_updateUnseenItems);
  }

  void _updateUnseenItems(_) {
    print("icon Checking connectionState: ${seenState.toString()} == ${connectionState.toString()} ${seenState.toString() == connectionState.toString()}");
    if (seenState.toString() == connectionState.toString()) return;
    if (!isConnected) seenState = connectionState;

    unseenItemCount = 0;
    if (!oscConnected && bleConnected)
      unseenItemCount += 1;

    if (isConnected && Bridge.isUnclaimed)
      unseenItemCount += 1;

    if (isConnected && Prop.unclaimedProps.length > 0)
      unseenItemCount += 1;

    setState(() {});
  }

  @override
  dispose() {
    propStateSubscription?.cancel();
    stateSubscription?.cancel();
    super.dispose();
  }

  List<dynamic> get connectionState => [isConnected, bleConnected, oscConnected, Bridge.isUnclaimed, currentWifiNetworkName, Prop.unclaimedProps.length];
  List<dynamic> seenState;

  @override
  Widget build(BuildContext context) {
    print("================+++++++ ${connectionState.toString() == seenState.toString()}");
    print("================+++++++C ${connectionState}");
    print("================+++++++S ${seenState}");

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            setState(() => unseenItemCount = 0);
            seenState = connectionState;
            openBridgeDetails();
          },
          child: Badge(
            elevation: 3.0,
            showBadge: unseenItemCount > 0,
            badgeContent: Container(
                padding: EdgeInsets.only(left: 1, bottom: 2, right: 1),
              child: Text('${unseenItemCount}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            badgeColor: Colors.red.withOpacity(0.7),
            child: ConnectionIcon(
              isConnected: isConnected,
              connectedIcon: Image(image: AssetImage('assets/images/bridge-connected.png')),
              disconnectedIcon: Image(image: AssetImage('assets/images/bridge-disconnected.png')),
            )
          ),
        ),
        Container(
            margin: EdgeInsets.only(right: 5),
        ),
        _EditGroupButton(),
        Container(
            margin: EdgeInsets.only(right: 5),
        )
      ]
    );
  }

  Widget _editGroupsWidget() {
    return Container(
      width: 300,
      height: 500,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      child: EditGroups(),
    );
  }

  Widget _EditGroupButton() {
    var propCount = Group.currentQuickGroup.props.length;

    return GestureDetector(
      onTap: () {
        showDialog(context: context,
          builder: (context) => Dialog(
            child: _editGroupsWidget(),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
          )
        ).then((_) { setState(() {}); });
      },
      child: Group.connectedGroups.length == 0 ? Container() : Badge(
        badgeContent: Text(Group.connectedGroups.length.toString(), style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontSize: 11,
              )),
        position: BadgePosition.topEnd(top: 6, end: 6),
        badgeColor: Colors.white,
        // badgeContent: Group.unseenGroups.length == 0 ? null :
        //   Text(Group.unseenGroups.length.toString()),
        child: Container(
          padding: EdgeInsets.all(15),
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcATop),
            child: Image(image: AssetImage('assets/images/cube.png')),
          ),
          // child: Group.possibleGroups.length == 0 ? null : Icon(
          //     propCount <= 0 ? Icons.warning : {
          //       1: Icons.filter_1,
          //       2: Icons.filter_2,
          //       3: Icons.filter_3,
          //       4: Icons.filter_4,
          //       5: Icons.filter_5,
          //       6: Icons.filter_6,
          //       7: Icons.filter_7,
          //       8: Icons.filter_8,
          //     }[propCount] ?? Icons.filter_9_plus,
          //     size: 24,
          ),
        ),
      // ),
    );
  }
}

