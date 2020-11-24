import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';

class ActionButton extends StatelessWidget {
  ActionButton({this.text, this.child, this.onPressed, this.visible, this.margin, this.rightMargin});

  final text;
  final child;
  final margin;
  final visible;
  final onPressed;
  final rightMargin;

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: visible ?? true,
      child: Container(
        height: 40,
        width: child != null ? 40 : null,
        margin: margin ?? EdgeInsets.only(top: 10, right: rightMargin ?? 0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: child != null ? FloatingActionButton(
          backgroundColor: AppController.darkGrey,
          onPressed: onPressed,
          heroTag: "icon child",
          child: child,
        ) : FloatingActionButton.extended(
          backgroundColor: AppController.darkGrey,
          label: Text(text, style: TextStyle(color: Colors.white)),
          heroTag: text,
          onPressed: onPressed,
        ),
      )
    );
  }

}

