import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:osc/osc.dart';
import 'package:osc/src/convert.dart';
import 'package:osc/src/message.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:validators/validators.dart';
import 'package:multicast_dns/multicast_dns.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:app/models/bridge.dart';

class OSCManager {
  InternetAddress remoteHost;
  int remotePort = 9000;

  String autoDetectedBridge;
  bool isConnected = false;

  RawDatagramSocket socket;
  SharedPreferences prefs;

  StreamController<int> zeroconfStream ;

  StreamController<void> get changeStream => Bridge.changeStream;
  Stream get stateStream => Bridge.stateStream;

  OSCManager() {
    RawDatagramSocket.bind(InternetAddress.anyIPv4, 0).then((_socket) {
      // loadPreferences();
      socket = _socket;
    });

    autoDetectedBridge = "";
    initWifi();
  }

  Timer periodicTimer;
  void initWifi() {
    periodicTimer?.cancel();
    periodicTimer = Timer(Duration(seconds: 5), initWifi);
    checkWifiConnection().then((_) {
      print("Connection checked: ${wifiIsConnected}");
      if (wifiIsConnected)
        discoverServices();
        // scanForBridges().then((bridges) {
        //   print("Scanned for bridges: ${bridges.length}");
        //   if (bridges.length == 0)
        //     waitingForCredentials = true;
        //   // else if (bridges.length == 1)
        // });
    });
  }

  Future<List<String>> scanForBridges() {
    return Future.value([]);

    // Client.makeRequest('get',
    //     uri: ''
    // )
  }

  bool waitingForCredentials = false;

  bool wifiIsConnected;
  DateTime wifiLastCheckedAt;
  Connectivity _connectivity;

  Set<Map<String, String>> wifiNetworks = Set();
  String currentWifiNetworkName;
  String mostRecentWifiPassword;
  String currentWifiSSID;

  bool get connectedToBridgeWifi {
    RegExp regex = RegExp(r'FlowConnect');
    return regex.hasMatch(currentWifiNetworkName);
  }

  String get mostRecentWifiNetworkName => mostRecentWifiNetwork['name'];
  String get mostRecentWifiSSID => mostRecentWifiNetwork['ssid'];

  Map<String, String> get mostRecentWifiNetwork {
    if (connectedToBridgeWifi && wifiNetworks.length > 1) {
      return wifiNetworks.firstWhere((network) {
        return !RegExp(r'FlowConnect').hasMatch(network['name']);
      }, orElse: () => {}); 

    }
  }

  bool get wifiRecentlyChecked => wifiLastCheckedAt != null && DateTime.now().difference(wifiLastCheckedAt) < Duration(seconds: 1);
  Future checkWifiConnection() async {
    wifiLastCheckedAt ??= DateTime.fromMillisecondsSinceEpoch(0);
    _connectivity ??= Connectivity();


    // .............................
    //
    // I fear that we need this for ios devices.... but it's throwing an error
    // (on macos... maybe we should try limiting it to ios and running again)
    //
    // var status = await NetworkInfo().getLocationServiceAuthorization();
    // if (status == LocationAuthorizationStatus.notDetermined) {
    //   status = await NetworkInfo().requestLocationServiceAuthorization();
    // }

    return _connectivity.checkConnectivity().then(updateWifiConnection);
  }

  Future updateWifiConnection(connectionResult) async {
    wifiLastCheckedAt = DateTime.now();
    wifiIsConnected = connectionResult == ConnectivityResult.wifi;
    if (wifiIsConnected) {
      try {
        currentWifiNetworkName = await NetworkInfo().getWifiName();
        currentWifiSSID = await NetworkInfo().getWifiBSSID();
        wifiNetworks.add({
          'ssid': currentWifiSSID,
          'name': currentWifiNetworkName,
        });
      } on PlatformException catch (e) {
          print(e.toString());
      }
    }
  }
















  void setSyncing(bool val) {
    if (val) sendSync(0);
    else sendSimpleMessage("/stopSync");
  }

