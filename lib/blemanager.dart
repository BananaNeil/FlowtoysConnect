import 'dart:async';
import 'dart:math';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:convert';

import 'package:app/models/bridge.dart';
import 'package:app/app_controller.dart';
import 'package:app/models/sync_packet.dart';

import 'package:shared_preferences/shared_preferences.dart';

enum BridgeMode { WiFi, BLE, Both }

class BLEManager {
  FlutterBlue flutterBlue;
  BluetoothDevice bridge;


  bool _isConnected = false;
  bool get isConnected => _isConnected;
  set isConnected(value) {
    if (value != _isConnected)
    _isConnected = value;
    changeStream.add(null);
  }

  bool isConnecting = false;
  bool isScanning = false;
  bool isReadyToSend = false;
  bool isSending = false;

  StreamController<void> get changeStream => Bridge.changeStream;
  Stream get stateStream => Bridge.stateStream;

  BridgeMode bridgeMode;
  String networkName = "";
  String ssid = "";
  String pass = "";

  final uartUUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  final txUUID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";
  final rxUUID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";

  BluetoothService uartService;
  BluetoothCharacteristic txChar;
  BluetoothCharacteristic rxChar;

  BLEManager() {
    bridgeMode = BridgeMode.Both;
    initBLE();
  }


  void initBLE() async {
    print("CHECK IF Flutter Blue AVAILABLE?"); 
    FlutterBlue.instance.isAvailable.then((value) {
      print("IS Flutter Blue AVAILABLE? ${value}"); 
      if (!value) {
        print("Bluetooth device not available on this device");
        return;
      }

      flutterBlue = FlutterBlue.instance;

      flutterBlue.isScanning.listen((result) {
        isScanning = result;
        changeStream?.add(null);
      });

      scanAndConnect();
    });
  }

  void setSyncing(bool val) {
    if (val) sendString("s0");
    else sendString("S");
  }

  void sendPattern({String groupId, int page, int mode, int actives, List<int> paramValues}) {
    // List<Object> args = new List<Object>();
    // args.add(groupId);
    // args.add(0);//groupIsPublic = false, force private group
    // args.add(page);
    // args.add(mode);
    // args.add(actives);
    // var values = paramValues.map((value) => (value*255).round());
    sendString("p${groupId},${page - 1},${mode - 1},${actives},${paramValues.join(',')}");
  }

  String _statusMessage;
  String get statusMessage {
    if (_statusMessage != null)
      return _statusMessage;

    if (isOff)
      return "Turn on Bluetooth to connect...";
    else if (isConnected) 
      return "Communicating with bridge via Bluetooth (${Bridge.name})";
    else return "Searching via Bluetooth...";
  }

  set statusMessage(message) {
    changeStream.add(null);
    _statusMessage = message;
  }

  bool isOff = false;

  void factoryReset() {
    sendString('R');
  }

  void scanAndConnect() async {
    if (flutterBlue == null)
      return print("BLE not supported");
    sleep(Duration(milliseconds: 100));

    bridge = null;
    isConnected = false;

    await flutterBlue.connectedDevices.then((devices) {
      for (BluetoothDevice device in devices) {
        if (device.name.contains("FlowConnect")) {
          Bridge.name = device.name;
          bridge = device;
          break;
        }
      }
    }).catchError((error) {
      print("Searching for devices failed: ${error}");
    });

    if (bridge != null) {
      print("Already connected but not assigned (${txChar != null})");
      isConnected = false;
      isReadyToSend = txChar != null;
       connectToBridge();
      return;
    }

    //Not already there, start scanning

    if (isScanning) {
      print("Already scanning");
      return;
    }

    // print("CHECK IF ON");
    flutterBlue.isOn.then((isOn) async {
      isOff = !isOn;
      if (!isOn) {
        // THIS IS A GREAT PLACE TO TELL THE USER TO TURN ON THEIR BLUETOOTH 
        print("Bluetooth is not activated.");
        periodicallyAttemptReconnect();
        return;
      }
      print("Scanning devices...");
      
      print("SETTING BRIDGE TO NULL");
      bridge = null;
      isConnected = false;
      isConnecting = true;
      isReadyToSend = false;
      changeStream.add(null);
      await flutterBlue.stopScan();

      flutterBlue
          .startScan(timeout: Duration(seconds: 5))
          .whenComplete(connectToBridge);

      scanSubscription?.cancel();
      scanSubscription = flutterBlue.scanResults.listen((scanResult) {
        // do something with scan result

        for (var result in scanResult) {
          if (result.device.name.contains("FlowConnect")) {
            Bridge.name = result.device.name;
            bridge = result.device;
            flutterBlue.stopScan();
            return;
          }
        }
      });
    });
  }

  int _secondsUntilReconnect = 2;
  int get secondsUntilReconnect => min(_secondsUntilReconnect += 1, 12);

  void resetReconnectionTimeOut() {
    _secondsUntilReconnect = 2;
  }

