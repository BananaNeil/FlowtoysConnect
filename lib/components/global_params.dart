import 'package:app/components/horizontal_line_shadow.dart';
import 'package:app/components/inline_mode_params.dart';
import 'package:app/helpers/animated_clip_rect.dart';
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
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF262626),
                    Color(0xFF1A1A1A),
                    Colors.black,
                  ]
                ),
              ),
              // decoration: BoxDecoration(
              //   image: DecorationImage(
              //     image: AssetImage("assets/images/dark-texture.jpg"),
              //     repeat: ImageRepeat.repeat,
              //     fit: BoxFit.none,
              //     scale: 2,
              //   ),
              // )
            )
          ),
          Column(
            children: [
              _Header(),
              HorizontalLineShadow(),
              AnimatedClipRect(
                curve: Curves.easeInOut,
                verticalAnimation: true,
                horizontalAnimation: false,
                alignment: Alignment.topCenter,
                open: Mode.globalParamsEnabled,
                duration: Duration(milliseconds: 200),
                child: _ExpandedContent(),
              )
            ]
          )
        ]
      )
    );
  }

  Widget _ExpandedContent() {
    return Container(
      child: Container(
        margin: EdgeInsets.only(
          right: isSmall ? 10 : 30,
          bottom: 14,
          left: 10,
          top: 5,
        ),
        child: _InlineParams(),
      ),
    );
  }

  Widget _Header() {
    return GestureDetector(
      onTap: () {
        Mode.globalParamsEnabled = !Mode.globalParamsEnabled;
        setState(() {});
      },
      child: Container(
        padding: EdgeInsets.all(5),
        decoration: BoxDecoration(
            color: Color(0xFF222222),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Checkbox(
              value: Mode.globalParamsEnabled,
              activeColor: Colors.blue,
              onChanged: (value) {
                Mode.globalParamsEnabled = value;
                setState(() {});
              }
            ),
            Text("Global Params", style: TextStyle(fontSize: 18)),
          ]
        ),
      ),
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