  void discoverServices() async {
   
    zeroconfStream = new StreamController<int>();
   
    const String name = '_osc._udp.local';

    final MDnsClient client = MDnsClient();

    print("OSC: Starting discovery, looking for " + name + " ...");
    // Start the client with default options.
    await client.start();
    print("OSC: Discovery started");

    zeroconfStream.add(0);

    bool found = false;
    Stream<PtrResourceRecord> pointers = client.lookup<PtrResourceRecord>(ResourceRecordQuery.serverPointer(name),
      timeout: const Duration(minutes: 1)
    );

    // Get the PTR recod for the service.
    await for (PtrResourceRecord ptr in pointers) {
        // Use the domainName from the PTR record to get the SRV record,
        // which will have the port and local hostname.
        // Note that duplicate messages may come through, especially if any
        // other mDNS queries are running elsewhere on the machine.

        await for (SrvResourceRecord srv in client.lookup<SrvResourceRecord>(
            ResourceRecordQuery.service(ptr.domainName))) {
          // Domain name will be something like "io.flutter.example@some-iphone.local._dartobservatory._tcp.local"
          final String bundleId =
              ptr.domainName; //.substring(0, ptr.domainName.indexOf('@'));

          print('OSC instance found at ' + srv.toString());
          if(srv.name.contains("flowtoysconnect")) {
            await for (IPAddressResourceRecord ipr
              in client.lookup<IPAddressResourceRecord>(
                  ResourceRecordQuery.addressIPv4(srv.target))) {
            // Domain name will be something like "io.flutter.example@some-iphone.local._dartobservatory._tcp.local"

            print("IPV4 Found : " + ipr.address.address);
            autoDetectedBridge = ipr.address.address;
            print("Bridge detected on " + autoDetectedBridge);
            setIPAddress(ipr.address.address);
            found = true;
            if(!zeroconfStream.isClosed) zeroconfStream.add(1);
            client.stop();
          }
        }
       
      }
    }

    if (!found) {
      autoDetectedBridge = "";
      if(!zeroconfStream.isClosed) zeroconfStream.add(2);
    }

    client.stop();
    zeroconfStream.close();

    isConnected = found;
    changeStream.add(null);
    print('Discovery Done. Connected? ${isConnected}');
  }

  // void loadPreferences() async {
  //   if (prefs == null) prefs = await SharedPreferences.getInstance();
  //   try {
  //     remoteHost = InternetAddress(prefs.getString("oscRemoteHost") ?? "192.168.4.1");
  //   } on ArgumentError catch (error) {
  //     print("Error getting IP from preferences : " + error.message);
  //   }
  //
  //   print("Now sending OSC to " + remoteHost?.address + ":" + remotePort.toString());
  // }

  void setRemoteHost(String value) {
    prefs.setString("oscRemoteHost", value);
    try {
      remoteHost = InternetAddress(prefs.getString("oscRemoteHost") ?? "192.168.1.43");
    } on ArgumentError catch (error) {
      print("Error getting IP from preferences : " + error.message);
    }

    print("Now sending OSC to " + remoteHost?.address + ":" + remotePort.toString());
  }

  void setIPAddress(String address) {
    if (address != null)
      remoteHost = InternetAddress(address);
  }


  //OSC Messages

  void sendMessage(OSCMessage m) {
    remotePort = 9000;
    print("Send message : " + m.address + " to ${remoteHost?.address}:${remotePort}");
    socket.send(m.toBytes(), remoteHost, remotePort);
  }

  void sendSimpleMessage(String message) {
    sendMessage(new OSCMessage(message, arguments:List<Object>()));
  }

  void sendGroupMessage(String message, int group) {
    List<Object> args = new List<Object>();
    args.add(group);
    args.add(0);//groupIsPublic = false, force private group
    OSCMessage m = new OSCMessage(message, arguments: args);
    sendMessage(m);
  }

