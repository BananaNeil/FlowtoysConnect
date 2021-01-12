import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:app/components/navigation.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';

class NeilsResearch extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return NeilsResearchPage(title: 'NeilsResearch');
  }
}

class NeilsResearchPage extends StatefulWidget {
  NeilsResearchPage({Key key, this.title}) : super(key: key);
  String title;

  @override
  _NeilsResearchPageState createState() => _NeilsResearchPageState();
}

class _NeilsResearchPageState extends State<NeilsResearchPage> {


  @override initState() {

    super.initState();
  }

  List<BluetoothDevice> devices = [];
  FlutterBlue flutterBlue;


  Future scanDevices() {
    flutterBlue = FlutterBlue.instance;
    if (flutterBlue == null)  {
      Fluttertoast.showToast(msg: "BLE not supported");
      return Future.value(false);
    }

    return flutterBlue.isOn.then((isOn) {
      if (!isOn) {
        Fluttertoast.showToast(msg: "Bluetooth is not activated.");
        return Future.value(false);
      }
      Fluttertoast.showToast(msg: "Scanning devices...");




      return flutterBlue.connectedDevices.then((devices) {
        Fluttertoast.showToast(msg: "DEVICES: ${devices.map((d) => d.name).join(", ")}");
        for (BluetoothDevice device in devices) {
          devices.add(device);
        }
      }).catchError((error) {
        Fluttertoast.showToast(msg: "Searching for devices failed: ${error}");
      });




    //   flutterBlue.startScan(timeout: Duration(seconds: 10));
    //
    //   flutterBlue.scanResults.listen((scanResult) {
    //     // do something with scan result
    //
    //     for (var result in scanResult) {
    //       //print('${result.device.name} found! rssi: ${result.rssi}');
    //       devices.add(result.device);
    //       // if (result.device.name.contains("FlowConnect")) {
    //       //   bridge = result.device;
    //       //   // flutterBlue.stopScan();
    //       //   return;
    //       // }
    //     }
    //     setState(() {});
    //   });
    }).catchError((e) {
      Fluttertoast.showToast(msg: "Checking if flutterBlue.isOn failed: ${e}");
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: AppController.closeKeyboard,
      child: Scaffold(
        backgroundColor: AppController.darkGrey,
        drawer: Navigation(),
        appBar: AppBar(
          title: Text("NEil's research"),
          backgroundColor: Color(0xff222222),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: RefreshIndicator(
                  onRefresh: scanDevices,
                  child: ListView(
                    padding: EdgeInsets.only(top: 5),
                    children: [
                      ..._Devices(),
                    ]
                  ),
                ),
              )
            ],
          ),
        ),
      )
    );
  }

  List<Widget> _Devices() {
    return devices.map((device) {
      return Card(
        elevation: 8.0,
        child: ListTile(
          title: Container(
            margin: EdgeInsets.only(bottom: 5),
            child: Text(device.name)
          )
        )
      );
    }).toList();
  }


}



