import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:app/components/edit_groups.dart';
import 'package:app/components/navigation.dart';
import 'package:app/app_controller.dart';
import 'package:app/models/bridge.dart';
import 'package:flutter/material.dart';
import 'package:app/client.dart';

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

class _PropsPageState extends State<PropsPage> {

  bool awaitingResponse = false;
  String errorMessage;

  @override initState() {
    super.initState();
  }


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: AppController.closeKeyboard,
      child: Scaffold(
        drawer: Navigation(),
        appBar: AppBar(
          title: Text("Connect Props"),
          backgroundColor: Color(0xff222222),
        ),
        body: Center(
          child: Column(
            children: [
              _CommunicationTypeButtons,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Center(child: Text("Syncing:")),
                  _SyncingSwitch,
                ]
              ),
            ]
          ),
        )
      )
    );
  }

  // bool wifiConnectionStream;
  Widget get _WifiDetails {
    // if (!Bridge.isWifi) return Container();
    // wifiConnectionStream ??= Connectivity().onConnectivityChanged.listen(updateWifiConnection);
    if (Bridge.oscManager.wifiIsConnected)
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
                Bridge.oscManager.currentWifiNetworkName ?? "Current Connection: Unknown Network",
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

  Future updateWifiConnection(connectionResult) {
    return Bridge.oscManager.updateWifiConnection(connectionResult).then((_) => setState(() {}));
  }

  Widget get _CommunicationTypeButtons {
    return Container(
      child: ToggleButtons(
        isSelected: [Bridge.isBle, Bridge.isWifi],
        onPressed: (int index) {
          setState(() {
            Bridge.currentChannel = ['bluetooth', 'wifi'][index];
            if (Bridge.isWifi)
             Bridge.oscManager.checkWifiConnection().then((_) {
                return AppController.openDialog("Your Bridge wants to join your WiFi network:",
                  "Bluetooth is cool, but WiFi is better. For a more stable and consistent connection to your props, please enter your wifi network's password.",
                  reverseButtons: true,
                  buttonText: 'Cancel',
                  child: _WifiDetails,
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
             });
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


