import 'package:open_settings/open_settings.dart';
import 'package:app/components/edit_groups.dart';
import 'package:app/authentication.dart';
import 'package:app/app_controller.dart';
import 'package:app/models/bridge.dart';
import 'package:flutter/material.dart';
import 'package:app/models/group.dart';
import 'package:badges/badges.dart';
import 'dart:io' show Platform;
import 'dart:async';


class BridgeConnectionStatus extends StatefulWidget {
  BridgeConnectionStatus();

  @override
  _BridgeConnectionStatus createState() => _BridgeConnectionStatus();
}

class _BridgeConnectionStatus extends State<BridgeConnectionStatus> {
  _BridgeConnectionStatus();

  StreamSubscription stateSubscription;
  int unseenItemCount = 0;

  @override
  initState() {
    super.initState();
    stateSubscription = Bridge.stateStream.listen((_) {
      unseenItemCount = 0;
      if (Bridge.oscManager.waitingForCredentials && bleConnected)
        unseenItemCount += 1;

      if (isConnected && Bridge.isUnclaimed)
        unseenItemCount += 1;

      setState(() {});
    });
  }

  @override
  dispose() {
    stateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {


    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // _ConnectionIcon(
        //   isConnected: bleConnected,
        //   connectedIcon: Icon(Icons.bluetooth_connected),
        //   disconnectedIcon: Icon(Icons.bluetooth_disabled),
        // ),
        // _ConnectionIcon(
        //   isConnected: oscConnected,
        //   connectedIcon: Icon(Icons.wifi),
        //   disconnectedIcon: Icon(Icons.wifi_off),
        // ),
        GestureDetector(
          onTap: () {
            setState(() => unseenItemCount = 0);
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
            child: _ConnectionIcon(
              isConnected: isConnected,
              connectedIcon: Image(image: AssetImage('assets/images/bridge-connected.png')),
              disconnectedIcon: Image(image: AssetImage('assets/images/bridge-disconnected.png')),
            )
          ),
        ),
        Container(
            margin: EdgeInsets.only(right: 10),
        ),
        _EditGroupButton(),
        Container(
            margin: EdgeInsets.only(right: 50),
        )
      ]
    );
  }

  Widget _BridgeDetailsCard({leading, title, subtitle, trailing, subtitleVisible, trailingButtonText, trailingVisible, onTapTrailing, showBadge}) {
    return Badge(
      showBadge: showBadge == true,
      badgeColor: Colors.red.withOpacity(1),
      badgeContent: Container(
        padding: EdgeInsets.all(0),
        child: Text(' ',
          style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold
          ),
        ),
      ),
      // position: BadgePosition.topStart(),
      position: BadgePosition(top: 25, end: 15),
      child: Card(
        elevation: 10,
        child: Container(decoration: BoxDecoration(color: Colors.black.withOpacity(0.4)), child: ListTile(
          minLeadingWidth : 0,
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          subtitle: subtitle,
          leading: leading,
          title: title,
          trailing: (!(trailingVisible == true) ? null : GestureDetector(
            onTap: () {
              Navigator.pop(context, onTapTrailing);
            },
            child: trailing ?? Container(
              margin: EdgeInsets.only(right: 27),
              padding: EdgeInsets.symmetric(vertical: 7, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.blue
              ),
              child: Text(trailingButtonText,
                style: TextStyle(
                  fontSize: 14,
                )
              ),
            )
          )),
        ))
      )
    );
  }

  Future _openLoginScreen() {
    Navigator.pushNamed(context, '/login-overlay', arguments: {
      'showCloseButton': true
    }).then((_) {
      print("Logiin screen closed!!!!!!!!!! now open the name form:");
      _openNameForm();
    });
  }

  Future openBridgeDetails() {
    return AppController.openDialog(isConnected ? "Connected to ${Bridge.name}" : "Bridge not yet found",
      "",
      buttonText: 'close',
      buttons: [{
        'text': 'Bluetooth Not Working?',
        'color': AppController.blue,
        'onPressed': () {
          print("Open bluetooth help dialoag");
        },
      }],
      child: Container(
        margin: EdgeInsets.only(top: 20),
        child: Column(
          children: [
             !(isConnected && Bridge.isUnclaimed) ? null : _BridgeDetailsCard(
              trailingVisible: isConnected && Bridge.isUnclaimed,
              showBadge: isConnected && Bridge.isUnclaimed,
              title: Text("Is this your bridge?"),
              trailingButtonText: Authentication.isAuthenticated ? "Claim Now" : "Sign in to Claim",
              onTapTrailing: Authentication.isAuthenticated ? _openNameForm : _openLoginScreen,
              leading: _ConnectionIcon(
                disconnectedIcon: Image(image: AssetImage('assets/images/bridge-connected.png')),
                isConnected: false,
              ),
            ),
            Bridge.oscManager.connectedToBridgeWifi ?
              _BridgeDetailsCard(
                leading: _ConnectionIcon(
                  isConnected: true,
                  connectedIcon: Icon(Icons.wifi),
                  disconnectedIcon: Icon(Icons.wifi_off),
                ),
                title: Text(
                  "Connected to a FlowConnect network"
                ),
                subtitle: Text("Click 'Connect' to help your bridge join the network [${Bridge.oscManager.mostRecentWifiNetworkName}]"),
                showBadge: isConnected && !oscConnected,
                trailingVisible: isConnected && !oscConnected,
                subtitleVisible: !isConnected && !oscConnected,
                onTapTrailing: _openWifiDetailsForm,
                trailingButtonText: 'Connect',
              ) : null,
             wifiConnected ? 
            _BridgeDetailsCard(
              leading: _ConnectionIcon(
                isConnected: oscConnected,
                connectedIcon: Icon(Icons.wifi),
                disconnectedIcon: Icon(Icons.wifi_off),
              ),
              title: Text(oscConnected ? 
                  "Communicating with bridge via WIFI (${Bridge.oscManager.currentWifiNetworkName})" :
                    "Waiting for Bridge to join WIFI (${Bridge.oscManager.currentWifiNetworkName})"
              ),
              showBadge: isConnected && !oscConnected,
              trailingVisible: isConnected && !oscConnected,
              subtitleVisible: !isConnected && !oscConnected,
              onTapTrailing: _openWifiDetailsForm,
              trailingButtonText: 'Connect',
            ) : _BridgeDetailsCard(
              leading: _ConnectionIcon(
                isConnected: oscConnected,
                connectedIcon: Icon(Icons.wifi),
                disconnectedIcon: Icon(Icons.wifi_off),
              ),
              title: Text("No wifi network found."
              ),
              trailingVisible: Platform.isIOS || Platform.isAndroid,
              subtitleVisible: true,
              subtitle: Text(Platform.isIOS || Platform.isAndroid ?
                  "For a better connection, try launching a hotspot from your device." :
                  "Try connecting to the Bridge's wifi network directly\n( password: findyourflow )"
              ),

              onTapTrailing: () {
                OpenSettings.openWIFISetting();
                return Future.value(null);
              },
              trailingButtonText: 'Wifi Settings',
            ),
            _BridgeDetailsCard(
              leading: _ConnectionIcon(isConnected: bleConnected, connectedIcon: Icon(Icons.bluetooth_connected), disconnectedIcon: Icon(Icons.bluetooth_disabled)),
              title: Container(
                child: bleConnected ? Text("Communicating with bridge via Bluetooth (${Bridge.name})") :
                  Text("Searching via Bluetooth..."),
              ),
            ),

          ].where((widget) => widget != null).toList(),
        ),
      )
    ).then((callback) {
      if (callback != null && callback is Function) callback();
    });

  }

  Future _openNameForm() {
    Bridge.name = "${Bridge.ownerName}'s FlowConnect";
    return AppController.openDialog("Give your bridge a name!",
        "Naming your bridge will link it to your flowtoys account, and only allow you to control it when in \"private\" mode",
      reverseButtons: true,
      buttonText: 'Cancel',
      child: BridgeNameForm(),
      buttons: [
        {
          'text': "Save",
          'color': Colors.blue,
          'onPressed': () {
            Bridge.save();
          }
        }
      ]
    );
  }

  Future _openWifiDetailsForm() {
    return AppController.openDialog("Your Bridge wants to join your WiFi network:",
      "Bluetooth is cool, but WiFi is better. For a more stable and consistent connection to your props, please enter your wifi network's password.",
      reverseButtons: true,
      buttonText: 'Cancel',
      child: _WifiDetailsForm(),
      buttons: [
        {
          'text': "Connect",
          'color': Colors.blue,
          'onPressed': () {
            Bridge.connectToMostRecentWifiNetwork();
          }
        }
      ]
    );
  }

  Widget _WifiDetailsForm() {
    // if (!Bridge.isWifi) return Container();
    // wifiConnectionStream ??= Connectivity().onConnectivityChanged.listen(updateWifiConnection);
    if (wifiConnected)
      return Container(
        width: 300,
        height: 200,
        // margin: EdgeInsets.only(top: 20),
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.only(top: 20, bottom: 5),
              padding: EdgeInsets.only(top: 25, bottom: 25),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
              ),
              width: double.infinity,
              child: Text(
                Bridge.oscManager.mostRecentWifiNetworkName ?? "Current Connection: Unknown Network",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  color: Colors.white,
                )
              ),
            ),
            Container(
              child: TextFormField(
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'enter password here',
                ),
                onChanged: (text) {
                  Bridge.oscManager.mostRecentWifiPassword = text;
                }
              )
            ),
          ]
        )
      );
    else return Text("TODO: suggest user to Connect to bridge's wifi? (this may cause issues with internet connectivity)");
  }

  Widget _ConnectionIcon({isConnected, connectedIcon, disconnectedIcon}) {
    Bridge.oscManager.initWifi();
    return Container(
      height: 35,
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(isConnected ? Colors.blue : Colors.white, BlendMode.srcATop),
        child: isConnected ? connectedIcon : disconnectedIcon,
      ),
    );
  }

  bool get isConnected => bleConnected || oscConnected;
  bool get bleConnected => Bridge.bleManager.isConnected;
  bool get oscConnected => Bridge.oscManager.isConnected;
  bool get wifiConnected => Bridge.oscManager.wifiIsConnected;

  String get connectionStatus {
    var oscState = oscConnected ? 'Connected' : 'Disconnected';
    var bleState = bleConnected ? 'Connected' : 'Disconnected';
    return "BLE: ${bleState} - Wifi: ${oscState}";
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
      child: Badge(
        badgeContent: Text(Group.possibleGroups.length.toString(), style: TextStyle(
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


class BridgeNameForm extends StatefulWidget {
  BridgeNameForm();

  @override
  _BridgeNameForm createState() => _BridgeNameForm();
}

class _BridgeNameForm extends State<BridgeNameForm> {
  _BridgeNameForm();

  @override
  initState() {
    super.initState();
  }

  @override
  dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 200,
      // margin: EdgeInsets.only(top: 20),
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.only(top: 20, bottom: 5),
            padding: EdgeInsets.only(top: 25, bottom: 25),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
            ),
            width: double.infinity,
            child: Text(
              Bridge.name ?? "${Bridge.ownerName}'s FlowConnect",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                color: Colors.white,
              )
            ),
          ),
          Container(
            child: TextFormField(
              textAlign: TextAlign.center,
              // initialValue: ,
              decoration: InputDecoration(
                hintText: 'Or enter a custom name here...',
              ),
              onChanged: (text) {
                setState(() {
                  if (text == '')
                    Bridge.name = Authentication.currentAccount.firstName;
                  else Bridge.name = text;

                  Bridge.name += " FlowConnect";
                });
              }
            )
          ),
        ]
      )
    );
  }
}
