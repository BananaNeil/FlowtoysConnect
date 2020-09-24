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

  Widget ParamSlider(param, {title, children}) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                if (param.presentChildParams.isNotEmpty) {
                  param.toggleMultiValue();
                  _updateMode();
                }
              });
            },
            child: Row(
              children: [
                Text(title, style: TextStyle(
                  fontSize: 16//, fontWeight: FontWeight.bold
                )),
                Visibility(
                  visible: children != null,
                  child: param.multiValueEnabled ? Icon(Icons.expand_more) : Icon(Icons.chevron_right),
                ),
              ]
            )
          ),
          SliderPicker(
            min: 0,
            max: 1,
            height: sliderHeight,
            value: param.getValue(),
            colorRows: gradients(param),
            gradientStops: gradientStops(param),
            thumbColor: thumbColorFor(param),
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
      "brightness",
      "saturation",
      "hue",
      "speed",
      "density",
    ].map((paramName) {
      ModeParam param = mode.getParam(paramName);

      return ParamSlider(param,
        title: toBeginningOfSentenceCase(paramName),
        children: !param.multiValueEnabled ? emptyList : mapWithIndex(param.presentChildParams, (groupIndex, childParam) {
          Group group = Group.currentGroups[groupIndex];
          return ParamSlider(childParam,
            title: "${group.name} (${group.props.length})",
            children: !childParam.multiValueEnabled ? emptyList : mapWithIndex(childParam.presentChildParams, (propIndex, propParam) {
              return ParamSlider(propParam, title: "Prop #${propIndex + 1}");
            }).toList(),
          );
        }).toList(),
      ); 
    }).toList();
  }

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

  Color thumbColorFor(param) {
    if (showMultiRow(param))
      if (param.paramName == 'hue')
        return Colors.white;
      else return Colors.transparent;

    var hue = param.mode.getValue('hue', groupIndex: param.groupIndex, propIndex: param.propIndex);
    var brightness = param.mode.getValue('brightness', groupIndex: param.groupIndex, propIndex: param.propIndex);
    var saturation = param.mode.getValue('saturation', groupIndex: param.groupIndex, propIndex: param.propIndex);

    return {
      'hue': color.withHue((hue * 720) % 360).withSaturation(1).toColor(),
      'saturation': color.withHue((hue * 720) % 360).withSaturation(saturation).toColor(),
      'brightness': color.withHue((hue * 720) % 360).withSaturation(saturation).withValue(brightness).toColor(),
    }[param.paramName] ?? Colors.black;
  }

  List<Color> gradientColors(param, {hue, saturation, brightness}) {
    // includeMiddleValue makes the sliders seem more acurate when sub-sliders are active.
    return {
      'hue': hueColors,
      'saturation': [
          color.withHue((hue ?? mode.hue.value) * 720 % 360).withSaturation(0).toColor(),
          param.multiValueActive == true ? color.withHue((hue ?? mode.hue.value) * 720 % 360).withSaturation(saturation).toColor() : null,
          color.withHue((hue ?? mode.hue.value) * 720 % 360).withSaturation(1).toColor(),
        ]..removeWhere((color) => color == null),
      'brightness': [
        Colors.black,
        param.multiValueActive == true ? color.withHue((hue ?? mode.hue.value) * 720 % 360).withSaturation(saturation ?? mode.saturation.value).withValue(brightness).toColor() : null,
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
    }[param.paramName] ?? null;
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

