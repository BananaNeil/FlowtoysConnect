import 'package:flutter_hsvcolor_picker/flutter_hsvcolor_picker.dart';
import 'package:app/components/horizontal_line_shadow.dart';
import 'package:app/models/mode_param.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:app/models/mode.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:async';

class InlineModeParams extends StatefulWidget {
  InlineModeParams({
    Key key,
    this.mode,
    this.child,
    this.onTouchUp,
    this.updateMode,
    this.onTouchDown,
    // this.onChange,
  }) : super(key: key);

  Widget child;
  final Mode mode;
  Function onTouchUp = () {};
  Function updateMode = () {};
  Function onTouchDown = () {};

  @override
  _InlineModeParamsState createState() => _InlineModeParamsState(
    mode: mode,
  );
}

class _InlineModeParamsState extends State<InlineModeParams> with TickerProviderStateMixin {
  _InlineModeParamsState({this.mode});

  final Mode mode;
  String showControlsForParam;
  String showSlider;
  String sliderType;
  double containerWidth;
  double initialValue;

  @override initState() {
    super.initState();
  }

  @override dispose() {
    animators.values.forEach((animator) => animator.dispose());
    super.dispose();
  }

  @override
  build(BuildContext context) {
    color = mode.getHSVColor();
    if (color != colorWas) _bustCache();
    colorWas = color;

    if (showControlsForParam != null)
      return _ParamControls(paramName: showControlsForParam);

    if (showSlider != null && sliderVisible)
      return _Slider(
        paramName: showSlider,
        sliderType: sliderType,
      );

    return Container(
      margin: EdgeInsets.only(top: 8),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          containerWidth = box.maxWidth;
          return Column(
            children: [
              _Toggles(),
              Container(
                height: 15,
              ),
              Dials(),
              AnimationSwitches(),
              widget.child ?? Container(),
            ]
          );
        }
      )
    );
  }

  Map<String, AnimationController> animators = {};

  List<String> _params;
  List<String> get params => _params ??= [
    'adjust',
    'hue',
    'saturation',
    'brightness',
    'density',
    'speed',
  ];

  List<Color> _hueColors;
  List<Color> get hueColors {
    if (_hueColors != null) return _hueColors;
    var color = HSVColor.fromColor(Colors.blue);
    return _hueColors ??= List<int>.generate(13, (int index) => index * 60 % 360).map((degree) {
      return color.withHue(1.0 * degree).toColor();
    }).toList();
  }

  Widget get adjustLines {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        gradient: LinearGradient(
          colors: [Colors.black.withOpacity(1.0), Colors.black.withOpacity(0.8), Colors.black.withOpacity(1.0)]
        )
      ),
      child: Row(
        children: List<int>.generate(30, (int index) => index).map((index) {
          return Flexible(
              flex: 1,
              child: Container(
              height: 30,
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: Colors.grey, width: 1)),
                ),
              )
          );
        }).toList()
      ),
    );
  }

  Widget get speedLines {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        gradient: LinearGradient(
          colors: [Colors.black.withOpacity(1.0), Colors.black.withOpacity(0.8), Colors.black.withOpacity(1.0)]
        )
      ),
      child: Row(
        children: List<int>.generate(17, (int index) => 17 - index+1).map((size) {
          return Flexible(
              flex: size * size,
              child: Container(
              height: 30,
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: Colors.grey, width: 1)),
                ),
              )
          );
        }).toList()
      )
    );
  }

  HSVColor colorWas;
  HSVColor color;

  Map<String, Color> _colors;
  Map<String, Color> get colors => _colors ??= {
    'hue': color.withSaturation(1.0).withValue(1.0).toColor(),
    'saturation': color.withValue(1.0).toColor(),
    'brightness': color.toColor(),
  };

  Map<String, List<Color>> _gradients;
  Map<String, List<Color>> get gradients => _gradients ??= {
    'hue': hueColors,
    'saturation': [color.withValue(1.0).withSaturation(0.0).toColor(), color.withValue(1.0).withSaturation(1.0).toColor()],
    'brightness': [color.withValue(0.0).toColor(), color.withValue(1.0).toColor()],
  };

  Map<String, Widget> get icons => {
    'adjust': Container(padding: EdgeInsets.all(5), child: Image(image: AssetImage('assets/images/adjust.png'))),
    'brightness': Icon(Icons.brightness_medium, size: dialSize - 8),
    'saturation': Icon(Icons.opacity, size: dialSize - 8),
    'speed': Icon(Icons.fast_forward, size: dialSize - 8),
    'hue': Icon(Icons.color_lens, size: dialSize - 8),
    'density': Icon(Icons.waves, size: dialSize - 8),
  };

  void _bustCache() {
    _gradients = null;
    _colors = null;
  }

  bool sliderVisible = false;


  bool get isShowingHueParam =>  showSlider == 'hue' && sliderType == 'param';

  Widget _ParamControls({paramName}) {
    var label = toBeginningOfSentenceCase(paramName);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              child: Text("x", style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                showControlsForParam = null;
                // showSlider = null;
                if (this.mounted)
                  setState(() {});
                mode.save();
                widget.onTouchUp();
              },
            ),
          ]
        ),

        AnimatedBuilder(
          animation: animators[paramName],
          builder: (ctx, w) {
            return _Slider(paramName: paramName, sliderType: 'param');
          }
        ),
        _Slider(paramName: paramName, sliderType: 'speed'),
      ]
    );
  }

  Widget _Slider({paramName, sliderType}) {
    var label = toBeginningOfSentenceCase(paramName);
    if (sliderType == 'speed')
      label += " Animation Speed";

    var speed = mode.getAnimationSpeed(paramName);
    var sliderValue = mode.getValue(paramName).clamp(0.0, isShowingHueParam ? 2.0 : 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(child: Text(label), padding: EdgeInsets.only(top: 8, bottom: 4)),
        SliderPicker(
          min: 0,
          max: isShowingHueParam ? 2.0 : 1.0,
          height: 30,
          thumbColor: sliderType != 'speed' ? null : (speed == 0 ? Color(0xAAAAAAAA) : Colors.green.withOpacity(0.75)),

          value: sliderType == 'param' ? sliderValue : speed.abs(),
          colorRows: sliderType == 'speed' ? null : [gradients[paramName]],
          onChanged: (value){
            if (sliderType == 'param')
              mode.getParam(paramName).setValue(value.clamp(0.0, 1.1 + (isShowingHueParam ? 1 : 0)));
            else if (sliderType == 'speed') {
              mode.setAnimationSpeed(paramName, value);
              ensureAnimationControllerFor(paramName);
            }
            mode.save();

            widget.updateMode();
            setState((){});
          },
          child: sliderType == 'param' && paramName == 'adjust' ? adjustLines : speedLines
        )
      ]
    );
  }

  Widget _Toggles() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        // _ToggleButton(
        //   title: "Bypass Sliders",
        //   value: mode.bypassParams,
        //   onChanged: (value) {
        //     mode.bypassParams = value;
        //     setState(() {});
        //   },
        // ),
        _ToggleButton(
          title: "Adjust On",
          value: mode.isAdjusting,
          onChanged: (value) {
            print("IS AD: ${mode.isAdjusting}");
            mode.isAdjusting = value;
            setState(() {});
          },
        ),
        _ToggleButton(
          value: mode.adjustRandomized,
          title: "Scramble Group",
          onChanged: (value) {
            mode.adjustRandomized = value;
            setState(() {});
          },
        ),
      ]
    );
  }

  Widget _ToggleButton({onChanged, title, value}) {
    return GestureDetector(
      onTap: () {
        onChanged(!value);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.0),
          color: Color(0xFF333333),
        ),
        child: IntrinsicWidth(
          child: Column(
            // crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 5),
                child: Opacity(
                  opacity: 0.3,
                  child: HorizontalLineShadow(),
                )
              ),
              Row(children: [
                Checkbox(value: value, activeColor: Colors.blue, onChanged: onChanged),
                Container(child: Text(title), padding: EdgeInsets.only(top: 10, bottom: 10, right: 15, left: 0)),
              ]),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 5),
                child: HorizontalLineShadow(),
              )
            ],
          )
        )
      )
    );
  }

  Widget Dials() {
    return SliderListener(
      onStart: (int index) {
        sliderType = 'param';
        showSlider = params[index];
        initialValue =  mode.getValue(showSlider);
      },
      onUpdate: (value) {
        widget.updateMode();
        mode.getParam(showSlider).setValue(value);
        mode.save();
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: params.map<Widget>((paramName) {
          return Dial(paramName);
        }).toList()
      )
    );
  }
  Widget AnimationSwitches() {
    return Container(
      height: 25,
      margin: EdgeInsets.only(top: 5),
      child: SliderListener(
        onStart: (int index) {
          sliderType = 'speed';
          showSlider = params[index];
          initialValue =  mode.getAnimationSpeed(showSlider).abs();
        },
        onUpdate: (value) {
          mode.setAnimationSpeed(showSlider, value);
          mode.save();
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: params.map<Widget>((paramName) {
            var speed = mode.getAnimationSpeed(paramName);
            return Container(
              width: 30,
              child: SliderPicker(
                value: speed.abs(),
                thumbColor: speed == 0 ? Color(0xAAAAAAAA) : Colors.green,
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0xAA333333),
                  )
                ),
                height: 15,
                min: 0.0,
                max: 1.0,
              )
            );
            // return Transform.scale(
            //   scale: 0.7,
            //   child: Switch(
            //     value: mode.isAnimating(paramName),
            //     onChanged: (bool) {
            //       mode.setAnimating(paramName, bool);
            //       if (bool)
            //         animators[paramName].forward();
            //       else {
            //         animators[paramName].stop();
            //         widget.onTouchUp();
            //       }
            //       setState((){});
            //     },
            //   )
            // );
          }).toList()
        )
      )
    );
  }

  double gradientBlackSpace = 0.1;
  double get dialSize => containerWidth < 380 ? 24.0 : 30.0;
  double get adjustmentRange => (1 - 2 * gradientBlackSpace);

  Widget Dial(paramName) {
    if (paramName == null)
      return Container(width: 0);

    var gradientsForParam = gradients[paramName] ?? [Colors.black, Colors.white];
    var gradientStopCount = gradientsForParam.length;
    var gradientStops = List.generate(gradientStopCount, (index) {
      var ratio = index / (gradientStopCount - 1);
      return gradientBlackSpace + ratio * adjustmentRange;
    });
    gradientStops.insert(0, gradientStops.first);
    gradientStops.add(gradientStops.last);

    var paramValue = mode.getValue(paramName);
    if (paramName == 'hue')
      paramValue *= 0.5;

    return Stack(
      alignment: Alignment.center,
      children: [
        Transform(
          alignment: FractionalOffset.center,
          transform: Matrix4.rotationZ(pi / 2),
          child: Container(
            height: dialSize + 7,
            width: dialSize + 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF1A1A1A),
                  spreadRadius: 2.0,
                  blurRadius: 2.0,
                ),
              ],

              gradient:  SweepGradient(
                stops: gradientStops,
                colors: //[
                  [
                    Colors.black,
                    ...gradientsForParam,
                    Colors.black,
                  ],
              ),
            )
          ),
        ),
        DialValueIndicator(paramName, paramValue),
        Container(
          height: dialSize,
          width: dialSize,
          padding: EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black,
          ),
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcATop),
            child: icons[paramName],
          )
        )
      ]
    );
  }

  void ensureAnimationControllerFor(paramName) {
    var param = mode.getParam(paramName);
    var paramValue = mode.getValue(paramName);
    // THIS IS THE SAME AS: inline_mode_params.dart
    // THIS IS THE SAME AS: edit_mode_widget.dart
    var speed = mode.getAnimationSpeed(paramName);
    if (animators[paramName] == null){
      animators[paramName] = AnimationController(
        duration: Duration(
          microseconds: speed == 0 ? 10000 :
            (param.numberOfCycles * ModeParam.maxAnimationDuration.inMicroseconds / speed.abs()
        ).toInt()),
        upperBound: 1,
        lowerBound: 0,
        vsync: this,
      );
      animators[paramName].addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          animators[paramName].reverse();
        } else if (status == AnimationStatus.dismissed) {
          animators[paramName].forward();
        }
      });
    }
    animators[paramName].value = paramValue;

    if (!param.isAnimating)
      animators[paramName].stop();
    else {
      animators[paramName].duration = Duration(microseconds: (param.numberOfCycles * ModeParam.maxAnimationDuration.inMicroseconds / speed.abs()).toInt());
      if (param.animatedSpeedDirection > 0)
        animators[paramName].forward();
      else
        animators[paramName].reverse();
    }
  }

  Widget DialValueIndicator(paramName, paramValue) {
    ensureAnimationControllerFor(paramName);

    Widget indicator = Container(
      height: dialSize + 10,
      width: dialSize + 10,
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          height: dialSize - 10,
          width: 3,
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: Colors.white, width: 1),
              right: BorderSide(color: Colors.black, width: 2),
            ),
          ),
        ),
      ),
    );
    var rotationOffset = adjustmentRange * pi;
    return AnimatedBuilder(
      animation: animators[paramName],
      builder: (ctx, w) {
        return Transform(
          alignment: FractionalOffset.center,
          transform: Matrix4.rotationZ(adjustmentRange * 2 * pi * animators[paramName].value - rotationOffset),
          child: indicator,
        );
      }
    );
  }

  int sliderIndexFromPosition(xPosition) {
    return (params.length * xPosition / containerWidth).floor();
  }

  Widget SliderListener({child, onStart, onUpdate}) {
    double dx = 0;
    return Listener(
      onPointerDown: (PointerEvent details) {
        var index = sliderIndexFromPosition(details.localPosition.dx);
        onStart(index);
        Timer(Duration(milliseconds: 800), () {
          if (showControlsForParam == null)
            setState(() => sliderVisible = true);
        });
        if (this.mounted)
          setState(() {});
        widget.onTouchDown();
      },
      onPointerUp: (PointerEvent details) {
        showSlider = null;
        print("DX: ${dx} ${!sliderVisible}");
        if (dx.abs() < 0.85 && !sliderVisible) {
          var index = sliderIndexFromPosition(details.localPosition.dx);
          showControlsForParam = params[index];
        } else widget.onTouchUp();
        sliderVisible = false;
        if (this.mounted) setState(() {});
      },
      onPointerMove: (PointerEvent details) {
        dx += details.delta.dx;
        if (dx.abs() >= 0.85)
          sliderVisible = true;

        // var val = mode.getValue(showSlider);
        var delta;
        delta = 2 * (dx) / containerWidth;
        delta *= 2 * (1 + (initialValue - (params.indexOf(showSlider) / params.length)).abs()); 
        onUpdate((initialValue + delta).clamp(0.0, 1.1 + (isShowingHueParam ? 1 : 0)));
        if (this.mounted)
          setState(() {});
      },
      child: child,
    );
  }

}


