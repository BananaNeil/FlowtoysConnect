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

// import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:app/models/sync_packet.dart';
import 'package:app/models/bridge.dart';

import 'package:quiver/iterables.dart' hide max, min;
import 'package:app/app_controller.dart';

class OSCManager {
  InternetAddress remoteHost;
  int remotePort = 9000;

  String autoDetectedBridge;

  DateTime networkSearchStartedAt;
  bool get isSearchingNetwork {
    if (networkSearchStartedAt == null) return false;
    return DateTime.now().difference(networkSearchStartedAt) < Duration(seconds: 15);
  }

  bool _isConnected = false;
  bool get isConnected => _isConnected;
  set isConnected(bool value) {
    if (value != _isConnected) {
      networkSearchStartedAt = null;
      if (value) sendSimpleMessage("/ping");
    }
    _isConnected = value;
    changeStream.add(null);
  }

  RawDatagramSocket socket;
  SharedPreferences prefs;

  StreamController<int> zeroconfStream;

  StreamController<void> get changeStream => Bridge.changeStream;
  Stream get stateStream => Bridge.stateStream;

	_receiveMessage(RawSocketEvent event) {
    if (event == RawSocketEvent.read) {
      Datagram dg = socket.receive();
      if (dg == null) return;
      List<String> recieved = String.fromCharCodes(dg.data).split(',');
      String path = recieved.first;
      List<int> data = recieved.last.codeUnits;
      print("Received from ${dg.address.address}:${dg.port}");

      data = partition(data.sublist(23), 4).map((arr) => arr.reduce((num a, num b) => a + b)).toList();
      print("path: |${path} ${path[12]} ${"/sync-packet".length}");
      print("data: ${data}");

      if (path.contains("/sync-packet"))
        SyncPacket.fromBridge(data);
    }
  }

  OSCManager() {
    RawDatagramSocket.bind(InternetAddress.anyIPv4, 0).then((_socket) {
			_socket.listen(_receiveMessage);
      // loadPreferences();
      socket = _socket;
    });

    autoDetectedBridge = "";
    print("INIT OSCMANAGER()()()()");
    initWifi();
  }

  Timer periodicTimer;

