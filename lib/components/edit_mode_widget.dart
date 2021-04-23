import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:app/models/prop.dart';
import 'package:app/models/mode.dart';
import 'package:app/components/mode_widget.dart';
import 'package:app/components/inline_mode_params.dart';



import 'package:flutter_hsvcolor_picker/flutter_hsvcolor_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:app/components/edit_mode_widget.dart';
import 'package:app/models/mode_param.dart';
import 'package:app/models/base_mode.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/models/mode.dart';

import 'package:app/models/group.dart';
import 'package:app/preloader.dart';
import 'package:app/client.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math';

class EditModeWidget extends StatefulWidget {
  EditModeWidget({
    Key key,
    this.mode,
    this.onChange,
    this.autoUpdate,
    this.editDetails,
    this.sliderHeight
  }) : super(key: key);

  final Mode mode;
  final num sliderHeight;
  final bool editDetails;
  final bool autoUpdate;
  Function onChange = (mode) {};

  @override
  _EditModeWidgetState createState() => _EditModeWidgetState(
    sliderHeight: sliderHeight ?? 40.0,
    editDetails: editDetails,
    mode: mode,
  );
}

class _EditModeWidgetState extends State<EditModeWidget> with TickerProviderStateMixin {
  _EditModeWidgetState({this.mode, this.editDetails, this.sliderHeight});

  List<BaseMode> baseModes = [];
  final Mode mode;

  bool awaitingResponse = false;
  bool editDetails = false;
  Timer updateModeTimer;
  String errorMessage;
  num sliderHeight;

  HSVColor color = HSVColor.fromColor(Colors.blue);

  bool get autoUpdate => widget.autoUpdate ?? true;

  void onChange(mode) {
    Prop.refreshByMode(mode);
    if (widget.onChange != null)
      widget.onChange(mode);
  }

  @override dispose() {
    animators.values.forEach((animator) => animator.dispose());
    super.dispose();
  }

  Map<String, AnimationController> animators = {};


