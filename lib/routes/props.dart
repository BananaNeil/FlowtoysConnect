import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:app/components/edit_groups.dart';
import 'package:app/components/navigation.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/client.dart';

class Props extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PropsPage(title: 'Props');
  }
}

class PropsPage extends StatefulWidget {
  PropsPage({Key key, this.title}) : super(key: key);
  String title;

  @override
  _PropsPageState createState() => _PropsPageState();
}

class _PropsPageState extends State<PropsPage> {

  bool awaitingResponse = false;
  String errorMessage;

  @override initState() {
    super.initState();
  }


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: AppController.closeKeyboard,
      child: Scaffold(
        drawer: Navigation(),
        appBar: AppBar(
          title: Text("Connect Props"),
          backgroundColor: Color(0xff222222),
        ),
        body: Center(
          child: EditGroups(),
        )
      )
    );
  }
}


