import 'package:app/components/bridge_connection_status_icon.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flash_animation/flash_animation.dart';
import 'package:app/components/mode_widget.dart';
import 'package:app/components/edit_groups.dart';
import 'package:app/components/navigation.dart';
import 'package:app/components/rename_form.dart';
import 'package:app/app_controller.dart';
import 'package:app/authentication.dart';
import 'package:app/models/bridge.dart';
import 'package:flutter/material.dart';
import 'package:app/models/group.dart';
import 'package:app/models/prop.dart';
import 'package:app/models/mode.dart';
import 'package:app/client.dart';
import 'package:intl/intl.dart';
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
        // Authentication.currentAccount?.connectedPropIds ??= Set<String>.from([]);
        Authentication.currentAccount?.addConnectedPropId(prop.id);
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
          actions: [

              BridgeConnectionStatusIcon(),
          ]
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black,
                Color(0xFF1A1A1A),
                Color(0xFF404040),
              ]
            )
          ),
          child: Center(
            child: Container(height: double.infinity,
              child: SingleChildScrollView(
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
                      Text("Connected Props:",
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
                      ..._UnconnectedGroups(),
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
          )
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

  List<Widget> _UnconnectedGroups() {
    if (Group.unconnectedGroups.length == 0)
      return [Text('No new groups detected',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey,
          ),
      )];

    return Group.unconnectedGroups.map((group) {
      return _groupWidget(group);
    }).toList();
  }

  Widget _groupWidget(group) {
    var isExpanded = _expandedGroupIds.contains(group.groupId);
    bool canClaim = Group.unclaimedGroups.contains(group);
    return  Card(
      margin: EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      elevation: 8.0,
      child: ListTile(
        minLeadingWidth: 0,
        leading: PropImage(
          prop: group.props.first,
        ),
        trailing: canClaim ? _ClaimNowButton(group) : null,
        title: Container(
          padding: EdgeInsets.symmetric(vertical: 6.0),
          child: Column(
            children: [
              _groupTitle(group, isExpanded: isExpanded),
              // ...(isExpanded ? _propsForGroup(group) : []),
            ]
          )
        )
      )
    );
  }

  Widget _ClaimNowButton(group) {
    return GestureDetector(
      onTap: () {
        if (Authentication.isAuthenticated)
          _openClaimDialog(group: group);
        else {
          var propIds = Authentication.currentAccount.propIds;
          return Navigator.pushNamed(context, '/login-overlay', arguments: {
            'showCloseButton': true
          }).then((_) {
            if (Authentication.isAuthenticated) {
              _openClaimDialog(group: group);
            }
          });
        }
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
    );
  }

  _openClaimDialog({group}) {
    RenameController renameController = RenameController();
    renameController.possessivePrefix = Authentication.currentAccount.firstName;

    if (group.props.length == 1)
      renameController.suffix = "Prop";
    else renameController.suffix = "Props";

    AppController.openCustomDialog(
      ClaimGroup(group: group, renameController: renameController)
    );
  }

  Widget _groupTitle(group, {isExpanded}) {
    Set unSelectedPropIds = group.propIds.toSet().difference(Group.currentQuickGroup.propIds.toSet());
    bool allPropsSelected = unSelectedPropIds.length == 0;
    bool canExpand = group.props.length > 1;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (!canExpand) return;
          if (isExpanded)
            _expandedGroupIds.remove(group.groupId);
          else _expandedGroupIds.add(group.groupId);
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
          Expanded(
            child: Text(group.nameWithCount,
              style: TextStyle(
                fontSize: AppController.scaleViaWidth(15, maxValue: 19, minValue: 13)
              )
            )
          ),
          // !canExpand ? Container() :
          //     (isExpanded ? Icon(Icons.expand_more) : Icon(Icons.chevron_right)), 
        ]
      ),
    );
  }

  List<Widget> _propsForGroup(group) {
    var i = 0;
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
            Text("Prop ${i += 1}",

              style: TextStyle(
                fontSize: AppController.scaleViaWidth(15, maxValue: 19, minValue: 13)
              )
            ),
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
class ClaimGroup extends StatefulWidget {
  ClaimGroup({this.group, this.renameController});

  Group group;
  RenameController renameController;

  @override
  _ClaimGroup createState() => _ClaimGroup();
}

class _ClaimGroup extends State<ClaimGroup> {
  _ClaimGroup();

  @override
  initState() {
    super.initState();
  }

  @override
  dispose() {
    super.dispose();
  }

  Map<String, String> propOptions = {
    // 'Prop': 'Props',
    'Poi': 'Poi',
    'Prop': 'Props',
    'Club': 'Clubs',
    'Staff': 'Staves',
    'Sword': 'Swords',
    'Chuck': 'Chucks',
    'Pixel Poi': 'Pixel Poi',
    'Double Staff': 'Double Staves',
  };

  String get pluralizedPropType => propCount > 1 ? propOptions[propType] : propType;
  int get propCount => widget.group.props.length;
  String propType = "Prop";

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: EdgeInsets.only(top: 15),
      insetPadding: EdgeInsets.all(AppController.isSmallScreen ? 15 : 25),
      actionsPadding: EdgeInsets.all(5),
      actions: actions,
      content: _Content(),
    );
  }

  Widget _Content() {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: AppController.isSmallScreen ? 5 : 10, vertical: 10),
      title: Text("Claim this group",
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 20)
      ),
      subtitle: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _InnerContent(),
          Container(width: 500),
        ]
      )
    );
  }

  List<Widget> get actions {
    return <Widget>[
      FlatButton(
        child: Text("Claim Now!",
          style: TextStyle(
            color: Colors.blue,
          ),
        ),
        onPressed: () async {
          widget.group.name = widget.renameController.newName;
          widget.group.props.forEach((prop) {
            prop.propType = propType;
            prop.userId = Authentication.currentAccount.id;
            // Authentication.currentAccount.propIds.add(prop.id);
          });
          await Client.updateProps(
            propIds: widget.group.props.map((prop) => prop.id).toList(),
            groupName: widget.group.name,
            groupCount: propCount,
            propType: propType,
          ).then((_) {
            Authentication.currentAccount.save();
          });
          Navigator.pop(context, null);
          setState(() {});
        }
      ),
      FlatButton(
        child: Text('close'),
        onPressed: () {
          AppController.dialogIsOpen = false;
          Navigator.pop(context, null);
        },
      ),
    ];
  }

  Widget _InnerContent() {
    return Container(
        margin: EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey, width: 1))
      ),
      child: Column(
        children: [
          _ChoosePropType(),
          _DetectedProps(),
          RenameForm(
            key: Key(widget.renameController.newName),
            controller: widget.renameController
          ),

        ]
      )
    );
  }

	GlobalKey _toolTipKey = GlobalKey();
  Widget _DetectedProps() {
    return Container(
      margin: EdgeInsets.only(top: 2),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children:[
              Container(
                margin: EdgeInsets.only(right:5),
                child: Text("${propCount} ${pluralizedPropType} ${widget.group.hasVirtualProps ? 'selected' : 'detected'}",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.green,
                  )
                )
              ),
              GestureDetector(
                onTap: () {
                  final dynamic _toolTip = _toolTipKey.currentState;
                  _toolTip.ensureTooltipVisible();
                },
                child: Tooltip(
                  key: _toolTipKey,
                  padding: EdgeInsets.all(15),
                  margin: EdgeInsets.symmetric(horizontal: 40),
                  textStyle: TextStyle(fontSize: 15, color: Colors.black),
                  message: "If this number is incorrect, your props may be using an old firmware. "+
                    "Please update your firmware so this app can see each prop individually.",
                  child: Container(
                    child: Text("?"),
                    padding: EdgeInsets.only(top: 5, right: 5, left: 6, bottom: 6),
                    margin: EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                  )
                ),
              ),
            ]
          ),
          Container(
            margin: EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children:[
                _PropCountButton(
                  color: widget.group.hasVirtualProps ? Color(0xff40a253) : Colors.grey,
                  padding: EdgeInsets.only(left: 8, right: 7, bottom: 2, top: 0),
                  text: "-",
                  onTap: () {
                    if (widget.group.hasVirtualProps) {
                      widget.group.removeVirtualProp();
                      widget.renameController.suffix = pluralizedPropType;
                      setState(() {});
                    }
                  }
                ),
                Container(width: 10),
                _PropCountButton(
                  color: Color(0xff40a253),
                  text: "+",
                  onTap: () {
                    widget.group.addVirtualProp();
                    widget.renameController.suffix = pluralizedPropType;
                    setState(() {});
                  }
                ),
              ]
            )
          )
        ]
      )
    );
  }

	Widget _PropCountButton({text, color, onTap, padding}) {
		if (onTap == null)
			return null;

		return GestureDetector(
			onTap: onTap,
			child: Container(
				padding: padding ?? EdgeInsets.only(left: 7, right: 7, bottom: 2, top: 0),
				decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Color(0x44000000),
              offset: Offset(0.9, 0.9),
              spreadRadius: 1,
            )
          ],
					borderRadius: BorderRadius.circular(4),
					color: color,
				),
				child: Text(text, style: TextStyle(fontSize: 18)),
			)
		);
	}

  Widget _ChoosePropType() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
            margin: EdgeInsets.only(right: 20),
            child: Text("Choose your prop type:"),
        ),
        Container(
          margin: EdgeInsets.only(top: 5),
          child: DropdownButton(
            // isExpanded: true,
            value: propType,
            items: propOptions.keys.map((option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Container(
                  margin: EdgeInsets.only(bottom: 5,left: 10, right: 5),
                  child: Text(option)
                )
              );
            }).toList(),
            onChanged: (value) {
              propType = value;
              widget.renameController.suffix = pluralizedPropType;
              setState(() {});
            },
          ),
        ),
      ]
    );
  }

}

