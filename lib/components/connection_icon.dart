import 'package:flutter/material.dart';

class ConnectionIcon extends StatefulWidget {
  ConnectionIcon({
    Key key,
    this.isConnected,
    this.connectedIcon,
    this.disconnectedIcon,
  }) : super(key: key);

  bool isConnected;
  Widget connectedIcon;
  Widget disconnectedIcon;

  @override
  _ConnectionIcon createState() => _ConnectionIcon();

}


class _ConnectionIcon extends State<ConnectionIcon> {
  _ConnectionIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 35,
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(widget.isConnected ? Colors.blue : Colors.white, BlendMode.srcATop),
        child: widget.isConnected ? widget.connectedIcon : widget.disconnectedIcon,
      ),
    );
  }
}
