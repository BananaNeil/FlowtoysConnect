import 'package:app/components/connection_icon.dart';
import 'package:app/components/rename_form.dart';
import 'package:open_settings/open_settings.dart';
import 'package:app/authentication.dart';
import 'package:app/app_controller.dart';
import 'package:app/models/bridge.dart';
import 'package:app/models/prop.dart';
import 'package:flutter/material.dart';
// import 'package:app/models/group.dart';
import 'package:badges/badges.dart';
import 'dart:io' show Platform;
import 'package:intl/intl.dart';
import 'dart:async';


class BridgeConnectionStatus extends StatefulWidget {
  BridgeConnectionStatus();

  @override
  _BridgeConnectionStatus createState() => _BridgeConnectionStatus();
}

class _BridgeConnectionStatus extends State<BridgeConnectionStatus> {
  _BridgeConnectionStatus();

  StreamSubscription stateSubscription;

  bool get isConnected => bleConnected || oscConnected;
  bool get bleConnected => Bridge.bleManager.isConnected;
  bool get oscConnected => Bridge.oscManager.isConnected;
  bool get wifiNetworkKnown => Bridge.oscManager.networkKnown;

  @override
  initState() {
    super.initState();
    stateSubscription = Bridge.stateStream.listen((_) => setState((){}));
  }

  @override
  dispose() {
    stateSubscription?.cancel();
    super.dispose();
  }

