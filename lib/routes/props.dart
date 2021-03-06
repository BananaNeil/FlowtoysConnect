import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flash_animation/flash_animation.dart';
import 'package:app/components/mode_widget.dart';
import 'package:app/components/edit_groups.dart';
import 'package:app/components/navigation.dart';
import 'package:app/app_controller.dart';
import 'package:app/authentication.dart';
import 'package:app/models/bridge.dart';
import 'package:flutter/material.dart';
import 'package:app/models/group.dart';
import 'package:app/models/prop.dart';
import 'package:app/models/mode.dart';
import 'package:app/client.dart';
import 'dart:async';

class Props extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PropsPage(title: 'Props');
  }
}

class PropsPage extends StatefulWidget {
  PropsPage({Key key, this.title}) : super(key: key);
  String title;

  @override
  _PropsPageState createState() => _PropsPageState();
}

class _PropsPageState extends State<PropsPage> with TickerProviderStateMixin {

  StreamSubscription currentModeSubscription;
  bool awaitingResponse = false;
  bool isTopLevelRoute;
  String errorMessage;


  @override initState() {
    super.initState();
    isTopLevelRoute = !Navigator.canPop(context);
    currentModeSubscription = Prop.propUpdateStream.listen((Prop prop) {
      Mode mode = prop.currentMode;
      if (mode?.page == 5 && mode?.number == 1) {
        Authentication.currentAccount.propIds ??= [];
        Authentication.currentAccount.propIds.add(prop.id);
        Group.currentQuickGroup.props.add(prop); 
      }
      setState(() {});
    });
  }

  @override
  dispose() {
    currentModeSubscription.cancel();
    super.dispose(); 
  }