  Timer reconnectTimer;
  void periodicallyAttemptReconnect() {
    print("periodically attempting to reconnect to BLE");
    reconnectTimer?.cancel();
    if (!isConnected)
      reconnectTimer = Timer(Duration(seconds: secondsUntilReconnect), () {
        reconnectToBridge();
        periodicallyAttemptReconnect();
        print("BLE Wated ${secondsUntilReconnect} seconds, now reconnecting");
      });
  }

  StreamSubscription<List<ScanResult>> scanSubscription;
  StreamSubscription stateSubscription;
  void connectToBridge() async {

    if (bridge == null) {
      //print("Bridge not found");
      print("No FlowConnect bridge found via BLE.");
      isConnected = false;
      isConnecting = false;
      changeStream.add(null);
      periodicallyAttemptReconnect();
      return;
    }

    print("BLE: Connect to bridge : " + bridge?.name);
    print("BLE: Connecting to bridge...");


    stateSubscription?.cancel();
    stateSubscription = bridge.state.listen((state) {
      
      // Okay.... this is getting called when the bridge crashes. Then seconds later, we are trying to read from rx.
      // We need to set isConnected (done, I think), and let rx reading be conditional on that.

      print("Bridge connection state change: ${state} ...");
      bool newConnected = state == BluetoothDeviceState.connected;
      isConnected = newConnected;
      if(isConnected) isConnecting = false;
      changeStream.add(null);

      if(state != BluetoothDeviceState.connected)
        periodicallyAttemptReconnect();
      else Bridge.name = bridge.name;

      if (isConnected || newConnected) {
        print((isConnected ? "Connected to " : "Disconnected from ") + bridge.name+".");
      }

      if (isConnected) {
        resetReconnectionTimeOut();
        getRXTXCharacteristics();
      }
    });


     
    try {
      await bridge.connect();
    } on PlatformException catch (error) {
      if (error.message == "Peripheral not found")
        scanAndConnect();
      print("Error connecting : " + error.toString());
      print("Error message : " + error.message);
    }
  }

  void _receiveMessage(_data) {
    List<int> data = List<int>.from(_data);
    if (data.length > 0) {
      String commandType = String.fromCharCode(data.removeLast());
      print("RECEIVED FROM RX BLE (command type: ${commandType}): ${data}"); 
      if (commandType == 'p') {
        SyncPacket.fromBridge(data);
      } else if (commandType == 'w')
        AppController.oscManager.setIPAddress(String.fromCharCodes(data));
    }
  }

  BluetoothCharacteristic rx;
  StreamSubscription rxSubscription;
  void getRXTXCharacteristics() async {
    print("Discover services");
    List<BluetoothService> services = await bridge.discoverServices();
    for (BluetoothService service in services) {
      if (service.uuid.toString() == uartUUID) {
        uartService = service;

        for (BluetoothCharacteristic characteristic in service.characteristics) {
          print("Characteristic : "+characteristic.uuid.toString());

          if (characteristic.uuid.toString() == rxUUID) {
            rxSubscription?.cancel()?.then((_) { print("RX subscription cleaned!");});
            rx = characteristic;
            print("Reseting RX subscription:"); 
            rxSubscription = characteristic.value.listen(_receiveMessage);
            Timer(Duration(seconds: 2), () async {
              print("READ FROM RX IF : ${rx}");
              await rx?.setNotifyValue(true); 
              await rx?.read(); 
            });
          }
          if (characteristic.uuid.toString() == txUUID) {
            txChar = characteristic;
            
            if(bridge != null) {
              final mtu = await bridge.mtu.first;
              try { await bridge.requestMtu(48); } catch (e) {
                // THis was failing on iOS and Mac
              }

              print("SETTING IS READY TO TRUE: (MTU: ${mtu})");
              isReadyToSend = true;
              networkName = bridge.name;

              
              changeStream.add(null);
            }
      
            // return;
          }
        }
        //print("Characteristic not found");
        changeStream.add(null);
        return;
      }
    }

    //print("Service not found");
    changeStream.add(null);
  }

  void reconnectToBridge() async {
    print("Reconnecting to bridge (brige is null? ${bridge == null }, isConnected: ${isConnected})");
    if (bridge == null)
      await scanAndConnect();
    else if (!isConnected)
      await connectToBridge();
  }

  void sendString(String message) async {

    print("Sending via BLE : " + message);

    await reconnectToBridge();
    print("Connected to bridge: ${isConnected}");

    if (txChar == null || !isReadyToSend) {
      print("Bridge is broken (tx characteristic not found), not sending (isReady: ${isReadyToSend})");
      return;
    }

   
    //for(int i=0;i<10 && isSending;i++) sleep(Duration(milliseconds: 100));

    print("IS SENDING BLE");
    try {
      isSending = true;
       await txChar.write(
          utf8.encode(
            message,
          ),
          withoutResponse: true);
    } on PlatformException catch (error) {
      print("Error writing : " + error.toString()+" : "+error.code.toString());
      print("Error sending Bluetooth command :\n${error.toString()}");
    } on Exception catch (error) {
      print("Error writing (exception) : " + error.toString());
      print("Error sending Bluetooth command :\n${error.toString()}");
    }

        print("DONE SENDING BLE");
    isSending = false;
  }