  String get currentWifiNetworkName => Bridge.oscManager.currentWifiNetworkName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: EdgeInsets.only(top: 15),
      insetPadding: EdgeInsets.all(isSmallScreen ? 15 : 25),
      actionsPadding: EdgeInsets.all(5),
      actions: actions,
      content: Stack(
        children: [
          _Content(),
        ]
      )
    );
  }

  bool get isSmallScreen => AppController.isSmallScreen;

  Widget _Content() {
    return Stack(
      children: [
        ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 5 : 10, vertical: 15),
          title: Container(
            margin: EdgeInsets.only(right: 20, left: 20, top: 10),
            child: Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20)
            )
          ),
          subtitle: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _InnerContent(),
              Container(width: 500),
            ]
          )
        ),
        Container(
          height: 40,
          margin: EdgeInsets.only(right: 15),
          child: Align(
            alignment: FractionalOffset.topRight,
            child: GestureDetector(
              child: Icon(Icons.settings),
              onTap: () {
                Navigator.pop(context, _openBridgeSettings);
              }
            ),
          ),
        )
      ],
    );
  }

  String get title {
    if (isConnected)
      return "Connected to ${Bridge.name}";
    else if (Bridge.isRestarting == true)
      return "Bridge is restarting...";
    else if (Bridge.oscManager.connectedToBridgeWifi)
      return "Bridge not yet responding...";
    else return "Bridge not yet found";
  }

  Widget _InnerContent() {
    return Container(
      margin: EdgeInsets.only(top: 20),
      child: Column(
        children: [
           !(isConnected && Bridge.isUnclaimed) ? null : _BridgeDetailsCard(
            trailingVisible: isConnected && Bridge.isUnclaimed,
            showBadge: isConnected && Bridge.isUnclaimed,
            titleText: "Is this your bridge?",
            trailingButtonText: _claimNowText,
            onTapTrailing: () => ensureAuthentication(() => _openNameForm()),
            leading: ConnectionIcon(
              connectedIcon: Image(image: AssetImage('assets/images/bridge-connected.png')),
              isConnected: true,
            ),
          ),
           _WifiDetailsCard(),
          _BridgeDetailsCard(
            leading: ConnectionIcon(isConnected: bleConnected, connectedIcon: Icon(Icons.bluetooth_connected), disconnectedIcon: Icon(Icons.bluetooth_disabled)),
            trailingVisible: Bridge.bleManager.isOff && (Platform.isIOS || Platform.isAndroid),
            trailingButtonText: "Settings",
            onTapTrailing: () {
              OpenSettings.openBluetoothSetting();
              return Future.value(null);
            },
            titleText: Bridge.bleManager.statusMessage,
          ),
          isConnected && unclaimedPropCount > 0 ? _BridgeDetailsCard(
            leading: ConnectionIcon(isConnected: false, disconnectedIcon: Container(width: 23, child: Image(image: AssetImage('assets/images/cube.png')))),
            onTapTrailing: () => Navigator.pushNamed(context, '/props'),
            trailingButtonText: "Claim Now",
            trailingVisible: true,
            showBadge: true,
            // onTapTrailing: () {
            // //   OpenSettings.openBluetoothSetting();
            //   return Future.value(null);
            // },
            titleText: "${unclaimedPropCount} unclaimed ${Intl.plural(unclaimedPropCount, one: 'prop', other: 'props')} detected!",
          ) : null,

        ].where((widget) => widget != null).toList(),
      ),
    );
  }

  int get unclaimedPropCount => Prop.unclaimedProps.length;

  String get _claimNowText => Authentication.isAuthenticated ? "Claim Now" : "Sign in to Claim";

  List<Widget> get actions {
    return <Widget>[
      FlatButton(
        child: Container(
          child: Text('Bluetooth Not Working?'),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        textColor: AppController.blue,
        onPressed: () {
          AppController.dialogIsOpen = false;
          Navigator.pop(context, true);
          print("Open bluetooth help dialoag");
        },
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

  Widget _WifiDetailsCard() {
    if (!Bridge.oscManager.isEnabled) return null;
    if (isConnected && Bridge.oscManager.connectedToBridgeWifi)
      return _BridgeDetailsCard(
        leading: ConnectionIcon(
          isConnected: true,
          connectedIcon: Icon(Icons.wifi_tethering),
          disconnectedIcon: Icon(Icons.wifi_tethering),
        ),
        titleText: "Connected to a FlowConnect network!",
        // subtitle: Text("Click 'Connect' to help your bridge join the network [${Bridge.oscManager.mostRecentWifiNetworkName}]"),
        subtitle: Text("Use this connection to link your bridge to the network [ ${Bridge.oscManager.mostRecentWifiNetworkName} ]"),
        onTapTrailing: _openWifiDetailsForm,
        trailingButtonText: 'Link Now',
        trailingVisible: Bridge.oscManager.mostRecentWifiNetworkName != null,
        subtitleVisible: Bridge.oscManager.mostRecentWifiNetworkName != null,
      ); 
    else if (wifiNetworkKnown)
      return _BridgeDetailsCard(
        leading: ConnectionIcon(
          isConnected: oscConnected,
          connectedIcon: Icon(Icons.wifi),
          disconnectedIcon: Icon(Icons.wifi_off),
        ),
        titleText: oscConnected ? 
            "Communicating with bridge via WIFI (${currentWifiNetworkName})" :
              "Waiting for Bridge to join WIFI (${currentWifiNetworkName})",
        showBadge: isConnected && !oscConnected,
        trailingVisible: isConnected && !oscConnected,
        subtitleVisible: !isConnected && !oscConnected,
        onTapTrailing: _openWifiDetailsForm,
        trailingButtonText: 'Connect',
      );
    else return _BridgeDetailsCard(
      leading: ConnectionIcon(
        isConnected: oscConnected,
        connectedIcon: Icon(Icons.wifi),
        disconnectedIcon: Icon(Icons.wifi_off),
      ),
      titleText: "Wifi network unknown",
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
    ); 
  }

  Widget _BridgeDetailsCard({leading, titleText, subtitle, trailing, subtitleVisible, trailingButtonText, trailingVisible, onTapTrailing, showBadge}) {
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
          subtitle: subtitleVisible == true ? subtitle : null,
          leading: leading,
          title: Text(titleText, style: TextStyle(
                  fontSize: AppController.isSmallScreen ? 13 : 16
          )),
          trailing: (!(trailingVisible == true) ? null : Container(
            constraints: BoxConstraints(minWidth: 0, maxWidth: AppController.isSmallScreen ? 120 : 160),
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context, onTapTrailing);
              },
              child: trailing ?? Container(
                margin: EdgeInsets.only(right: showBadge == true ? 27 : 0),
                padding: EdgeInsets.symmetric(vertical: 7, horizontal: AppController.isSmallScreen ? 8 : 12),
                decoration: BoxDecoration(
                  color: Colors.blue
                ),
                child: Text(trailingButtonText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                  fontSize: AppController.isSmallScreen ? 13 : 14
                  )
                ),
              )
            )
          )),
        ))
      )
    );
  }

  Future _openBridgeSettings() {
    return AppController.openDialog("Bridge Settings",
        "",
      reverseButtons: true,
      buttonText: 'Back',
      child: BridgeSettings(),
    ).then((_) => openBridgeDetails());
  }

  Future _openNameForm() {
    RenameController renameController = RenameController();
    renameController.possessivePrefix = Authentication.currentAccount.firstName;
    renameController.suffix = "FlowConnect";
    return AppController.openDialog("Give your bridge a name!",
        "Naming your bridge will link it to your flowtoys account, and only allow you to control it when in \"private\" mode",
      reverseButtons: true,
      buttonText: 'Cancel',
      child: Container(
        margin: EdgeInsets.only(top: 15),
        child: RenameForm(controller: renameController),
      ),
      buttons: [
        {
          'text': "Claim Now!",
          'color': Colors.blue,
          'onPressed': () {
            Bridge.name = renameController.newName;
            Bridge.save();
          }
        }
      ]
    );
  }

  Future _openWifiDetailsForm() {
    return AppController.openDialog("Your Bridge wants to join your WiFi network:",
      Bridge.oscManager.connectedToBridgeWifi ?
        "You are directly connected to your bridge's wifi network. This provides a stable connection to your props, but you may have issues with internet connectivity. Link your bridge to your personal wifi network for connectivity to your props and the internet!" :
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
    if (wifiNetworkKnown)
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

}

class BridgeSettings extends StatefulWidget {
  BridgeSettings();

  @override
  _BridgeSettings createState() => _BridgeSettings();
}

class _BridgeSettings extends State<BridgeSettings> {
  _BridgeSettings();

  @override
  initState() {
    super.initState();
  }

  @override
  dispose() {
    super.dispose();
  }

  bool showRenameForm = false;
  bool confirmFactoryReset = false;

  @override
  Widget build(BuildContext context) {
    if (confirmFactoryReset)
      return _ConfirmFactoryReset();

    if (showRenameForm)
      return _RenameForm();

    return Container(
      width: 300,
      height: 200,
      // margin: EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => Bridge.oscManager.isEnabled = !Bridge.oscManager.isEnabled),
            child: Container(
              margin: EdgeInsets.only(top: 15),
              child: Row(children: [
                Checkbox(
                  value: Bridge.oscManager.isEnabled,
                  activeColor: Colors.blue,
                  onChanged: (value) => setState(() => Bridge.oscManager.isEnabled = value),
                ),
                Container(child: Text("WIFI Enabled"), padding: EdgeInsets.only(top: 10, bottom: 10, right: 7, left: 0)),
              ])
            )
          ),
          Visibility(
            visible: Bridge.isUnclaimed,
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text("Is this your bridge?"),
                _Button(
                    margin: EdgeInsets.all(0),
                  color: Colors.blue,
                  onTap: () => ensureAuthentication(() => _openNameForm()),
                  text: Authentication.isAuthenticated ? "Claim Now" : "Sign in to Claim",
                )
              ]
            ),
          ),
          _Button(
            visible: !Bridge.isUnclaimed,
              onTap: () => setState(() => showRenameForm = true),
              text: "RENAME",
          ),
          _Button(
            visible: !Bridge.isUnclaimed,
              onTap: () => setState(() => confirmFactoryReset = true),
              text: "FACTORY RESET",
              color: Colors.red,
          ),
        ]
      )
    );
  }

  Future _openNameForm() {
    RenameController renameController = RenameController();
    renameController.possessivePrefix = Authentication.currentAccount.firstName;
    renameController.suffix = "FlowConnect";
    return AppController.openDialog("Give your bridge a name!",
        "Naming your bridge will link it to your flowtoys account, and only allow you to control it when in \"private\" mode",
      reverseButtons: true,
      buttonText: 'Cancel',
      child: Container(
        margin: EdgeInsets.only(top: 15),
        child: RenameForm(controller: renameController),
      ),
      buttons: [
        {
          'text': "Claim Now!",
          'color': Colors.blue,
          'onPressed': () {
            Bridge.name = renameController.newName;
            Bridge.save();
          }
        }
      ]
    );
  }

  Widget _Button({onTap, visible, text, color, margin}){
    return Visibility(
      visible: visible ?? true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: margin ?? EdgeInsets.only(top: 15),
          padding: EdgeInsets.symmetric(vertical: 5, horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: color ?? Color(0xFF333333),
            boxShadow: [
              BoxShadow(
                color: Color(0xAA000000),
                offset: Offset(2.0, 2),
                spreadRadius: 1.0,
                blurRadius: 1.0,
              )
            ]
          ),
          child: Text(text),
        ),
      ),
    );
  }

  RenameController renameController;
  Widget _RenameForm() {
    if (renameController == null) {
      renameController = RenameController();
      renameController.newName = Bridge.name;
      renameController.suffix = " FlowConnect";
    }

    return Column(
      children: [
        Container(
          margin: EdgeInsets.only(top: 15),
          child: RenameForm(controller: renameController),
        ),
        GestureDetector(
          onTap: () {
            Bridge.name = renameController.newName;
            Bridge.save();
            Navigator.pop(context, true);
          },
          child: Text("SAVE", style: TextStyle(color: Colors.blue)),
        ),
      ]
    );
  }

  Widget _ConfirmFactoryReset() {
    return Column(
      children: [
        Container(
          margin: EdgeInsets.only(top: 15),
          child: Text("ARE YOU SURE YOU WANT TO RESET THIS BRIDGE?"),
        ),
        Container(
          margin: EdgeInsets.only(top: 15),
          child: Text("This will remove all customizations and settings"),
        ),
        GestureDetector(
          onTap: () {
            Bridge.factoryReset();
            Navigator.pop(context, null);
          },
          child: Text("RESET NOW", style: TextStyle(color: Colors.red)),
        ),
      ]
    );
  }

}


