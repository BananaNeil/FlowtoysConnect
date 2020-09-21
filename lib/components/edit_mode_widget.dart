import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:app/models/mode.dart';



import 'package:flutter_hsvcolor_picker/flutter_hsvcolor_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:app/components/edit_mode_widget.dart';
import 'package:app/models/mode_param.dart';
import 'package:app/models/base_mode.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/models/mode.dart';

import 'package:app/models/group.dart';
import 'package:app/client.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class EditModeWidget extends StatefulWidget {
  EditModeWidget({Key key, this.mode, this.editDetails, this.sliderHeight}) : super(key: key);

  final Mode mode;
  final num sliderHeight;
  final bool editDetails;

  @override
  _EditModeWidgetState createState() => _EditModeWidgetState(
    sliderHeight: sliderHeight ?? 40.0,
    editDetails: editDetails,
    mode: mode,
  );
}

class _EditModeWidgetState extends State<EditModeWidget> {
  _EditModeWidgetState({this.mode, this.editDetails, this.sliderHeight});

  final Mode mode;

  bool awaitingResponse = false;
  bool editDetails = false;
  Timer updateModeTimer;
  String errorMessage;
  num sliderHeight;

  HSVColor color = HSVColor.fromColor(Colors.blue);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Color(0xFF2F2F2F)),
      child: ListView(
        padding: EdgeInsets.all(20),
        children: [
          _RenameField(),
          _ChooseBaseMode(),
          ..._Sliders(),
        ],
      ),
    );
  }

  Future<void> _updateMode() {
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
          margin: EdgeInsets.only(bottom: 20),
          child: DropdownButton(
            isExpanded: true,
            value: mode.baseModeId.toString(),
            items: AppController.baseModes.map((BaseMode baseMode) {
              return DropdownMenuItem<String>(
                  value: baseMode.id.toString(),
                  child: new Text(baseMode.name),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                mode.updateBaseModeId(int.parse(value));
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
          labelText: 'Choose custom name',
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


  List<Widget> _Sliders() {
    return [
      "brightness",
      "saturation",
      "hue",
      "speed",
      "density",
    ].map((paramName) {
      ModeParam param = mode.getParam(paramName);
      return Container(
        margin: EdgeInsets.only(bottom: 10),
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
                 children: [
                   Text(toBeginningOfSentenceCase(paramName), style: TextStyle(
                     fontSize: 16//, fontWeight: FontWeight.bold
                   )),
                   param.multiValueEnabled ? Icon(Icons.expand_more) : Icon(Icons.chevron_right),
                 ]
             )
            ),
            SliderPicker(
              min: 0,
              max: 1,
              height: sliderHeight,
              value: param.getValue(),
              colorRows: colorRowsForSlider(paramName, includeMiddleValue: param.multiValueActive),
              gradientStops: paramName != 'hue' && param.multiValueActive ? [0.0, param.getValue(), 1.0] : null,
              thumbColor: showMultiRow(paramName) ? (paramName == 'hue' ? Colors.white : Colors.transparent) : thumbColorFor(paramName,
                hue: mode.getValue('hue'),
                brightness: mode.getValue('brightness'),
                saturation: mode.getValue('saturation')
              ),
              onChanged: (value){
                updateModeTimer?.cancel();
                setState(() => param.setValue(value));
                updateModeTimer = Timer(Duration(milliseconds: 1000), () => _updateMode());
              },
              child: speedLines
            ),
            Visibility(
              visible: param.multiValueEnabled,
              child: Padding(
                padding: EdgeInsets.only(left: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: !param.multiValueEnabled ? [] : 
                  mapWithIndex(param.presentChildParams, (groupIndex, childParam) {
                    Group group = Group.currentGroups[groupIndex];
                    bool isMultiProp = childParam.multiValueEnabled;
                    return [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            childParam.toggleMultiValue();
                            _updateMode();
                          });
                        },
                        child: Row(
                          children: [
                            Text(group.name),
                            Text(" (${group.props.length})"),
                            isMultiProp ?  Icon(Icons.expand_more) : Icon(Icons.chevron_right),
                          ]
                        )
                      ),
                      SliderPicker(
                        min: 0,
                        max: 1,
                        height: sliderHeight,
                        value: childParam.getValue(),
                        colorRows: colorRowsForSlider(paramName, groupIndex: groupIndex, includeMiddleValue: isMultiProp),
                        gradientStops: (paramName == 'hue' || !isMultiProp) ? null : [0.0, childParam.getValue(), 1.0],
                        thumbColor: (paramName == 'hue' && childParam.multiValueActive) ? Colors.white : showMultiRow(paramName, groupIndex: groupIndex) ? Colors.transparent : thumbColorFor(paramName,
                          hue: mode.getValue('hue', groupIndex: groupIndex),
                          brightness: mode.getValue('brightness', groupIndex: groupIndex),
                          saturation: mode.getValue('saturation', groupIndex: groupIndex),
                        ),
                        onChanged: (value){
                          updateModeTimer?.cancel();
                          setState(() => childParam.setValue(value));
                          updateModeTimer = Timer(Duration(milliseconds: 1000), () => _updateMode());
                        },
                        child: speedLines
                      ),
                      Visibility(
                        visible: isMultiProp,
                        child: Padding(
                          padding: EdgeInsets.only(left: 50),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: !isMultiProp ? [] : 
                            mapWithIndex(childParam.presentChildParams, (propIndex, propParam) {
                              num propValue = propParam.getValue();
                              bool isMultiProp = propParam.multiValueEnabled;
                              return [
                                Text("Prop #${propIndex + 1}"),
                                SliderPicker(
                                  min: 0,
                                  max: 1,
                                  value: propValue,
                                  height: sliderHeight,
                                  colors: colorsForSlider(paramName,
                                    hue: mode.getValue('hue', groupIndex: groupIndex, propIndex: propIndex),
                                    brightness: mode.getValue('brightness', groupIndex: groupIndex, propIndex: propIndex),
                                    saturation: mode.getValue('saturation', groupIndex: groupIndex, propIndex: propIndex),
                                  ),
                                  thumbColor: thumbColorFor(paramName,
                                    hue: mode.getValue('hue', groupIndex: groupIndex, propIndex: propIndex),
                                    brightness: mode.getValue('brightness', groupIndex: groupIndex, propIndex: propIndex),
                                    saturation: mode.getValue('saturation', groupIndex: groupIndex, propIndex: propIndex),
                                  ),
                                  onChanged: (value){
                                    updateModeTimer?.cancel();
                                    setState(() => propParam.setValue(value));
                                    updateModeTimer = Timer(Duration(milliseconds: 1000), () => _updateMode());
                                  },
                                  child: speedLines
                                ),
                              ];
                            }).expand((a) => a).toList()
                          )
                        )
                      )
                    ];
                  }).expand((a) => a).toList()
                )
              )
            )
          ]
        )
      );
    }).toList();
  }

  // DOES THIS WORK INSTEAD??
  List<Color> get hueColors {
    return List<int>.generate(13, (int index) => index * 60 % 360).map((degree) {
      return this.color.withHue(1.0 * degree).toColor();
    }).toList();
  }

  Widget get speedLines {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        return Row(
          children: List<int>.generate(10, (int index) => 12 - index+1).map((size) {
            return Container(
                height: 30,
                width: AppController.scale(box.maxWidth*(size * size * 0.425)/355.0),
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Colors.grey, width: 1)),
                  ),
                );
          }).toList()
        );
      }
    );
  }

  Color thumbColorFor(param, {hue, saturation, brightness}) {
    return {
      'hue': color.withHue((hue * 720) % 360).withSaturation(1).toColor(),
      'saturation': color.withHue((hue * 720) % 360).withSaturation(saturation).toColor(),
      'brightness': color.withHue((hue * 720) % 360).withSaturation(saturation).withValue(brightness).toColor(),
    }[param] ?? Colors.black;
  }

  List<Color> colorsForSlider(paramName, {hue, saturation, brightness, includeMiddleValue}) {
    // includeMiddleValue makes the sliders seem more acurate when sub-sliders are active.
    return {
      'hue': hueColors,
      'saturation': [
          color.withHue((hue ?? mode.hue.value) * 720 % 360).withSaturation(0).toColor(),
          includeMiddleValue == true ? color.withHue((hue ?? mode.hue.value) * 720 % 360).withSaturation(saturation).toColor() : null,
          color.withHue((hue ?? mode.hue.value) * 720 % 360).withSaturation(1).toColor(),
        ]..removeWhere((color) => color == null),
      'brightness': [
        Colors.black,
        includeMiddleValue == true ? color.withHue((hue ?? mode.hue.value) * 720 % 360).withSaturation(saturation ?? mode.saturation.value).withValue(brightness).toColor() : null,
        color.withHue((hue ?? mode.hue.value) * 720 % 360).withSaturation(saturation ?? mode.saturation.value).toColor(),
      ]..removeWhere((color) => color == null),
      'speed': [
        Color(0x44000000),
        Color(0x44FFFFFF),
      ],
      'density': [
        Color(0x44000000),
        Color(0x44FFFFFF),
      ]
    }[paramName] ?? null;
  }

  bool showMultiProp(paramName, {groupIndex}) {
    if (paramName == 'brightness' && showMultiProp('saturation', groupIndex: groupIndex)) return true;
    if (paramName == 'saturation' && showMultiProp('hue', groupIndex: groupIndex)) return true;

    var param = mode.getParam(paramName, groupIndex: groupIndex);
    if (groupIndex != null) return param.multiValueActive;
    return param.hasMultiValueChildren();
  }

  bool showMultiRow(paramName, {groupIndex}) {
    bool showMultiRow = false;
    if (groupIndex == null) {
      if (paramName == 'brightness' && (mode.saturation.multiValueActive || mode.hue.multiValueActive)) 
        showMultiRow = true;
      if (paramName == 'saturation' && mode.hue.multiValueActive)
        showMultiRow = true;
      showMultiRow = showMultiRow || mode.getParam(paramName).multiValueActive;
    }
    return showMultiRow || showMultiProp(paramName, groupIndex: groupIndex);
  }

  List<Map<String, int>> distinctSliderRowIndexes(paramName, {groupIndex}) {
    List<Map<String, int>> rows = [];

    if (showMultiRow(paramName, groupIndex: groupIndex))
      List.generate(Group.currentGroups.length, (currentGroupIndex) {
        if (groupIndex == null || groupIndex == currentGroupIndex) {
          if (showMultiProp(paramName)) {
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
    else rows.add({'group': groupIndex});

    return rows;
  }

  List<List<Color>> colorRowsForSlider(paramName, {groupIndex, includeMiddleValue}) {
    if (paramName == 'hue') return [hueColors];
    List<List<Color>> rows = [];


    return distinctSliderRowIndexes(paramName, groupIndex: groupIndex).map((indexes) {
      return colorsForSlider(paramName,
        includeMiddleValue: includeMiddleValue,
        hue: mode.hue.getValue(indexes: [indexes['group'], indexes['prop']]),
        brightness: mode.brightness.getValue(indexes: [indexes['group'], indexes['prop']]),
        saturation: mode.saturation.getValue(indexes: [indexes['group'], indexes['prop']]),
      );
    }).toList();
  }
}

