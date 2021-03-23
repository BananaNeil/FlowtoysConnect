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
import 'package:app/authentication.dart';
import 'package:app/models/sync_packet.dart';

import 'package:shared_preferences/shared_preferences.dart';

enum BridgeMode { WiFi, BLE, Both }

class BLEManager {
  Set<BluetoothDevice> bridges = Set<BluetoothDevice>();
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
        periodicallyAttemptReconnect();
        return;
      }

      if (flutterBlue == null) {
        flutterBlue = FlutterBlue.instance;

        flutterBlue.isScanning.listen((result) {
          isScanning = result;
          changeStream?.add(null);
        });
      }

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
    else if (bridges.length == 0)
      return "Searching via Bluetooth...";
  }

  set statusMessage(message) {
    changeStream.add(null);
    _statusMessage = message;
  }

  bool isOff = false;

  void factoryReset() {
    bridges.remove(bridge);
    Authentication.currentAccount.bridgeBleIds.remove(bridge.id.toString());
    Authentication.saveAccountToDisk();
    sendString('R');
  }

  void scanAndConnect() async {
    if (flutterBlue == null)
      return initBLE();

    // sleep(Duration(milliseconds: 100));

    bridges = Set<BluetoothDevice>();
    isConnected = false;

    await flutterBlue.connectedDevices.then((devices) {
      for (BluetoothDevice device in devices) {
        
        print("BRIDGE ID::::: ${device.id.toString()}");

        if (device.name.contains("FlowConnect")) {
          bridges.add(device);
        }
      }
    }).catchError((error) {
      print("Searching for devices failed: ${error}");
    });

    // if (bridge != null) {
    //   print("Already connected but not assigned (${txChar != null})");
    //   isConnected = false;
    //   isReadyToSend = txChar != null;
    //    connectToBridge();
    //   return;
    // }

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
          print("**BRIDGE ID::::: ${result.device.id.toString()}");
          if (result.device.name.contains("FlowConnect")) {
            bridges.add(result.device);
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
    if (bridges.length == 0) {
      //print("Bridge not found");
      print("No FlowConnect bridge found via BLE.");
      isConnected = false;
      isConnecting = false;
      changeStream.add(null);
      periodicallyAttemptReconnect();
      return;
    }

    // print("BLE: Connect to bridge : " + bridge?.name);
    // print("BLE: Connecting to bridge...");




    if (Authentication.isAuthenticated && !isConnected)
      bridges.forEach((bridge) {
        if (Authentication.currentAccount.bridgeBleIds.contains(bridge.id.toString()))
          connect(bridge);
      });
  }

  
  void connect(newBridge) async {
    if (newBridge == null) return;

    stateSubscription?.cancel();
    stateSubscription = newBridge.state.listen((state) async {
      
      // Okay.... this is getting called when the bridge crashes. Then seconds later, we are trying to read from rx.
      // We need to set isConnected (done, I think), and let rx reading be conditional on that.

      print("Bridge connection state change: ${state} ...");
      isConnected = state == BluetoothDeviceState.connected;
      if (isConnected) isConnecting = false;

      if(state == BluetoothDeviceState.disconnected || state == BluetoothDeviceState.disconnecting) {
        await scanAndConnect();
      } else {
        Bridge.bleId = newBridge.id.toString();
        Bridge.name = newBridge.name;
        bridge = newBridge;
        Bridge.save();
      }

      print((isConnected ? "Connected to " : "Disconnected from ") + newBridge.name+".");

      changeStream.add(null);

      if (isConnected) {
        resetReconnectionTimeOut();
        getRXTXCharacteristics();
      }
    });

    try {
      await newBridge.connect();
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
    if (!isConnected)
      await scanAndConnect();
    // else if ()
    //   await connectToBridge();
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
  }  
}

