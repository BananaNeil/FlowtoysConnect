import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:app/components/edit_show_widget.dart';
import 'package:app/components/timeline_widget.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/models/show.dart';
import 'package:app/client.dart';

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
  String errorMessage;
  bool isEditing = false;

  @override initState() {
    super.initState();
  }

  fetchShow() {
    Client.getShow(show?.id).then((response) {
      setState(() {
        if (response['success']) {
          show = response['show'];
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    var arguments = (ModalRoute.of(context).settings.arguments as Map);
    if (arguments != null)
      show ??= arguments['show'];

    if (show == null) fetchShow();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(show?.name ?? "Loading"),
        backgroundColor: Color(0xff222222),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, "/shows/${show.id}/edit", arguments: {
                'show': show,
              }).then((_) {
                setState(() {}); 
              });
            }
          ),
        ],
      ),
      body: show == null ?
        SpinKitCircle(color: Colors.blue) : TimelineWidget(
          messageColor: arguments['messageColor'],
          reloadPage: () => setState((){}),
          message: arguments['message'],
          show: show,
        )
    );
  }

}
