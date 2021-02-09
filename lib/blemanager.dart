import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum BridgeMode { WiFi, BLE, Both }

class BLEManager {
  FlutterBlue flutterBlue;
  BluetoothDevice bridge;

  bool isConnected = false;
  bool isConnecting = false;
  bool isScanning = false;
  bool isReadyToSend = false;
  bool isSending = false;

  StreamController<void> changeStream;

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
    changeStream = StreamController<void>.broadcast();
    bridgeMode = BridgeMode.Both;
    initBLE();
  }


  void initBLE() async {
    print("CHECK IF AVAILABLE?"); 
    FlutterBlue.instance.isAvailable.then((value) {
      print("IS AVAILABLE? ${value}"); 
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

  void sendPattern({int group, int page, int mode, int actives, List<double> paramValues}) {
    List<Object> args = new List<Object>();
    args.add(group);
    args.add(0);//groupIsPublic = false, force private group
    args.add(page);
    args.add(mode);
    args.add(actives);
    var values = paramValues.map((value) => (value*255).round());
    sendString("p${group},${page - 1},${mode - 1},${actives+1},${values.join(',')}");
  }

  void scanAndConnect() async {
    if (flutterBlue == null)
      return print("BLE not supported");
    sleep(Duration(milliseconds: 100));

    bridge = null;
    isConnected = false;
    changeStream.add(null);

    await flutterBlue.connectedDevices.then((devices) {
      print("DEVICES: ${devices.map((d) => d.name).join(", ")}");
      for (BluetoothDevice d in devices) {
        if (d.name.contains("FlowConnect")) {
          bridge = d;
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
       // connectToBridge();
      return;
    }

    //Not already there, start scanning

    if (isScanning) {
      print("Already scanning");
      return;
    }

    // print("CHECK IF ON");
    flutterBlue.isOn.then((isOn) {
      if (!isOn) {
        print("Bluetooth is not activated.");
        return;
      }
      print("Scanning devices...");
      
      print("SETTING BRIDGE TO NULL");
      bridge = null;
      isConnected = false;
      isConnecting = true;
      isReadyToSend = false;
      changeStream.add(null);
      flutterBlue.stopScan();

      flutterBlue
          .startScan(timeout: Duration(seconds: 5))
          .whenComplete(connectToBridge);

      subscription?.cancel();
      subscription = flutterBlue.scanResults.listen((scanResult) {
        // do something with scan result

        for (var result in scanResult) {
          //print('${result.device.name} found! rssi: ${result.rssi}');
          if (result.device.name.contains("FlowConnect")) {
            bridge = result.device;
            flutterBlue.stopScan();
            return;
          }
        }
      });
    });
  }

      StreamSubscription<List<ScanResult>> subscription;
  var stateSubscription;
  void connectToBridge() async {

    if (bridge == null) {
      //print("Bridge not found");
      print("No FlowConnect bridge found.");
      isConnected = false;
      isConnecting = false;
      changeStream.add(null);
      return;
    }

    print("Connect to bridge : " + bridge?.name);
    print(("Connecting to bridge..."));


    stateSubscription?.cancel();
    stateSubscription = bridge.state.listen((state) {
      // This is getting called a ton of times
      // 
      
      bool newConnected = state == BluetoothDeviceState.connected;
      isConnected = newConnected;
      if(isConnected) isConnecting = false;
      changeStream.add(null);

      if(isConnected || newConnected)
      {
        print((isConnected ? "Connected to " : "Disconnected from ") + bridge.name+".");
      }

      if (isConnected) {
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

  void getRXTXCharacteristics() async {
    print("Discover services");
    List<BluetoothService> services = await bridge.discoverServices();
    for (BluetoothService service in services) {
      if (service.uuid.toString() == uartUUID) {
        uartService = service;

        for (BluetoothCharacteristic characteristic in service.characteristics) {
          print("Characteristic : "+characteristic.uuid.toString());

          if (characteristic.uuid.toString() == txUUID) {
            txChar = characteristic;
            
            if(bridge != null) {
              final mtu = await bridge.mtu.first;
              try { await bridge.requestMtu(48); } catch (e) {
                // THis was failing on iOS and Mac
              }

              print("SETTING IS READY TO TRUE: (MTU: ${mtu})");
              isReadyToSend = true;
              networkName = bridge.name.substring(12);

              print("TRY TO LISTTEN TO TX!!!");
              // await characteristic.setNotifyValue(true);
              print("LISTTENING TO TX!!!");
              characteristic.value.listen((value) {
                print("RECEIVED FROM TX BLE: ${value}"); 
              });
              
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

  void sendString(String message) async {

    print("Sending : " + message);
   
    if (bridge == null)
      return scanAndConnect();
    else if (!isConnected) {
      print("Bridge is disconnected, reconnecting (brige is null? ${bridge == null })");
      await connectToBridge();
      return;
    }

    if (txChar == null || !isReadyToSend) {
      print("Bridge is broken (tx characteristic not found), not sending (isReady: ${isReadyToSend})");
      return;
    }

   
    //for(int i=0;i<10 && isSending;i++) sleep(Duration(milliseconds: 100));

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

    isSending = false;
  }


   void sendConfig({String networkName, String ssid, String password}) async 
   {
      sendString("n${ssid ?? networkName},${password}");
      this.ssid = ssid;
      pass = password;
      
      sleep(Duration(milliseconds: 40)); //safe between 2 calls
      if(networkName.isEmpty) this.networkName = "*";

      // 0 for WiFi, 1 for BLE, 2 for Both:
      sendString("g" + networkName + ",0");
      
      if(this.networkName != networkName)
      {
        this.networkName = networkName;
        if(bridge != null) bridge.disconnect();
        print("Start scanning after 6 seconds:");
        Future.delayed(Duration(seconds:6),scanAndConnect);
      }
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
    subscription.cancel();
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
