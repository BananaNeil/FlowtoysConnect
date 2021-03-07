import 'package:app/components/inline_mode_params.dart';
import 'package:app/components/horizontal_line_shadow.dart';
import 'package:app/app_controller.dart';
import 'package:app/models/bridge.dart';
import 'package:flutter/material.dart';
import 'package:app/models/group.dart';
import 'package:app/models/mode.dart';
import 'dart:async';

class GlobalParams extends StatefulWidget {
  GlobalParams();

  @override
  _GlobalParams createState() => _GlobalParams();
}

class _GlobalParams extends State<StatefulWidget> {
  _GlobalParams();

  @override
  initState() {
    super.initState();
  }

  double get containerWidth => AppController.screenWidth;
  bool get isSmall => containerWidth <= 450;
  bool get isXSmall => containerWidth <= 380;

  @override
  build(BuildContext context) {
    return Container(
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/images/dark-texture.jpg"),
                  repeat: ImageRepeat.repeat,
                  fit: BoxFit.none,
                  scale: 2,
                ),
              )
            )
          ),
          HorizontalLineShadow(),
          Column(
            children: [
              Row(
                children: [
                  Text("Global Params"),
                  Checkbox(
                    value: Mode.globalParamsEnabled,
                    activeColor: Colors.blue,
                    onChanged: (value) {
                      Mode.globalParamsEnabled = value;
                    }
                  )
                ]
              ),
              Container(
                child: Container(
                  margin: EdgeInsets.only(
                    right: isSmall ? 10 : 30,
                    bottom: 14,
                    left: 10,
                    top: 5,
                  ),
                  child: _InlineParams(),
                ),
              ),
            ]
          )
        ]
      )
    );
  }
  Timer _adjustingInlineParamTimer;
  Widget _InlineParams() {
    return InlineModeParams(
      mode: Mode.global,
      onTouchDown: () {
        _adjustingInlineParamTimer?.cancel();
        // widget.isAdjustingInlineParam(true);
      },
      onTouchUp: () {
        // _adjustingInlineParamTimer = Timer(Duration(seconds: 1), () => widget.isAdjustingInlineParam(false));
        Group.currentProps.forEach((prop) => prop.refreshMode());
        setState(() {});
      },
      updateMode: () {
        Group.currentProps.forEach((prop) => prop.refreshMode());
        // (Prop.propsByModeId[mode.id] ?? []).forEach((prop) => prop.currentMode = mode );
      },
    );
  }
}


