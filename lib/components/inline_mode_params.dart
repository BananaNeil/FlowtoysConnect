import 'package:flutter_hsvcolor_picker/flutter_hsvcolor_picker.dart';
import 'package:app/models/mode_param.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:app/models/mode.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class InlineModeParams extends StatefulWidget {
  InlineModeParams({
    Key key,
    this.mode,
    this.onTouchUp,
    this.onTouchDown,
    // this.onChange,
  }) : super(key: key);

  final Mode mode;
  Function onTouchUp = () {};
  Function onTouchDown = () {};

  @override
  _InlineModeParamsState createState() => _InlineModeParamsState(
    mode: mode,
  );
}

class _InlineModeParamsState extends State<InlineModeParams> with TickerProviderStateMixin {
  _InlineModeParamsState({this.mode});

  final Mode mode;
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

  Map<String, AnimationController> animators = {};

  var params = [
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
    return Row(
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
    );
  }

  Widget get speedLines {
    return Row(
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

  Map<String, Widget> icons = {
    'adjust': Container(padding: EdgeInsets.all(5), child: Image(image: AssetImage('assets/images/adjust.png'))),
    'brightness': Icon(Icons.brightness_medium, size: 22),
    'saturation': Icon(Icons.opacity, size: 22),
    'speed': Icon(Icons.fast_forward, size: 22),
    'hue': Icon(Icons.color_lens, size: 22),
    'density': Icon(Icons.waves, size: 22),
  };

  void _bustCache() {
    _gradients = null;
    _colors = null;
  }

  @override
  build(BuildContext context) {
    color = mode.getHSVColor();
    if (color != colorWas) _bustCache();
    colorWas = color;

    if (showSlider != null)
      return _Slider();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        containerWidth = box.maxWidth;
        return Column(
          children: [
            Dials(),
            AnimationSwitches(),
          ]
        );
      }
    );
  }

  bool get isShowingHueParam =>  showSlider == 'hue' && sliderType == 'param';

  Widget _Slider() {
    var label = toBeginningOfSentenceCase(showSlider);
    if (sliderType == 'speed')
      label += " Animation Speed";

    var speed = mode.getAnimationSpeed(showSlider);
    var sliderValue = mode.getValue(showSlider).clamp(0.0, isShowingHueParam ? 2.0 : 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        SliderPicker(
          min: 0,
          max: isShowingHueParam ? 2.0 : 1.0,
          height: 30,
          thumbColor: sliderType != 'speed' ? null : (speed == 0 ? Color(0xAAAAAAAA) : Colors.green.withOpacity(0.75)),

          value: sliderType == 'param' ? sliderValue : speed.abs(),
          colorRows: sliderType == 'speed' ? null : [gradients[showSlider]],
          onChanged: (value){ },
          child: sliderType == 'param' && showSlider == 'adjust' ? adjustLines : speedLines
        )
      ]
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
          var speed = mode.getAnimationSpeed(showSlider);
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
            height: 37,
            width: 37,
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
          height: 30,
          width: 30,
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

  Widget DialValueIndicator(paramName, paramValue) {
    var param = mode.getParam(paramName);
    // THIS IS THE SAME AS: inline_mode_params.dart
    // THIS IS THE SAME AS: edit_mode_widget.dart
    if (animators[paramName] == null){
      var speed = mode.getAnimationSpeed(paramName);
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
    else
      if (param.animatedSpeedDirection > 0)
        animators[paramName].forward();
      else
        animators[paramName].reverse();

    Widget indicator = Container(
      height: 40,
      width: 40,
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          height: 20,
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
    var was;
    return AnimatedBuilder(
      animation: animators[paramName],
      builder: (ctx, w) {
        // if (paramName == 'density')
        // print("..... ${animators[paramName].value}");
        return Transform(
          alignment: FractionalOffset.center,
          transform: Matrix4.rotationZ(adjustmentRange * 2 * pi * animators[paramName].value - rotationOffset),
          child: indicator,
        );
      }
    );
  }

  Widget SliderListener({child, onStart, onUpdate}) {
    double dx = 0;
    return Listener(
      onPointerDown: (PointerEvent details) {
        var index = (params.length * details.localPosition.dx / containerWidth).floor();
        onStart(index);
        if (this.mounted)
          setState(() {});
        widget.onTouchDown();
      },
      onPointerUp: (PointerEvent details) {
        showSlider = null;
        // dx = null;

        if (this.mounted)
          setState(() {});
        widget.onTouchUp();
      },
      onPointerMove: (PointerEvent details) {
        dx += details.delta.dx;

        // var val = mode.getValue(showSlider);
        var delta;
        delta = 2 * (dx) / containerWidth;
        delta *= 2 * (1 + (initialValue - (params.indexOf(showSlider) / params.length)).abs()); 
        onUpdate((initialValue + delta).clamp(0.0, 1.1));
        if (this.mounted)
          setState(() {});
      },
      child: child,
    );
  }

}


