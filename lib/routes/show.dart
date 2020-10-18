import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:app/components/edit_show_widget.dart';
import 'package:app/components/timeline_widget.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/models/show.dart';
import 'package:app/models/mode.dart';

class ShowPage extends StatelessWidget {
  ShowPage({this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return ShowPageState(id: id);
  }
}

class ShowPageState extends StatefulWidget {
  ShowPageState({Key key, this.id}) : super(key: key);
  final String id;

  @override
  _ShowPageState createState() => _ShowPageState(id);
}

class _ShowPageState extends State<ShowPageState> {
  _ShowPageState(this.id);
  String id;

  Show show;
  List<Mode> modes;
  String errorMessage;
  bool isEditing = false;

  @override
  Widget build(BuildContext context) {
    var arguments = (ModalRoute.of(context).settings.arguments as Map);
    if (arguments != null) {
      modes = arguments['modes'];
      show = arguments['show'];
    }
    show = show ?? Show.create();
    print("ID: ${show.id}");

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(show.name ?? "New Show"),
        backgroundColor: Color(0xff222222),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.edit),
          ),
        ],
      ),
      body: !show.isPersisted || isEditing ?
        EditShowWidget(show: show, modes: modes) :
        TimelineWidget(show: show)
    );
  }

}