  void sendPattern({int group, int page, int mode, int actives, List<double> paramValues}) {
    List<Object> args = new List<Object>();
    args.add(group);
    args.add(0);//groupIsPublic = false, force private group
    args.add(page - 1);
    args.add(mode - 1);
    args.add(actives);
    for(int i=0;i<paramValues.length;i++) args.add((paramValues[i]*255).round());
    OSCMessage m = new OSCMessage("/pattern", arguments: args);
    sendMessage(m);
  }

  void sendSync(double time)
  {
    List<Object> args = new List<Object>();
    args.add(time);
     OSCMessage m = new OSCMessage("/sync", arguments: args);
    sendMessage(m);
  }
}

class OSCSettingsDialog extends StatefulWidget {
  OSCSettingsDialog({Key key, this.manager}) : super(key: key) {}

  final OSCManager manager;

  @override
  OSCSettingsDialogState createState() => OSCSettingsDialogState(manager);
}

class OSCSettingsDialogState extends State<OSCSettingsDialog> {
  OSCSettingsDialogState(OSCManager _manager) : manager = _manager{

    ipController.text = manager.remoteHost?.address;

    manager.discoverServices();
    subscription = manager.zeroconfStream.stream.listen((data){
      setState(()
      {
        isSearchingZeroconf = data == 0;
        foundZeroconf = data == 1;
      });
    }); 
  }

  @override
  void dispose()
  {
    subscription.cancel();
    super.dispose();
  }

  StreamSubscription<int> subscription;
  bool isSearchingZeroconf = false;
  bool foundZeroconf = false;

  OSCManager manager;
  final TextEditingController ipController = new TextEditingController();

  final formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0.0,
        backgroundColor: Color(0xff333333),
        child: Padding(
            padding: EdgeInsets.all(8),
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                Container(
                    margin: EdgeInsets.only(bottom: 20),
                    alignment: Alignment.center,
                    child: Text(
                      "OSC Settings",
                      style: TextStyle(color: Color(0xffcccccc)),
                    )),
                Form(
                  key: formKey,
                  child: Row(
                    children: <Widget>[
                      Flexible(
                        child: TextFormField(
                          controller: ipController,
                          style: TextStyle(color: Colors.white),
                          validator: (value) {
                            return isIP(value, "4")
                                ? null
                                : "IP format is invalid (must be x.x.x.x)";
                          },
                          decoration: InputDecoration(
                              labelText: "Remote Host",
                              labelStyle: TextStyle(color: Colors.white54),
                              fillColor: Colors.white,
                              border: new OutlineInputBorder(
                                  borderRadius: new BorderRadius.circular(2.0),
                                  borderSide:
                                      new BorderSide(color: Colors.red))),
                        ),
                      ),
                      Padding(
                          padding: EdgeInsets.only(left: 15),
                          child: RaisedButton(
                              child: Text(isSearchingZeroconf?"Searching...":(foundZeroconf?"Auto-set":"Not found"),
                                  style: TextStyle(color: Color(0xffcccccc))),
                              color: Colors.green,
                              disabledColor: isSearchingZeroconf?Colors.blue:Colors.red,
                              onPressed: foundZeroconf
                                  ? () {
                                      ipController.text = manager.autoDetectedBridge;
                                    }
                                  : null)),
                    ],
                  ),
                ),
                Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: RaisedButton(
                      child: Text("Save"),
                      onPressed: () {
                        if (formKey.currentState.validate()) {
                          manager.setRemoteHost(ipController.text);
                          Navigator.of(context).pop();
                        }
                      },
                    ))
              ],
            )));
  }
}

class OSCSettingsIcon extends StatelessWidget {
  OSCSettingsIcon({Key key, this.manager}) : super(key: key) {}

  final OSCManager manager;

  Widget build(BuildContext context) {
    return FloatingActionButton(
        child: Icon(Icons.settings),
        onPressed: () => showDialog(
            context: context,
            builder: (BuildContext context) =>
                OSCSettingsDialog(manager: manager)));
  }
}
