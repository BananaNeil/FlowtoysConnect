import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:app/components/edit_show_widget.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/models/show.dart';
import 'package:app/models/mode.dart';

class NewSubShow extends StatelessWidget {
  NewSubShow();

  @override
  Widget build(BuildContext context) {
    return NewSubShowState();
  }
}

class NewSubShowState extends StatefulWidget {
  NewSubShowState({Key key}) : super(key: key);

  @override
  _NewSubShowState createState() => _NewSubShowState();
}

class _NewSubShowState extends State<NewSubShowState> {

  Show show;
  String errorMessage;
  bool _saved = false;
  bool isEditing = false;

  @override
  Widget build(BuildContext context) {
    show = show ?? Show.create();
    var arguments = (ModalRoute.of(context).settings.arguments as Map);
    if (!show.hasDefinedDuration)
      show.setDuration(arguments['duration']);
    List<Mode> modes;
    if (arguments != null)
      modes = List<Mode>.from(arguments['modes']);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text("Generate Mode Cycle"),
        backgroundColor: Color(0xff222222),
        leading: new IconButton(
          icon: new Icon(Icons.close),
          onPressed: () {
            Navigator.pop(context, _saved);
          },
        ),
      ),
      body: EditShowWidget(
        show: show,
        modes: modes,
        bpm: arguments['bpm'],
        onSave: (_) => _saved = true,
        onlyShowCycleGeneration: true,
        canEditShowDuration: arguments['duration'] == null,
      )
    );
  }

}


