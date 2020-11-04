import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:app/components/edit_show_widget.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/models/show.dart';
import 'package:app/models/mode.dart';
import 'package:app/client.dart';

class EditShow extends StatelessWidget {
  EditShow({this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return EditShowState(id: id);
  }
}

class EditShowState extends StatefulWidget {
  EditShowState({Key key, this.id}) : super(key: key);
  final String id;

  @override
  _EditShowState createState() => _EditShowState(id);
}

class _EditShowState extends State<EditShowState> {
  _EditShowState(this.id);
  String id;

  Show show;
  String errorMessage;
  bool isEditing = false;

  fetchShow() {
    Client.getShow(id).then((response) {
      setState(() {
        if (response['success'])
          show = response['show'];
      });
    });
  }

  @override
  void initState() {
    super.initState();
    fetchShow();
  }

  @override
  Widget build(BuildContext context) {
    var arguments = (ModalRoute.of(context).settings.arguments as Map);
    if (arguments != null)
      show = arguments['show'];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text("Edit ${show.name}"),
        backgroundColor: Color(0xff222222),
        leading: new IconButton(
          icon: new Icon(Icons.close),
          onPressed: () {
            Navigator.pop(context, null);
          },
        ),
      ),
      body: EditShowWidget(show: show)
    );
  }

}