  void setNetworkName(String name) {
    sendString("g" + name + ",0");
    Bridge.isRestarting = true;
    isConnected = false;
    bridge = null;
  }


   void sendConfig({String networkName, String ssid, String password}) async {
    sendString("n${ssid ?? networkName},${password}");
    this.ssid = ssid;
    pass = password;
    
    // sleep(Duration(milliseconds: 40)); //safe between 2 calls
    // if(networkName.isEmpty) this.networkName = "*";

    // 0 for WiFi, 1 for BLE, 2 for Both:
    
    // if(this.networkName != networkName) {
    //   this.networkName = networkName;
    //   if(bridge != null) bridge.disconnect();
    //   print("Start scanning after 6 seconds:");
    //   Future.delayed(Duration(seconds:6),scanAndConnect);
    // }
  }  
}

class BLEConnectIcon extends StatefulWidget {
  BLEConnectIcon({Key key, this.manager}) : super(key: key) {}

  final BLEManager manager;

  @override
  _BLEConnectIconState createState() => _BLEConnectIconState(manager);
}

class _BLEConnectIconState extends State<BLEConnectIcon> {
  _BLEConnectIconState(BLEManager _manager) : manager = _manager {
    // connect();
    subscription = manager.changeStream.stream.listen((data) {
      // print("connection changed here, connected ? "+widget.manager.isConnected.toString()+", connecting ? "+widget.manager.isConnecting.toString());
      setState(() {});
    });
  }

  @override
  void dispose() {
    subscription?.cancel()?.then((_) { print("Scan subscription cleaned!");});
    super.dispose();
  }

  StreamSubscription<void> subscription;
  BLEManager manager;

  void connect() {
    print("CONNECT....");
    manager.scanAndConnect();
    
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onLongPress: () => showDialog(
            context: context,
            builder: (BuildContext context) =>
                BLEWifiSettingsDialog(manager: manager)),
        child: FloatingActionButton(
          onPressed: connect,
          child: Icon(Icons.link),
          backgroundColor: widget.manager.isConnected
              ? (widget.manager.isReadyToSend ? Colors.green : Colors.orange)
              : (widget.manager.isConnecting ? Colors.blue : Colors.red),
        ));
  }
}

class BLEWifiSettingsDialog extends StatefulWidget {
  BLEWifiSettingsDialog({Key key, this.manager}) : super(key: key) {}

  final BLEManager manager;

  @override
  BLEWifiSettingsDialogState createState() => BLEWifiSettingsDialogState();
}

class BLEWifiSettingsDialogState extends State<BLEWifiSettingsDialog> {
  BLEWifiSettingsDialogState({Key key});

  final TextEditingController ssidController = new TextEditingController();
  final TextEditingController passController = new TextEditingController();
  final TextEditingController nameController = new TextEditingController();

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
                        "Setup Device",
                        style: TextStyle(color: Color(0xffcccccc)),
                      )),
                  InputTF(controller: nameController, labelText: "Name",initialValue:widget.manager.networkName),
                  Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                       children: <Widget>[
                      for (BridgeMode m in BridgeMode.values)
                          Row(
                          children:<Widget>[
                            Radio<BridgeMode>(
                          value: m,
                          groupValue: widget.manager.bridgeMode,
                          activeColor: Colors.white,
                          onChanged: (BridgeMode value) {
                            setState(() {
                              widget.manager.bridgeMode = value;
                            });
                          },
                        ),
                        Text(
                           m.toString().split(".").last,
                              style: TextStyle(
                                color: Colors.white, fontSize: 12
                                )),
                          ])
                      
                    ]),
                  ),
                 
                 if (widget.manager.bridgeMode == BridgeMode.WiFi ||
                    widget.manager.bridgeMode == BridgeMode.Both)
                    Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: InputTF(
                          controller: ssidController, labelText: "SSID", initialValue: widget.manager.ssid,),
                    ),
                if (widget.manager.bridgeMode == BridgeMode.WiFi ||
                    widget.manager.bridgeMode == BridgeMode.Both)
                    Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: InputTF(
                          controller: passController, labelText: "Password", initialValue: widget.manager.pass),
                    ),
                    Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: RaisedButton(
                          child: Text("Save"),
                          onPressed: () {
                            widget.manager.sendConfig(
                              networkName: nameController.text,
                              password: passController.text,
                              ssid: ssidController.text,
                            );
                            Navigator.of(context).pop();
                          },
                        ))
              ],
            ),
        )
    );
  }
}

class InputTF extends StatelessWidget {
  InputTF({this.labelText, this.controller, this.initialValue})
  {
    controller.text = initialValue;
  }

  final labelText;
  final TextEditingController controller;
  final initialValue;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
        controller: controller,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
            contentPadding:EdgeInsets.fromLTRB(8, 0, 8, 0),
            labelText: labelText,
            labelStyle: TextStyle(color: Colors.white54),
            enabledBorder: new OutlineInputBorder(
                borderRadius: new BorderRadius.circular(2.0),
                borderSide: new BorderSide(color: Colors.grey))));
  }
}