  @override initState() {
    super.initState();
    Preloader.getCachedBaseModes().then((cachedBaseModes) {
      setState(() => baseModes = cachedBaseModes);
      Client.getBaseModes().then((response) {
        if (response['success'])
          setState(() => baseModes = response['baseModes']);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Color(0xFF2F2F2F)),
      child: Column(
        children: [
          Container(
            height: 25,
            margin: EdgeInsets.only(top: 5),
            child: ModeRow(
              mode: mode,
              showImages: true,
              fit: BoxFit.fill,
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(20),
              children: [
                _RenameField(),
                _ChooseBaseMode(),
                _Buttons(),
                ..._Sliders(),
              ],
            ),
          ),
        ]
      )
    );
  }

  Widget _Buttons() {
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ActionButton(
            text: 'Defaults',
            color: Color(0xFFAA3333),
            onTap: () {
              mode.modeParams.keys.forEach((paramName) {
                mode.resetParam(paramName);
              });
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

  Future<void> _updateMode() {
    if (autoUpdate != true) return Future.value(null);
    setState(() { awaitingResponse = true; });
    return Client.updateMode(mode).then((response) {
      setState(() {
        if (response['success']) {
          awaitingResponse = false;
          errorMessage = null;
        } else errorMessage = response['message'];
      });
    });
  }

  bool get canEditDetails =>
    mode != null && mode.accessLevel != 'frozen' && editDetails == true;

  Widget _ChooseBaseMode() {
    if (!canEditDetails) return Container();
    return Stack(
      children: [
        Text("Choose Base Mode",
          style: TextStyle(
            color: Color(0xFF999999),
            fontSize: 12,
          ),
        ),
        Container(
          width: 250,
          margin: EdgeInsets.only(bottom: 20, top: 5),
          child: DropdownButton(
            isExpanded: true,
            value: mode.baseModeId ?? baseModes.elementAt(0)?.id,
            items: baseModes.map((BaseMode baseMode) {
              return DropdownMenuItem<String>(
                value: baseMode.id,
                child: Row(
                  children: [
                    Container(
                      margin: EdgeInsets.only(right: 7),
                      child: BaseModeImage(baseMode: baseMode, size: 12),
                    ),
                    Text(baseMode.name),
                  ]
                )
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                mode.updateBaseModeId(value);
                onChange(mode);
              });
              _updateMode();
            },
          ),
        )
      ]
    );
  }

  Widget _RenameField() {
    if (!canEditDetails) return Container();
    return Container(
      width: 250,
      padding: EdgeInsets.only(bottom: 30),
      child: TextFormField(
        initialValue: mode.name,
        decoration: InputDecoration(
          labelText: 'Choose Custom Name',
        ),
        onChanged: (text) {
          setState(() {
            updateModeTimer?.cancel();
            mode.name = text;
            updateModeTimer = Timer(Duration(milliseconds: 1000), () => _updateMode());
          });
        }
      )
    );
  }

  AnimationController animatorFor(param) {
    AnimationController animator = animators[param.uniqueIdentifier];
    // THIS IS THE SAME AS: inline_mode_params.dart
    // THIS IS THE SAME AS: edit_mode_widget.dart
    if (animator == null) {
      var speed = mode.getAnimationSpeed(param.paramName);
      animator = animators[param.uniqueIdentifier] = AnimationController(
        duration: Duration(
          microseconds: speed == 0 ? 10000 :
            (param.numberOfCycles * ModeParam.maxAnimationDuration.inMicroseconds / speed.abs()
        ).toInt()),
        upperBound: 1,
        lowerBound: 0,
        vsync: this,
      );
      animator.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          animator.reverse();
        } else if (status == AnimationStatus.dismissed) {
          animator.forward();
        }
      });
    }

    return animator;
  }

  Widget ParamSlider(param, {title, children, onReset, margin}) {
    var animatedParam = param.animatedParamDependency ?? param;
    var animator = animatorFor(animatedParam);

    if (animatedParam.isAnimating) {
      animator.value = animatedParam.getValue();//.clamp(0.0, param.numberOfCycles;
      if (animatedParam.animatedSpeedDirection > 0)
        animator.forward();
      else
        animator.reverse();
    }


    return Container(
      margin: margin ?? EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                  param.toggleMultiValue();
                  _updateMode();
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(title, style: TextStyle(
                      fontSize: 16//, fontWeight: FontWeight.bold
                    )),
                    Visibility(
                      visible: children != null,
                      child: param.multiValueEnabled ? Icon(Icons.expand_more) : Icon(Icons.chevron_right),
                    ),
                  ]
                ),
                Row(
                  children: [
                    Container(
                      child: GestureDetector(
                        onTap: () {
                          if (param.isAnimating)
                            param.animationSpeed = 0.0;
                          else param.animationSpeed = 0.5;
                          onChange(mode);
                          setState(() {});
                        },
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.rotationY(pi),
                          child: Container(
                            height: 30,
                            width: 35,
                            child: ColorFiltered(
                              colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcATop),
                              child: Image(image: AssetImage('assets/images/infinity.png')),
                            )
                          )
                        )
                      )
                    ),
                    Container(
                      margin: EdgeInsets.only(left: 10),
                      child: onReset == null ? null : GestureDetector(
                        onTap: onReset,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.rotationY(pi),
                          child: Icon(Icons.refresh),
                        )
                      )
                    ),
                  ]
                )
              ]
            )
          ),
          AnimatedBuilder(
            animation: animator,
            builder: (ctx, w) {
              return SliderPicker(
                min: 0.0,
                height: sliderHeight,
                // value: animator.value,
                max: param.numberOfCycles.toDouble(),
                value: param.getValue().clamp(0.0, param.numberOfCycles),
                colorRows: gradients(param),
                gradientStops: gradientStops(param),
                thumbColor: thumbColorFor(param),
                onChanged: (value){
                  updateModeTimer?.cancel();
                  setState(() => param.setValue(value));
                  updateModeTimer = Timer(Duration(milliseconds: 1000), () => _updateMode());
                  onChange(mode);
                },
                child: param.paramName == 'adjust' ? adjustLines : speedLines
              );
            }
          ),
          !param.multiValueEnabled ? Container() : Container(
            margin: EdgeInsets.only(top: 5, left: 10, right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SliderPicker(
                  min: 0.0,
                  max: 1.0,
                  height: sliderHeight/2,
                  value: param.animationSpeed,
                  colorRows: [[Color(0xBB000000), Color(0x99000000)]],
                  // colorRows: [],
                  gradientStops: gradientStops(param),
                  thumbColor: Colors.green.withOpacity(0.75),
                  onChanged: (value){
                    param.animationSpeed = value;
                    onChange(mode);
                    updateModeTimer?.cancel();
                    updateModeTimer = Timer(Duration(milliseconds: 1000), () => _updateMode());
                  },
                  child: speedLines
                ),
              ]
            )
          ),
          Visibility(
            visible: param.multiValueEnabled,
            child: Padding(
              padding: EdgeInsets.only(left: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children ?? [],
              )
            )
          )
        ]
      )
    );
  }


  List<Widget> _Sliders() {
    List<Widget> emptyList = [];
    return [
      "adjust",
      "brightness",
      "saturation",
      "hue",
      "speed",
      "density",
    ].map((paramName) {
      ModeParam param = mode.getParam(paramName);

      return ParamSlider(param,
        margin: EdgeInsets.only(bottom: 10),
        title: toBeginningOfSentenceCase(paramName),
        onReset: () {
          setState(() => mode.resetParam(paramName));
          onChange(mode);
          _updateMode();
        },
        children: param.childType == null ? null : (!param.multiValueEnabled ? emptyList : mapWithIndex(param.presentChildParams, (childIndex, childParam) {
          if (param.childType == 'group') {
            Group group = Group.currentGroups[childIndex];
            return ParamSlider(childParam,
              title: "${group.name} (${group.props.length})",
              children: !childParam.multiValueEnabled ? emptyList : mapWithIndex(childParam.presentChildParams, (propIndex, propParam) {
                return ParamSlider(propParam, title: "Prop #${propIndex + 1}");
              }).toList(),
            );
          } else if (param.childType == 'prop') {
            return ParamSlider(childParam, title: "Prop #${childIndex + 1}");
          }

        }).toList()),
      ); 
    }).toList();
  }

  List<Color> get hueColors {
    return List<int>.generate(13, (int index) => index * 60 % 360).map((degree) {
      return this.color.withHue(1.0 * degree).toColor();
    }).toList();
  }

  Widget get adjustLines {
    return Row(
      children: List<int>.generate(25, (int index) => 17 - index+1).map((size) {
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

  Color thumbColorFor(param) {
    if (showMultiRow(param))
      if (param.paramName == 'hue')
        return Colors.white;
      else return Colors.transparent;

    var hue = param.mode.getValue('hue', groupIndex: param.groupIndex, propIndex: param.propIndex);
    var brightness = param.mode.getValue('brightness', groupIndex: param.groupIndex, propIndex: param.propIndex);
    var saturation = param.mode.getValue('saturation', groupIndex: param.groupIndex, propIndex: param.propIndex);

    return {
      'hue': color.withHue((hue * 360) % 360).withSaturation(1).toColor(),
      'saturation': color.withHue((hue * 360) % 360).withSaturation(saturation).toColor(),
      'brightness': color.withHue((hue * 360) % 360).withSaturation(saturation).withValue(brightness).toColor(),
    }[param.paramName] ?? Colors.black;
  }

  List<Color> gradientColors(param, {hue, saturation, brightness}) {
    // includeMiddleValue makes the sliders seem more acurate when sub-sliders are active.
    if (param.paramName == 'hue')
      return hueColors;
    else if (param.paramName == 'saturation') {
      return [
        color.withHue((hue ?? mode.hue.value) * 360 % 360).withSaturation(0).toColor(),
        param.multiValueActive == true ? color.withHue((hue ?? mode.hue.value) * 360 % 360).withSaturation(saturation).toColor() : null,
        color.withHue((hue ?? mode.hue.value) * 360 % 360).withSaturation(1).toColor(),
      ]..removeWhere((color) => color == null);
    } else if (param.paramName == 'brightness')
      return [
        Colors.black,
        param.multiValueActive == true ? color.withHue((hue ?? mode.hue.value) * 360 % 360).withSaturation(saturation ?? mode.saturation.value).withValue(brightness).toColor() : null,
        color.withHue((hue ?? mode.hue.value) * 360 % 360).withSaturation(saturation ?? mode.saturation.value).toColor(),
      ]..removeWhere((color) => color == null);
    else if (param.paramName == 'speed')
      return [
        Color(0x44000000),
        Color(0x44FFFFFF),
      ];
    else if (param.paramName == 'density')
      return [
        Color(0x44000000),
        Color(0x44FFFFFF),
      ];
  }

  bool showMultiProp(param) {
    if (param.paramName == 'brightness' && showMultiProp(param.getSiblingParam('saturation'))) return true;
    if (param.paramName == 'saturation' && showMultiProp(param.getSiblingParam('hue'))) return true;

    if (param.groupIndex != null) return param.multiValueActive;
    return param.hasMultiValueChildren();
  }

  bool showMultiRow(param) {
    bool showMultiRow = false;
    if (param.propIndex != null)
      return false;
    else if (param.groupIndex == null) {
      if (param.paramName == 'brightness' && (param.mode.saturation.multiValueActive || param.mode.hue.multiValueActive))
        showMultiRow = true;
      if (param.paramName == 'saturation' && param.mode.hue.multiValueActive)
        showMultiRow = true;
      showMultiRow = showMultiRow || param.mode.getParam(param.paramName).multiValueActive;
    }
    return showMultiRow || showMultiProp(param);
  }

  List<Map<String, int>> distinctSliderRowIndexes(param) {
    List<Map<String, int>> rows = [];

    if (showMultiRow(param))
      List.generate(Group.currentGroups.length, (currentGroupIndex) {
        if (param.groupIndex == null || param.groupIndex == currentGroupIndex) {
          if (showMultiProp(param)) {
            var propCount = Group.currentGroups[currentGroupIndex].props.length;
            List.generate(propCount, (i) => i).forEach((propIndex) {
              rows.add({
                'group': currentGroupIndex,
                'prop': propIndex,
              });
            }); 
          } else {
            rows.add({ 'group': currentGroupIndex });
          }
        }
      });
    else rows.add({'group': param.groupIndex});

    return rows;
  }

  List<double> gradientStops(param) {
    if (param.paramName != 'hue' && param.multiValueActive)
      return [0.0, param.getValue(), 1.0];
  }

  List<List<Color>> gradients(param) {
    if (param.paramName == 'hue') return [hueColors];
    List<Map<String, int>> indexes;
    List<List<Color>> rows = [];

    if (param.propIndex == null)
      indexes = distinctSliderRowIndexes(param);
    else
      indexes = [{'group': param.groupIndex, 'prop': param.propIndex}];

    return indexes.map((indexes) {
      return gradientColors(param,
        hue: param.mode.hue.getValue(indexes: [indexes['group'], indexes['prop']]),
        brightness: param.mode.brightness.getValue(indexes: [indexes['group'], indexes['prop']]),
        saturation: param.mode.saturation.getValue(indexes: [indexes['group'], indexes['prop']]),
      );
    }).toList();
  }
}

