import 'package:flutter_hsvcolor_picker/flutter_hsvcolor_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:app/components/edit_mode_widget.dart';
import 'package:app/components/mode_widget.dart';
import 'package:app/models/mode_param.dart';
import 'package:app/models/base_mode.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/models/mode.dart';

import 'package:app/models/group.dart';
import 'package:app/client.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class EditMode extends StatelessWidget {
  EditMode({this.id, this.mode});

  final String id; 
  final Mode mode; 

  @override
  Widget build(BuildContext context) {
    return EditModePage(id: id, mode: mode);
  }
}

class EditModePage extends StatefulWidget {
  EditModePage({Key key, this.id, this.mode}) : super(key: key);
  final String id;
  final Mode mode;

  @override
  _EditModePageState createState() => _EditModePageState(id: id, mode: mode);
}

class _EditModePageState extends State<EditModePage> {
  _EditModePageState({this.id, this.mode});

  String id;

  bool awaitingSave = false;
  bool awaitingResponse = false;
  String errorMessage;
  Mode mode;

  HSVColor color = HSVColor.fromColor(Colors.blue);

  Future<void> _fetchMode() {
    setState(() { awaitingResponse = true; });
    return Client.getMode(id).then((response) {
      setState(() {
        if (response['success']) {
          awaitingResponse = false;
          mode = response['mode'];
          errorMessage = null;
        } else errorMessage = response['message'];
      });
    });
  }

  @override initState() {
    if (id == 'null') id = null;
    super.initState();
    if (id != null)
      _fetchMode();
  }

  @override
  Widget build(BuildContext context) {
    mode = mode ?? AppController.getParams(context)['mode'] ?? null;
    var saveMessage = AppController.getParams(context)['saveMessage'] ?? null;

    return GestureDetector(
      onTap: AppController.closeKeyboard,
      child: Scaffold(
        // floatingActionButton: _FloatingActionButton(),
        backgroundColor: AppController.darkGrey,
        appBar: AppBar(
          title: Text(mode?.name ?? (id == null ? "Edit" : "Loading...")), backgroundColor: Color(0xff222222),
          leading: new IconButton(
            icon: new Icon(Icons.close),
            onPressed: () {
              Navigator.pop(context, null);
            },
          ),
          actions: <Widget>[
            GestureDetector(
              child: Container(
                padding: EdgeInsets.all(18),
                child: awaitingSave ? SpinKitCircle(color: Colors.white) :
                  Text(
                    saveMessage ?? 'SAVE',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      fontSize: 16,
                    )
                  ),
              ),
              onTap: () {
                Navigator.pop(context, true);
              }
            )
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Visibility(
                visible: errorMessage != null,
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Text(errorMessage ?? "", textAlign: TextAlign.center, style: TextStyle(color: AppController.red)),
                )
              ),
              Container(
                margin: EdgeInsets.symmetric(vertical: 10),
                child: ModeImage(
                  mode: mode,
                  size: 80.0,
                )
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchMode,
                  child: EditModeWidget(
                    autoUpdate: false,
                    editDetails: true,
                    mode: mode,
                    onChange: (_mode) {
                      setState(() {
                        mode = _mode;
                      });
                    },
                  )
                ),
              ),
            ],
          ),
        ),
      )
    );
  }
}
