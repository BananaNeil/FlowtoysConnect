import 'package:app/components/horizontal_line_shadow.dart';
import 'package:app/components/inline_mode_params.dart';
import 'package:app/components/modes_filter_bar.dart';
import 'package:app/helpers/animated_clip_rect.dart';
import 'package:app/helpers/filter_controller.dart';
import 'package:app/app_controller.dart';
import 'package:app/models/bridge.dart';
import 'package:flutter/material.dart';
import 'package:app/models/group.dart';
import 'package:app/models/mode.dart';
import 'dart:async';

class GlobalParams extends StatefulWidget {
  GlobalParams({this.filterController});

  FilterController filterController;

  @override
  _GlobalParams createState() => _GlobalParams();
}

class _GlobalParams extends State<GlobalParams> {
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
      decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
                color: Color(0xAA000000),
                spreadRadius: 4.0,
                blurRadius: 4.0,
            )
          ]
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment(0, isExpanded ? 1 : 2),
                  colors: [
                    Color(0xFF262626),
                    Color(0xFF1A1A1A),
                    Colors.black,
                  ]
                ),
              ),
            )
          ),
          Column(
            children: [
              _Header(),
              HorizontalLineShadow(),
              _Filters(),
              _Params(),
            ]
          ),
          Positioned.fill(
            child: Align(
              alignment: FractionalOffset.bottomCenter,
              child: _DragHandle(),
            )
          )
        ]
      )
    );
  }

  Widget _Params() {
    return AnimatedClipRect(
      open: paramsExpanded,
      curve: Curves.easeInOut,
      verticalAnimation: true,
      horizontalAnimation: false,
      alignment: Alignment.topCenter,
      duration: Duration(milliseconds: 200),
      child: _ExpandedContent(),
    );
  }

  Widget _Filters() {
    return ModesFilterBar(
      filterController: widget.filterController,
      expanded: filtersExpanded,
    );
  }

  Widget _ExpandedContent() {
    return Column(
      children: [
        Container(
          margin: EdgeInsets.only(
            right: isSmall ? 10 : 30,
            bottom: 14,
            left: 10,
            top: 5,
          ),
          child: _InlineParams(),
        ),
      ]
    );
  }

  bool get isExpanded => paramsExpanded || filtersExpanded;
  bool filtersExpanded = false;
  bool paramsExpanded = false;
  bool _isAnimating = false;
  bool get isAnimating => _isAnimating;
  void set isAnimating(value) {
    _isAnimating = value;
    if (value)
      Timer(Duration(milliseconds: 200), () {
        setState(() =>isAnimating = false);
      });
  }


  Widget _DragHandle() {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: (details) {  
        if (isAnimating) return;
        if (details.delta.dy > 8) { // swipe Down
          if (!paramsExpanded || !filtersExpanded)
            isAnimating = true;
          if (!paramsExpanded)
            paramsExpanded = true;
          else filtersExpanded = true;
        } else if(details.delta.dy < -8){ //swipe up
          if (isExpanded)
            isAnimating = true;

          if (filtersExpanded)
            filtersExpanded = false;
          else paramsExpanded = false;
        }
        setState(() { });
      },
      child: Container(
        child: Container(
          height: 5,
          width: 80,
          margin: EdgeInsets.only(bottom:7, top: 20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(isExpanded ? 0.9 : 0.2),
            borderRadius: BorderRadius.circular(20),
          )
        ),
      )
    );
  }

  Widget _Header() {
    return Container(
      margin: EdgeInsets.only(bottom: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          GestureDetector(
            onTap: () {
              // Mode.globalParamsEnabled = !Mode.globalParamsEnabled;
              paramsExpanded = !paramsExpanded;
              setState(() {});
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                  // color: Color(0xFF222222),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Checkbox(
                    value: Mode.globalParamsEnabled,
                    activeColor: Colors.blue,
                    onChanged: (value) {
                      if (Mode.global.paramsAreDefaults && !paramsExpanded)
                        return setState(() => paramsExpanded = !paramsExpanded);

                      Mode.globalParamsEnabled = value;
                      setState(() {});
                    }
                  ),
                  Text("Global Params", style: TextStyle(fontSize: 16)),
                  // Container(
                  //   child: paramsExpanded ? Icon(Icons.expand_more) : Icon(Icons.chevron_right),
                  // )
                ]
              ),
            ),
          ),
          Container(
            margin: EdgeInsets.only(left: 10),
            child: GestureDetector(
              onTap: () {
                setState(() => filtersExpanded = !filtersExpanded);
              },
              child: Row(
                children: [
                  Checkbox(
                    value: widget.filterController.isOn,
                    activeColor: Colors.blue,
                    onChanged: (value) {
                      if (value == true && widget.filterController.filtersAreBlank)
                        return setState(() => filtersExpanded = !filtersExpanded);

                      if (value) widget.filterController.on();
                      else widget.filterController.off();
                      setState(() {});
                    }
                  ),
                  Text("Filters",
                    textAlign: TextAlign.left,
                    style: TextStyle(fontSize: 16)
                  ),
                  // Container(
                  //   child: filtersExpanded ? Icon(Icons.expand_more) : Icon(Icons.chevron_right),
                  // )
                ]
              )
            ),
          ),
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



