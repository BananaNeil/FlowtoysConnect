import 'dart:async';

import 'package:app/groupselection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/pagemodegrid.dart';
import 'package:app/blemanager.dart';
import 'package:app/oscmanager.dart';


import 'package:app/app_controller.dart';
import 'package:app/components/navigation.dart';

class Research extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ResearchPage(title: "Ben's Research");
  }
}

class ResearchPage extends StatefulWidget {
  ResearchPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _ResearchPageState createState() => _ResearchPageState();
}

enum ConnectionMode { BLE, OSC }

class _ResearchPageState extends State<ResearchPage> {
  int selectedGroup = 0;
  ConnectionMode mode;
  BLEManager bleManager;
  OSCManager oscManager;

  //flow control
  String patternCommand;
  String lastPatternCommand;
  Timer patternTimer;

  //ui
  ScrollController scrollController;

  bool dialVisible = true;

  SharedPreferences prefs;

  _ResearchPageState() {
    bleManager = AppController.bleManager;
    oscManager = new OSCManager();

    patternTimer = Timer.periodic(Duration(milliseconds: 50), (timer) {
      sendPatternIfChanged();
    });
    /*scrollController = ScrollController()
      ..addListener(() {
        setDialVisible(scrollController.position.userScrollDirection ==
            ScrollDirection.forward);
      });*/

    loadPreferences();
  }

  void loadPreferences() async {
    if (prefs == null) prefs = await SharedPreferences.getInstance();
    int m = prefs.getInt("mode");
    print("mode loaded " + m.toString());
    setMode(m != null ? ConnectionMode.values[m] : ConnectionMode.BLE);
  }

  void setMode(ConnectionMode _mode) {
    setState(() {
      if (mode == _mode) return;

      mode = _mode;
      if (mode == ConnectionMode.OSC) {
        bleManager.bridge?.disconnect();
      } else {
        // bleManager.scanAndConnect();
      }
    });

    print("Mode is now " + mode.toString());
    prefs.setInt("mode", ConnectionMode.values.indexOf(mode));
  }

  /* helper */

  /* BRIDGE API FUNCTIONS */

  void wakeUp() {
    if (mode == ConnectionMode.BLE) {
      bleManager.sendString("w" + selectedGroup.toString());
    } else {
      oscManager.sendGroupMessage("/wakeUp", selectedGroup);
    }
  }

  void powerOff() {
    if (mode == ConnectionMode.BLE) {
      bleManager.sendString("z" + selectedGroup.toString());
    } else {
      oscManager.sendGroupMessage("/powerOff", selectedGroup);
    }
  }

  void syncGroups() {
    if (mode == ConnectionMode.BLE) {
      bleManager.sendString("s0"); //infinite
    } else {
      oscManager.sendSync(0);
    }
  }

  void stopSync() {
    if (mode == ConnectionMode.BLE) {
      bleManager.sendString("S");
    } else {
      oscManager.sendSimpleMessage("/stopSync");
    }
  }

  void setPattern(
      int page, int _mode, List<bool> paramEnables, List<double> paramValues) {
    int actives = 0;
    String values = "";
    for (int i = 0; i < paramEnables.length; i++) {
      actives += (paramEnables[i] ? 1 : 0) << (i + 1);
      values += (i > 0 ? "," : "") + (paramValues[i] * 255).round().toString();
    }

    if (mode == ConnectionMode.BLE) {
      patternCommand = "p" +
          selectedGroup.toString() +
          "," +
          page.toString() +
          "," +
          _mode.toString() +
          "," +
          actives.toString() +
          "," +
          values;
    } else {
      oscManager.sendPattern(
        paramValues: paramValues,
        group: selectedGroup,
        actives: actives,
        mode: _mode,
        page: page,
      );
    }
  }

  void sendPatternIfChanged() {
    if (mode == ConnectionMode.OSC) return;
    if (lastPatternCommand == patternCommand) return;
    bleManager.sendString(patternCommand);
    lastPatternCommand = patternCommand;
  }

  //UI
  void setDialVisible(bool value) {
    if (dialVisible == value) return;
    setState(() {
      dialVisible = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        drawer: Navigation(),
        backgroundColor: Color(0xff333333),
        appBar: AppBar(
            title: Text(widget.title), backgroundColor: Color(0xff222222)),
        body: 
        Padding(
          padding:EdgeInsets.fromLTRB(0,0,0,80),
          child:Center(
          child: Column(
            children: [
              GroupSelection(
                onGroupChanged: (group) {
                  selectedGroup = group;
                },
              ),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    CommandButton(
                        text: "Wake Up",
                        onPressed: wakeUp,
                        color: Colors.green),
                    CommandButton(
                        text: "Power off",
                        onPressed: powerOff,
                        color: Colors.red),
                    CommandButton(
                        text: "Start sync",
                        onPressed: syncGroups,
                        color: Colors.blue),
                    CommandButton(
                        text: "Stop sync",
                        onPressed: stopSync,
                        color: Colors.purple),
                  ]),
              Expanded(
                  child: PageModeSelection(
                scrollController: scrollController,
                onPageModeChanged: setPattern,
              )),
            ],
          ),
        ),
        ),
        floatingActionButton: Stack(
          children: <Widget>[
            if (dialVisible)
              Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: 70),
                    child: mode == ConnectionMode.BLE
                        ? BLEConnectIcon(manager: bleManager)
                        : OSCSettingsIcon(manager: oscManager),
                  )),
            SpeedDial(
              child: Icon(
                  mode == ConnectionMode.BLE ? Icons.bluetooth : Icons.wifi),
              visible: dialVisible,
              closeManually: false,
              tooltip: 'Choose your connection',
              heroTag: 'speed-dial-hero-tag',
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 32.0,
              curve: Curves.bounceInOut,
              overlayColor: Colors.black,
              overlayOpacity: 0.5,
              shape: CircleBorder(),
              children: [
                SpeedDialChild(
                    child: Icon(Icons.bluetooth),
                    label: 'Bluetooth',
                    labelStyle: TextStyle(fontSize: 18.0),
                    onTap: () {
                      setMode(ConnectionMode.BLE);
                    }),
                SpeedDialChild(
                  child: Icon(Icons.wifi),
                  label: 'OSC',
                  labelStyle: TextStyle(fontSize: 18.0),
                  onTap: () {
                    setMode(ConnectionMode.OSC);
                  },
                )
              ],
            )
          ],
        ));
  }
}

class CommandButton extends StatelessWidget {
  const CommandButton({this.text, this.onPressed, this.color});

  final String text;
  final Function onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ButtonTheme(
      minWidth: 80.0,
      child: RaisedButton(
        onPressed: onPressed,
        padding: const EdgeInsets.all(0),
        child: Text(
          text,
          style: TextStyle(fontSize: 14),
        ),
        color: color,
        textColor: Colors.white70,
        splashColor: Colors.white70,
      ),
    );
  }
}

