import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:app/components/edit_show_widget.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/models/show.dart';
import 'package:app/models/mode.dart';

class NewShow extends StatelessWidget {
  NewShow();

  @override
  Widget build(BuildContext context) {
    return NewShowState();
  }
}

class NewShowState extends StatefulWidget {
  NewShowState({Key key}) : super(key: key);

  @override
  _NewShowState createState() => _NewShowState();
}

class _NewShowState extends State<NewShowState> {

  Show show;
  String errorMessage;
  bool _saved = false;
  bool isEditing = false;

  @override
  Widget build(BuildContext context) {
    show = show ?? Show.create();
    var arguments = (ModalRoute.of(context).settings.arguments as Map);
    List<Mode> modes;
    if (arguments != null) {
      if (show.modeTracks.isEmpty)
        modes = List<Mode>.from(arguments['modes']);
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text("Create New Show"),
        backgroundColor: Color(0xff222222),
        leading: new IconButton(
          icon: new Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, _saved);
          },
        ),
      ),
      body: EditShowWidget(
        show: show,
        modes: modes,
        onSave: (_) => _saved = true,
        canEditShowDuration: true
      )
    );
  }

}