  void initWifi() {
    periodicTimer?.cancel();
    periodicTimer = Timer(Duration(seconds: 5), initWifi);
    print("INIT wifi");
    checkWifiConnection().then((_) {
      print("Connection checked: ${wifiIsConnected} ${!isSearchingNetwork}");
      if (wifiIsConnected && !isSearchingNetwork)
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

  bool wifiIsConnected = false;
  DateTime wifiLastCheckedAt;
  // Connectivity _connectivity;

  Set<Map<String, String>> wifiNetworks = Set();
  String currentWifiNetworkName;
  String mostRecentWifiPassword;
  String currentWifiSSID;

  bool get connectedToBridgeWifi {
    if (!wifiIsConnected) return false;
    RegExp regex = RegExp(r'FlowConnect');
    return regex.hasMatch(currentWifiNetworkName);
  }

  String get mostRecentWifiNetworkName => mostRecentWifiNetwork['name'];
  String get mostRecentWifiSSID => mostRecentWifiNetwork['ssid'];

  Map<String, String> get mostRecentWifiNetwork {
    // if (connectedToBridgeWifi && wifiNetworks.length > 1) {
      return wifiNetworks.firstWhere((network) {
        return !RegExp(r'FlowConnect').hasMatch(network['name']);
      }, orElse: () => {}); 

    // }
  }

  bool get wifiRecentlyChecked => wifiLastCheckedAt != null && DateTime.now().difference(wifiLastCheckedAt) < Duration(seconds: 1);
  Future checkWifiConnection() async {
    wifiLastCheckedAt ??= DateTime.fromMillisecondsSinceEpoch(0);
    // _connectivity ??= Connectivity();


    // .............................
    //
    // Do we need this or something like this for android devices?
    if (Platform.isIOS) {
      var status = await NetworkInfo().getLocationServiceAuthorization();
      if (status == LocationAuthorizationStatus.notDetermined) {
        status = await NetworkInfo().requestLocationServiceAuthorization();
      }
    }

    // return _connectivity.checkConnectivity().then(updateWifiConnection);

    var newWifiNetworkName;
    try {
      newWifiNetworkName = await NetworkInfo().getWifiName();
      currentWifiSSID = await NetworkInfo().getWifiBSSID();
    } on PlatformException catch (e) {
        print(e.toString());
    }

    if (newWifiNetworkName == null || currentWifiNetworkName != newWifiNetworkName)
      isConnected = false;

    wifiIsConnected = newWifiNetworkName != null; 
    currentWifiNetworkName = newWifiNetworkName;
    if (wifiIsConnected)
      wifiNetworks.add({
        'ssid': currentWifiSSID,
        'name': currentWifiNetworkName,
      });
  }

  // Future updateWifiConnection(connectionResult) async {
  //   wifiLastCheckedAt = DateTime.now();
  //   var previouslyConnected = wifiIsConnected;
  //   wifiIsConnected = connectionResult == ConnectivityResult.wifi;
  //   print("UPDATing wifi status ,,,,,,,,,,,,,, ${connectionResult} ${await NetworkInfo().getWifiName()}");
  //   if (wifiIsConnected != previouslyConnected) isConnected = false;
  //   if (wifiIsConnected) {
  //     try {
  //       var newWifiNetworkName = await NetworkInfo().getWifiName();
  //       if (currentWifiNetworkName != newWifiNetworkName)
  //         isConnected = false;
  //
  //       currentWifiNetworkName = newWifiNetworkName;
  //       currentWifiSSID = await NetworkInfo().getWifiBSSID();
  //       wifiNetworks.add({
  //         'ssid': currentWifiSSID,
  //         'name': currentWifiNetworkName,
  //       });
  //     } on PlatformException catch (e) {
  //         print(e.toString());
  //     }
  //   }
  // }
















  void setSyncing(bool val) {
    if (val) sendSync(0);
    else sendSimpleMessage("/stopSync");
  }

  void discoverServices() async {
   
    zeroconfStream = new StreamController<int>();
    networkSearchStartedAt = DateTime.now();
   
    const String name = '_osc._udp.local';

    final MDnsClient client = MDnsClient();

    print("OSC: Starting discovery, looking for " + name + " ...");
    // Start the client with default options.
    await client.start();
    print("OSC: Discovery started");

    zeroconfStream.add(0);

    bool found = false;
    try {
      Stream<PtrResourceRecord> pointers = client.lookup<PtrResourceRecord>(ResourceRecordQuery.serverPointer(name),
        timeout: const Duration(seconds: 15)
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
            final String bundleId = ptr.domainName; //.substring(0, ptr.domainName.indexOf('@'));

            print('OSC instance found at ' + srv.toString());














            // What if there are two?
            // What if there are two?
            // What if there are two?
            // What if there are two?


            if(srv.name.contains("FlowConnect")) {
              await for (IPAddressResourceRecord ipr
                in client.lookup<IPAddressResourceRecord>(
                    ResourceRecordQuery.addressIPv4(srv.target))) {
              // Domain name will be something like "io.flutter.example@some-iphone.local._dartobservatory._tcp.local"

              print("IPV4 Found : " + ipr.address.address);
              autoDetectedBridge = ipr.address.address;
              print("Bridge detected on " + autoDetectedBridge);
              setIPAddress(ipr.address.address);
              found = true;
              Bridge.name = srv.name.replaceAll('._osc._udp.local', '');
              if(!zeroconfStream.isClosed) zeroconfStream.add(1);
              client.stop();
            }
          }
         
        }
      }
    } on SocketException catch (error) {
      print("Something went wrong with searching local wifi network for bridge.... SocketException");
    }

    if (!found) {
      autoDetectedBridge = "";
      if(!zeroconfStream.isClosed) zeroconfStream.add(2);
    } else if (currentWifiNetworkName.contains("FlowConnect")) {
      Bridge.name = currentWifiNetworkName;
    }

    client.stop();
    zeroconfStream.close();

    isConnected = found;
    networkSearchStartedAt = null;
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
    print("SENDING SIMPLE MESSAGE: ${message}");
    sendMessage(new OSCMessage(message, arguments:List<Object>()));
  }

  void sendGroupMessage(String message, int group) {
    List<Object> args = new List<Object>();
    args.add(group);
    args.add(0);//groupIsPublic = false, force private group
    OSCMessage m = new OSCMessage(message, arguments: args);
    sendMessage(m);
  }

  void sendPattern({String groupId, int page, int mode, int actives, List<double> paramValues}) {
    List<Object> args = new List<Object>();
    args.add(groupId);
    args.add(0);//groupIsPublic = false, force private group
    args.add(page - 1);
    args.add(mode - 1);
    args.add(actives);
    for(int i=0;i<paramValues.length;i++) args.add((paramValues[i]*255).round());
    print("OSC SENDING PATTERN... ${args}");
    OSCMessage m = new OSCMessage("/pattern", arguments: args);
    sendMessage(m);
  }

  void setNetworkName(String name) {
    sendMessage(OSCMessage("/setNetworkName", arguments: [
      name
    ]));
  }

  void sendConfig({String networkName, String ssid, String password}) async {
    OSCMessage m = new OSCMessage("/wifiSettings", arguments: [
      ssid ?? networkName, password,
    ]);
    print("M: ${m}");
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

