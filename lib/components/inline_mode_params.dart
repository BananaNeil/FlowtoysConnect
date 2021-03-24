import 'package:flutter_hsvcolor_picker/flutter_hsvcolor_picker.dart';
import 'package:app/components/horizontal_line_shadow.dart';
import 'package:app/models/mode_param.dart';
import 'package:app/app_controller.dart';
import 'package:app/models/bridge.dart';
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
    intensityStream?.cancel();
    super.dispose();
  }

  @override
  build(BuildContext context) {
    color = mode.getHSVColor();
    if (color != colorWas) _bustCache();
    colorWas = color;

    if (showControlsForParam != null)
      return Container(
        child: _ParamControls(paramName: showControlsForParam),
        margin: EdgeInsets.only(
          right: 10,
          bottom: 20,
          left: 10,
          top: 15,
        ),
      );

    return Container(
      child: Stack(
        children: [
          Container(
            margin: EdgeInsets.only(
              right: 10,
              bottom: 20,
              left: 10,
              top: 15,
            ),
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
                    _Buttons(),
                    _AdvancedLink()
                  ]
                );
              }
            )
          ),
          showSlider != null && sliderVisible ?  Positioned.fill(

            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 20,
              ),
              // constraints: BoxConstraints.expand(),
              decoration: BoxDecoration(
                // color: Colors.black.withOpacity(0.5),
                gradient: LinearGradient(
                  begin: Alignment(0, -1.0),
                  end: Alignment(0, 1.0),
                  stops: [0, 0.1, 0.9, 1],
                  colors: [
                    Colors.black.withOpacity(0.5),
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.5),
                  ]
                )
              ),
              child: _Slider(
                paramName: showSlider,
                sliderType: sliderType,
              )
            )
          ) : Container(),
        ]
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              child: Container(
                padding: EdgeInsets.only(right: 10, bottom: 10),
                decoration: BoxDecoration(
                    // shape: BoxShape.circle,
                    // color: Colors.black,
                ),
                child: Text("close", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
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
        _ParamButtons(paramName),
      ]
    );
  }

  Map<String, Map<String, dynamic>> audioLinks = {};
  StreamSubscription intensityStream;
  void reloadAudioLinks() {
    intensityStream?.cancel();

    if (audioLinks.keys.length == 0) {
      // Bridge.audioManager.stopStream();
      // BUT ONLY IF THERE ARE NO OTHER LISTENERS ATTACHED
      return;
    }

    Bridge.audioManager.startStream();
    intensityStream = Bridge.audioIntensityStream.listen((intensity) {
      print("AUDIO INTENSITY: ${intensity}");
      audioLinks.keys.forEach((paramName) {
        mode.getParam(paramName).setValue(intensity);
        // animators[paramName].value = intensity;
      });
      setState(() {});
    });
  }

  Widget _ParamButtons(paramName) {
    return Container(
      margin: EdgeInsets.only(top: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
            _ToggleButton(
              title: "Link Audio",
              padding: EdgeInsets.all(0),
              value: mode.getParam(paramName).linkAudio ?? false,
              onChanged: (value) {
                var param = mode.getParam(paramName);
                param.linkAudio = value;
                  audioLinks ??= {};
                if (value == true)
                  audioLinks[paramName] = {
                    'type': 'incremental',
                  };
                else audioLinks.remove(paramName);
                reloadAudioLinks();
                setState(() {});
              },
            ),
          ActionButton(
            text: 'Defaults',
            color: Color(0xFFAA3333),
            onTap: () {
              mode.resetParam(paramName);
              ensureAnimationControllerFor(paramName);
              setState((){});
            }
          ),
          ActionButton(
            text: 'Randomize!',
            color: Color(0xFF33AA33),
            onTap: () {
              mode.getParam(paramName).setValue(Random().nextDouble());
              setState(() {});
            }
          )
        ].where((button) => button != null).toList()
      ),
    );
  }

  Widget _Slider({paramName, sliderType}) {
    var label = toBeginningOfSentenceCase(paramName);
    if (sliderType == 'speed')
      label += " Animation Speed";

    var speed = mode.getAnimationSpeed(paramName);
    var sliderValue = mode.getValue(paramName).clamp(0.0, isShowingHueParam ? 2.0 : 1.0);
    bool audioLinked = false; 
    var value;

    if (sliderType == 'param') {
      value = sliderValue;
      audioLinked = mode.getParam(paramName).linkAudio;
    } else value = speed.abs(); 
    print("VALUE::::::::::::::: ${value}");
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(child: Text(label), padding: EdgeInsets.only(top: 8, bottom: 4)),
            _IncrementButtons(
              disableDecrement: value <= 0.0 || audioLinked,
              disableIncrement: value >= 1.0 || audioLinked,
              onChange: (direction) {
                setSliderValue(
                  type: sliderType,
                  param: paramName,
                  dx: direction / 255.0,
                );
                setState(() {});
              }
            ),
          ]
        ),
        SliderPicker(
          min: 0,
          max: isShowingHueParam ? 2.0 : 1.0,
          height: 30,
          thumbColor: sliderType != 'speed' ? null : (speed == 0 ? Color(0xAAAAAAAA) : Colors.green.withOpacity(0.75)),

          value: value,
          colorRows: sliderType == 'speed' ? null : [gradients[paramName]],
          onChanged: (value) {
            setSliderValue(
              type: sliderType,
              param: paramName,
              value: value,
            );
          },
          child: sliderType == 'param' && paramName == 'adjust' ?
              adjustLines : speedLines
        )
      ]
    );
  }

  Widget _IncrementButtons({onChange, disableIncrement, disableDecrement}) {
    onChange ??= (direction) {};
    disableDecrement ??= false;
    disableIncrement ??= false;


    return Container(
      margin: EdgeInsets.only(bottom: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children:[
          _IncrementalButton(
            color: disableDecrement ? Colors.grey : Color(0xff40a253),
            padding: EdgeInsets.only(left: 8, right: 7, bottom: 2, top: 0),
            text: "-",
            onTap: () {
              if (!disableDecrement) {
                onChange(-1);
              }
            }
          ),
          Container(width: 10),
          _IncrementalButton(
            color: disableIncrement ? Colors.grey : Color(0xff40a253),
            text: "+",
            onTap: () {
              if (!disableIncrement) {
                onChange(1);
              }
            }
          ),
        ]
      )
    );
  }

  Widget _IncrementalButton({text, color, onTap, padding}) {
    if (onTap == null)
     return null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? EdgeInsets.only(left: 7, right: 7, bottom: 2, top: 0),
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Color(0x44000000),
              offset: Offset(0.9, 0.9),
              spreadRadius: 1,
            )
          ],
          borderRadius: BorderRadius.circular(4),
          color: color,
        ),
        child: Text(text, style: TextStyle(fontSize: 18)),
      )
    );
  }

  void setSliderValue({param, type, value, dx}) {
    bool isShowingHueParam = param == 'hue' && type == 'param';

    if (type == 'speed')
      value ??= mode.getAnimationSpeed(param);
    else value ??= mode.getValue(param);

    if (dx != null)
        value += dx;

    if (type == 'param')
      mode.getParam(param).setValue(value.clamp(0.0, 1.1 + (isShowingHueParam ? 1 : 0)));
    else if (type == 'speed') {
      mode.setAnimationSpeed(param, value);
      ensureAnimationControllerFor(param);
    }
    mode.save();

    widget.updateMode();
    setState((){});
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
            mode.isAdjusting = value;
            setState(() {});
          },
        ),
        _ToggleButton(
          value: mode.adjustRandomized,
          title: "Randomize Adjust",
          onChanged: (value) {
            mode.adjustRandomized = value;
            setState(() {});
          },
        ),
      ]
    );
  }

  Widget _ToggleButton({onChanged, title, value, padding}) {
    return GestureDetector(
      onTap: () {
        onChanged(!value);
      },
      child: Container(
        padding: padding ?? EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.0),
          color: Color(0xFF333333),
        ),
        child: IntrinsicWidth(
          child: Column(
            // crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 3),
                child: Opacity(
                  opacity: 0.3,
                  child: HorizontalLineShadow(),
                )
              ),
              Row(children: [
                Checkbox(value: value, activeColor: Colors.blue, onChanged: onChanged),
                Container(child: Text(title), padding: EdgeInsets.only(top: 10, bottom: 10, right: 7, left: 0)),
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
          widget.updateMode();
          mode.save();
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: params.map<Widget>((paramName) {
            var speed = mode.getAnimationSpeed(paramName);
            return Container(
              width: 30,
              child: SliderPicker(
                onChanged: (val) {},
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

  double dx = 0;
  Widget SliderListener({child, onStart, onUpdate}) {
    return Listener(
      onPointerDown: (PointerEvent details) {
        dx = 0;
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

  Widget _AdvancedLink() {
    if (mode == Mode.global)
      return Container();

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          margin: EdgeInsets.only(top: 10, right: 10),
          child: GestureDetector(
            child: Text('MORE...', style: TextStyle(color: Colors.grey)),
            onTap: () {
              var replacement = mode.dup();
              Navigator.pushNamed(context, '/modes/${replacement.id}', arguments: {
                'mode': replacement,
              }).then((saved) {
                if (saved == true)
                  mode.updateFromCopy(replacement).then((_) {
                  });
              });
            },
          )
        )
      ]
    );
  }

  Widget _Buttons() {
    return Container(
      margin: EdgeInsets.only(top: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ActionButton(
            text: 'Defaults',
            color: Color(0xFFAA3333),
            onTap: () {
              mode.modeParams.keys.forEach((paramName) {
                mode.resetParam(paramName);
                ensureAnimationControllerFor(paramName);
              });
              widget.onTouchUp();
              widget.updateMode();
              setState((){});
            }
          ),
          ActionButton(
            text: 'Randomize!',
            color: Color(0xFF33AA33),
            onTap: () {
              mode.modeParams.keys.forEach((key) {
                if (key != 'brightness')
                  mode.getParam(key).setValue(Random().nextDouble());
              });
              widget.onTouchUp();
              widget.updateMode();
              setState(() {});
            }
          ),
          ActionButton(
            text: 'Save As',
            color: Colors.blue,
            onTap: () {
              Navigator.pushNamed(context, '/lists/new', arguments: {
                'selectedModes': [mode],
              });
            }
          ),
        ].where((button) => button != null).toList()
      ),
    );
  }

}


Widget ActionButton({text, color, onTap}) {
  if (onTap == null)
    return null;

  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.only(left: 14, right: 14, bottom: 10, top: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: color,
      ),
      child: Text(text),
    )
  );
}
