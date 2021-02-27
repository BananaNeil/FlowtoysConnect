import 'package:flutter/material.dart';

class HorizontalLineShadow extends StatelessWidget {
  HorizontalLineShadow({this.spreadRadius, this.blurRadius, this.color});

  Color color;
  double blurRadius;
  double spreadRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: color ?? Color(0xAA000000),
            spreadRadius: spreadRadius ?? 2.0,
            blurRadius: blurRadius ?? 2.0,
          ),
        ]
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
        )
      )
    );
  }

}
