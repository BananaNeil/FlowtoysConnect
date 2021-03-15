import 'package:app/authentication.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RenameController {
  String newName;


  void set possessivePrefix(value) {
    prefix = "${value}'";
    // If the last letter of the user's name is an 's', only add an aprostrophe
    if (!RegExp(r"s\'").hasMatch(prefix))
      prefix += "s";
  }

  String _prefix;
  String get prefix => _prefix;
  void set prefix(value) {
    _prefix = value;
    newName = "${prefix} ${suffix}";
  }



  String _suffix = "";
  String get suffix => _suffix;
  void set suffix(value) {
    _suffix = value;
    newName = "${prefix} ${suffix}";
  }

}

class RenameForm extends StatefulWidget {
  RenameForm({this.controller, Key key}) : super(key: key);

  RenameController controller;

  @override
  _RenameForm createState() => _RenameForm();
}

class _RenameForm extends State<RenameForm> {
  _RenameForm();

  @override
  initState() {
    super.initState();
  }

  @override
  dispose() {
    super.dispose();
  }

  String get newName => widget.controller.newName;
  set newName(value) => widget.controller.newName = value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      // height: 200,
      margin: EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.only(top: 5, bottom: 5),
            padding: EdgeInsets.only(top: 25, bottom: 25),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
            ),
            width: double.infinity,
            child: Text(newName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                color: Colors.white,
              )
            ),
          ),
          Container(
            child: TextFormField(
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp("[a-zA-Z0-9 '+()?<>]")),
              ],
              textAlign: TextAlign.center,
              // initialValue: ,
              decoration: InputDecoration(
                hintText: 'Or enter a custom name here...',
              ),
              onChanged: (text) {
                setState(() {
                  if (text == '') {
                    widget.controller.possessivePrefix = Authentication.currentAccount.firstName;
                  } else widget.controller.prefix = text;
                });
              }
            )
          ),
        ]
      )
    );
  }
}