  List<String> _expandedGroupIds = [];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: AppController.closeKeyboard,
      child: Scaffold(
      drawer: isTopLevelRoute ? Navigation() : null,
        appBar: AppBar(
          title: Text("Connect Props"),
          backgroundColor: Color(0xff222222),
        ),
        body: Center(
          child: Container(
                  constraints: BoxConstraints(minWidth: 0, maxWidth: 540),
            margin: EdgeInsets.all(AppController.scaleViaWidth(20)),
            child: Column(
              children: [
                Text("Put your props into Page 5 to claim:",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppController.scaleViaWidth(22, minValue: 15, maxValue: 28),
                  )
                ),
                Container(
                  margin: EdgeInsets.only(top: 2, bottom: 20, left: 20, right: 20,),
                  child: Text("Get to page 5 by quickly pressing a prop button 5 times. When successful, you'll see 5 flashes.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: AppController.scaleViaWidth(16, minValue: 13, maxValue: 19),
                    )
                  ),
                ),
                Text("Your Props:",
                  style: TextStyle(
                    fontSize: AppController.scaleViaWidth(16, minValue: 15, maxValue: 18),
                  )
                ),
                ..._ConnectedGroups(),

                Container(
                  margin: EdgeInsets.only(top: 30),
                  child: Text("Waiting to connnect:",
                    style: TextStyle(
                      fontSize: AppController.scaleViaWidth(16, minValue: 15, maxValue: 18),
                    )
                  )
                ),
                ..._UnclaimedGroups(),
                // _CommunicationTypeButtons,
                // Row(
                //   mainAxisAlignment: MainAxisAlignment.center,
                //   children: [
                //     Center(child: Text("Syncing:")),
                //     _SyncingSwitch,
                //   ]
                // ),
              ]
            )
          ),
        )
      )
    );
  }

  List<Widget> _ConnectedGroups() {
    if (Group.connectedGroups.length == 0)
      return [Text('No connected groups found',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey,
          ),
      )];

    return Group.connectedGroups.map((group) {
      return _groupWidget(group);
    }).toList();
  }

  List<Widget> _UnclaimedGroups() {
    if (Group.unclaimedGroups.length == 0)
      return [Text('No new groups detected',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey,
          ),
      )];

    return Group.unclaimedGroups.map((group) {
      return _groupWidget(group);
    }).toList();
  }

  Widget _groupWidget(group) {
    var isExpanded = _expandedGroupIds.contains(group.id);
    // print("MMMMMMMMMMM: ${group.props.first.currentMode.number}");
    return  Card(
      margin: EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      elevation: 8.0,
      child: ListTile(
        minLeadingWidth: 0,
        leading: ModeImage(
          mode: group.props.first.currentMode,
        ),
        trailing: Group.connectedGroups.contains(group) ? GestureDetector(
          onTap: () {
            return Navigator.pushNamed(context, '/login-overlay', arguments: {
              'showCloseButton': true
            }).then((_) {
              if (Authentication.isAuthenticated)
                setState(() {});
            });
          },
          child: Container(
            // margin: EdgeInsets.only(right: showBadge == true ? 27 : 0),
            padding: EdgeInsets.symmetric(vertical: 7, horizontal: AppController.isSmallScreen ? 8 : 12),
            decoration: BoxDecoration(
              color: Colors.blue
            ),
            child: Text(Authentication.isAuthenticated ? "Claim Now" : "Sign in to Claim",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppController.isSmallScreen ? 13 : 14
              )
            ),
          )
        ) : null,
        title: Container(
          padding: EdgeInsets.symmetric(vertical: 6.0),
          child: Column(
            children: [
              _groupTitle(group, isExpanded: isExpanded),
              ...(isExpanded ? _propsForGroup(group) : []),
            ]
          )
        )
      )
    );
  }

  Widget _groupTitle(group, {isExpanded}) {
    Set unSelectedPropIds = group.propIds.toSet().difference(Group.currentQuickGroup.propIds.toSet());
    bool allPropsSelected = unSelectedPropIds.length == 0;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isExpanded)
            _expandedGroupIds.remove(group.id);
          else _expandedGroupIds.add(group.id);
        });
      },
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              setState(() {
                group.props.forEach((prop) {
                  if (allPropsSelected)
                    Group.currentQuickGroup.props.removeWhere((p) => p.id == prop.id);
                  else if (!Group.currentQuickGroup.propIds.contains(prop.id))
                    Group.currentQuickGroup.props.add(prop);
                });
              });
            },
            child: Container(
              height: 30,
            //   child: allPropsSelected ? Icon(Icons.check) : Container(),
            ),
          ),
          Text(group.name, style: TextStyle(fontSize: AppController.scaleViaWidth(15, maxValue: 19, minValue: 13))),
          isExpanded ? Icon(Icons.expand_more) : Icon(Icons.chevron_right), 
        ]
      ),
    );
  }

  List<Widget> _propsForGroup(group) {
    return group.props.map<Widget>((prop) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          var propIds = Group.currentQuickGroup.propIds;
          var props = Group.currentQuickGroup.props;
          setState(() {
            if (propIds.contains(prop.id))
              props.removeWhere((quickProp) => quickProp.id == prop.id);
            else props.add(prop);
          });
        },
        child: Row(
          children: [
            Container( width: 25),
            // Container(
            //   width: 25,
            //   height: 30,
            //   // decoration: BoxDecoration(color: Colors.blue),
            //   child: Group.currentQuickGroup.propIds.contains(prop.id) ?
            //          Icon(Icons.check) : Container(),
            // ),
            Text("Prop #"),
          ]
        )
      );
    }).toList();
  }










  Widget get _CommunicationTypeButtons {
    return Container(
      child: ToggleButtons(
        isSelected: [Bridge.isBle, Bridge.isWifi],
        onPressed: (int index) {
          setState(() {
            // Bridge.currentChannel = ['bluetooth', 'wifi'][index];
          });
        },
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text("Bluetooth"),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text("WiFi"),
          ),
        ]
      )
    );
  }

  Widget get _SyncingSwitch {
    return Switch(
      value: Bridge.isSyncing,
      onChanged: (_) {
        setState(() => Bridge.toggleSyncing());
      }
    );
  }
}


