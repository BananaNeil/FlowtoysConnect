import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:app/components/navigation.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/blemanager.dart';

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
  BLEManager ble;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Navigation(),
      appBar: AppBar(
        title: Text('Find Devices'),
        backgroundColor: Color(0xff222222),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            FlutterBlue.instance.startScan(timeout: Duration(seconds: 4)),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              StreamBuilder<List<BluetoothDevice>>(
                stream: Stream.periodic(Duration(seconds: 2))
                    .asyncMap((_) => FlutterBlue.instance.connectedDevices),
                initialData: [],
                builder: (c, snapshot) => Column(
                  children: snapshot.data.map((d) => ListTile(
                    title: Text(d.name),
                    subtitle: Text(d.id.toString()),
                    trailing: StreamBuilder<BluetoothDeviceState>(
                      stream: d.state,
                      initialData: BluetoothDeviceState.disconnected,
                      builder: (c, snapshot) {
                        if (snapshot.data ==
                            BluetoothDeviceState.connected) {
                          return RaisedButton(
                            child: Text('OPEN'),
                            onPressed: () {}
                          );
                        }
                        return Text(snapshot.data.toString());
                      },
                    ),
                  )).toList(),
                ),
              ),
              StreamBuilder<List<ScanResult>>(
                stream: FlutterBlue.instance.scanResults,
                initialData: [],
                builder: (c, snapshot) => Column(
                  children: snapshot.data.map((r) => Text("${r.device.id} - ${r.device.name}")).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: StreamBuilder<bool>(
        stream: FlutterBlue.instance.isScanning,
        initialData: false,
        builder: (c, snapshot) {
          if (snapshot.data) {
            return FloatingActionButton(
              child: Icon(Icons.stop),
              onPressed: () => FlutterBlue.instance.stopScan(),
              backgroundColor: Colors.red,
            );
          } else {
            return FloatingActionButton(
                child: Icon(Icons.search),
                onPressed: () => FlutterBlue.instance
                    .startScan(timeout: Duration(seconds: 4)));
          }
        },
      ),
    );
  }

}




