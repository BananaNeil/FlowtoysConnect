import 'package:flutter_hsvcolor_picker/flutter_hsvcolor_picker.dart';
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

class _InlineModeParamsState extends State<InlineModeParams> {
  _InlineModeParamsState({this.mode});

  final Mode mode;
  String showSlider;
  double containerWidth;
  double initialValue;

  var params = [
    'adjust',
    'hue',
    'saturation',
    'brightness',
    'density',
    'speed',
  ];

  List<Color> get hueColors {
    var color = HSVColor.fromColor(Colors.blue);
    return List<int>.generate(13, (int index) => index * 60 % 360).map((degree) {
      return color.withHue(1.0 * degree).toColor();
    }).toList();
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

  @override
  build(BuildContext context) {
    var color = mode.getHSVColor();
    var colors = {
      'hue': color.withSaturation(1.0).withValue(1.0).toColor(),
      'saturation': color.withValue(1.0).toColor(),
      'brightness': color.toColor(),
    };

    Map<String, List<Color>> gradients = {
      'hue': hueColors,
      'saturation': [color.withValue(1.0).withSaturation(0.0).toColor(), color.withValue(1.0).withSaturation(1.0).toColor()],
      'brightness': [color.withValue(0.0).toColor(), color.withValue(1.0).toColor()],
      'adjust': [Colors.grey, Colors.grey],
    };
    var icons = {
      'adjust': Container(padding: EdgeInsets.all(5), child: Image(image: AssetImage('assets/images/adjust.png'))),
      'brightness': Icon(Icons.brightness_medium, size: 22),
      'saturation': Icon(Icons.opacity, size: 22),
      'speed': Icon(Icons.fast_forward, size: 22),
      'hue': Icon(Icons.color_lens, size: 22),
      'density': Icon(Icons.waves, size: 22),
    };

    if (showSlider != null)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(toBeginningOfSentenceCase(showSlider)),
          SliderPicker(
            min: 0,
            max: showSlider == 'hue' ? 2.0 : 1.0,
            height: 30,
            value: mode.getValue(showSlider).clamp(0.0, showSlider == 'hue' ? 2.0 : 1.0),
            colorRows: [gradients[showSlider]],
            // gradientStops: gradientStops(param),
            // thumbColor: thumbColorFor(param),
            onChanged: (value){
              // onChange(mode);
              // updateModeTimer?.cancel();
              // setState(() => param.setValue(value));
              // updateModeTimer = Timer(Duration(milliseconds: 1000), () => _updateMode());
            },
            child: speedLines
          )
        ]
      );



    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        containerWidth = box.maxWidth;

        double dx = 0;

        return Listener(
          onPointerDown: (PointerEvent details) {
            var index = (params.length * details.localPosition.dx / containerWidth).floor();
            showSlider = params[index];
            initialValue =  mode.getValue(showSlider);
            if (this.mounted)
              setState(() {});
            widget.onTouchDown();
          },
          onPointerUp: (PointerEvent details) {
            showSlider = null;
            dx = null;

            if (this.mounted)
              setState(() {});
            widget.onTouchUp();
          },
          onPointerMove: (PointerEvent details) {
            dx += details.delta.dx;

            var val = mode.getValue(showSlider);
            var delta;
            delta = 2 * (dx) / containerWidth;
            delta *= 2 * (1 + (initialValue - (params.indexOf(showSlider) / params.length)).abs()); 
            mode.getParam(showSlider).setValue(initialValue + delta);
            if (this.mounted)
              setState(() {});
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: params.map<Widget>((paramName) {
              if (paramName == null)
                return Container(width: 0);


              var gradientBlackSpace = 0.1;
              var adjustmentRange = (1 - 2 * gradientBlackSpace);
              var gradientsForParam = gradients[paramName] ?? [Colors.black, Colors.white];
              var gradientStopCount = gradientsForParam.length;
              var gradientStops = List.generate(gradientStopCount, (index) {
                var ratio = index / (gradientStopCount - 1);
                return gradientBlackSpace + ratio * adjustmentRange;
              });
              gradientStops.insert(0, gradientStops.first);
              gradientStops.add(gradientStops.last);

              var rotationOffset = adjustmentRange * pi;
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
                  Transform(
                    alignment: FractionalOffset.center,
                    // transform: Matrix4.rotationZ(2 * pi * mode.getValue(paramName)),
                    transform: Matrix4.rotationZ(adjustmentRange * 2 * pi * paramValue - rotationOffset),
                    child: Container(
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
                    ),
                  ),
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
            }).toList()
          )
        );
      }
    );
  }

  // bool awaitingResponse = false;
  // bool editDetails = false;
  // Timer updateModeTimer;
  // String errorMessage;
  // num sliderHeight;
  //
  // HSVColor color = HSVColor.fromColor(Colors.blue);
  //
  // bool get autoUpdate => widget.autoUpdate ?? true;
  //
  // Function get onChange => widget.onChange ?? (mode){};
  //
  // @override initState() {
  //   super.initState();
  //   Preloader.getCachedBaseModes().then((cachedBaseModes) {
  //     setState(() => baseModes = cachedBaseModes);
  //     Client.getBaseModes().then((response) {
  //       if (response['success'])
  //         setState(() => baseModes = response['baseModes']);
  //     });
  //   });
  // }
  //
  // @override
  // Widget build(BuildContext context) {
  //   return Container(
  //     decoration: BoxDecoration(color: Color(0xFF2F2F2F)),
  //     child: Column(
  //       children: [
  //         Container(
  //           height: 25,
  //           margin: EdgeInsets.only(top: 5),
  //           child: ModeRow(
  //             mode: mode,
  //             showImages: true,
  //             fit: BoxFit.fill,
  //           ),
  //         ),
  //         Expanded(
  //           child: ListView(
  //             padding: EdgeInsets.all(20),
  //             children: [
  //               _RenameField(),
  //               _ChooseBaseMode(),
  //               ..._Sliders(),
  //             ],
  //           ),
  //         ),
  //       ]
  //     )
  //   );
  // }
  //
  // Future<void> _updateMode() {
  //   if (autoUpdate != true) return Future.value(null);
  //   setState(() { awaitingResponse = true; });
  //   return Client.updateMode(mode).then((response) {
  //     setState(() {
  //       if (response['success']) {
  //         awaitingResponse = false;
  //         errorMessage = null;
  //       } else errorMessage = response['message'];
  //     });
  //   });
  // }
  //
  // bool get canEditDetails =>
  //   mode != null && mode.accessLevel != 'frozen' && editDetails == true;
  //
  // Widget _ChooseBaseMode() {
  //   if (!canEditDetails) return Container();
  //   return Stack(
  //     children: [
  //       Text("Choose Base Mode",
  //         style: TextStyle(
  //           color: Color(0xFF999999),
  //           fontSize: 12,
  //         ),
  //       ),
  //       Container(
  //         width: 250,
  //         margin: EdgeInsets.only(bottom: 20, top: 5),
  //         child: DropdownButton(
  //           isExpanded: true,
  //           value: (mode.baseModeId ?? baseModes.elementAt(0)?.id)?.toString(),
  //           items: baseModes.map((BaseMode baseMode) {
  //             return DropdownMenuItem<String>(
  //               value: baseMode.id.toString(),
  //               child: Row(
  //                 children: [
  //                   Container(
  //                     margin: EdgeInsets.only(right: 7),
  //                     child: BaseModeImage(baseMode: baseMode, size: 12),
  //                   ),
  //                   Text(baseMode.name),
  //                 ]
  //               )
  //             );
  //           }).toList(),
  //           onChanged: (value) {
  //             setState(() {
  //               mode.updateBaseModeId(value);
  //               onChange(mode);
  //             });
  //             _updateMode();
  //           },
  //         ),
  //       )
  //     ]
  //   );
  // }
  //
  // Widget _RenameField() {
  //   if (!canEditDetails) return Container();
  //   return Container(
  //     width: 250,
  //     padding: EdgeInsets.only(bottom: 30),
  //     child: TextFormField(
  //       initialValue: mode.name,
  //       decoration: InputDecoration(
  //         labelText: 'Choose custom name',
  //       ),
  //       onChanged: (text) {
  //         setState(() {
  //           updateModeTimer?.cancel();
  //           mode.name = text;
  //           updateModeTimer = Timer(Duration(milliseconds: 1000), () => _updateMode());
  //         });
  //       }
  //     )
  //   );
  // }
  //
  // Widget ParamSlider(param, {title, children, onReset, margin}) {
  //   print("SLIDER FOR ${title} ${param.paramName} ::: ${param.multiValueEnabled}");
  //   return Container(
  //     margin: margin ?? EdgeInsets.only(bottom: 10),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         GestureDetector(
  //           onTap: () {
  //             setState(() {
  //                 param.toggleMultiValue();
  //                 _updateMode();
  //             });
  //           },
  //           child: Row(
  //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //             children: [
  //               Row(
  //                 children: [
  //                   Text(title, style: TextStyle(
  //                     fontSize: 16//, fontWeight: FontWeight.bold
  //                   )),
  //                   Visibility(
  //                     visible: children != null,
  //                     child: param.multiValueEnabled ? Icon(Icons.expand_more) : Icon(Icons.chevron_right),
  //                   ),
  //                 ]
  //               ),
  //               Container(
  //                 child: onReset == null ? null : GestureDetector(
  //                   onTap: onReset,
  //                   child: Transform(
  //                     alignment: Alignment.center,
  //                     transform: Matrix4.rotationY(pi),
  //                     child: Icon(Icons.refresh),
  //                   )
  //                 )
  //               )
  //             ]
  //           )
  //         ),
  //         SliderPicker(
  //           min: 0,
  //           max: param.paramName == 'hue' ? 2.0 : 1.0,
  //           height: sliderHeight,
  //           value: param.getValue().clamp(0.0, param.paramName == 'hue' ? 2.0 : 1.0),
  //           colorRows: gradients(param),
  //           gradientStops: gradientStops(param),
  //           thumbColor: thumbColorFor(param),
  //           onChanged: (value){
  //             onChange(mode);
  //             updateModeTimer?.cancel();
  //             setState(() => param.setValue(value));
  //             updateModeTimer = Timer(Duration(milliseconds: 1000), () => _updateMode());
  //           },
  //           child: speedLines
  //         ),
  //         Visibility(
  //           visible: param.multiValueEnabled,
  //           child: Padding(
  //             padding: EdgeInsets.only(left: 30),
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: children ?? [],
  //             )
  //           )
  //         )
  //       ]
  //     )
  //   );
  // }
  //
  //
  // List<Widget> _Sliders() {
  //   List<Widget> emptyList = [];
  //   return [
  //     "brightness",
  //     "saturation",
  //     "hue",
  //     "speed",
  //     "density",
  //   ].map((paramName) {
  //     ModeParam param = mode.getParam(paramName);
  //
  //     return ParamSlider(param,
  //       margin: EdgeInsets.only(bottom: 20),
  //       title: toBeginningOfSentenceCase(paramName),
  //       onReset: () {
  //         setState(() => mode.resetParam(paramName));
  //         onChange(mode);
  //         _updateMode();
  //       },
  //       children: !param.multiValueEnabled ? emptyList : mapWithIndex(param.presentChildParams, (groupIndex, childParam) {
  //         print("RENDER GROUPS: ${childParam.mode} ------------- ${groupIndex}");
  //         Group group = Group.currentGroups[groupIndex];
  //         return ParamSlider(childParam,
  //           title: "${group.name} (${group.props.length})",
  //           children: !childParam.multiValueEnabled ? emptyList : mapWithIndex(childParam.presentChildParams, (propIndex, propParam) {
  //             return ParamSlider(propParam, title: "Prop #${propIndex + 1}");
  //           }).toList(),
  //         );
  //       }).toList(),
  //     ); 
  //   }).toList();
  // }
  //
  // List<Color> get hueColors {
  //   return List<int>.generate(13, (int index) => index * 60 % 360).map((degree) {
  //     return this.color.withHue(1.0 * degree).toColor();
  //   }).toList();
  // }
  //
  // Widget get speedLines {
  //   return Row(
  //     children: List<int>.generate(17, (int index) => 17 - index+1).map((size) {
  //       return Flexible(
  //           flex: size * size,
  //           child: Container(
  //           height: 30,
  //             decoration: BoxDecoration(
  //               border: Border(right: BorderSide(color: Colors.grey, width: 1)),
  //             ),
  //           )
  //       );
  //     }).toList()
  //   );
  // }
  //
  // Color thumbColorFor(param) {
  //   if (showMultiRow(param))
  //     if (param.paramName == 'hue')
  //       return Colors.white;
  //     else return Colors.transparent;
  //
  //   var hue = param.mode.getValue('hue', groupIndex: param.groupIndex, propIndex: param.propIndex);
  //   var brightness = param.mode.getValue('brightness', groupIndex: param.groupIndex, propIndex: param.propIndex);
  //   var saturation = param.mode.getValue('saturation', groupIndex: param.groupIndex, propIndex: param.propIndex);
  //
  //   return {
  //     'hue': color.withHue((hue * 360) % 360).withSaturation(1).toColor(),
  //     'saturation': color.withHue((hue * 360) % 360).withSaturation(saturation).toColor(),
  //     'brightness': color.withHue((hue * 360) % 360).withSaturation(saturation).withValue(brightness).toColor(),
  //   }[param.paramName] ?? Colors.black;
  // }
  //
  // List<Color> gradientColors(param, {hue, saturation, brightness}) {
  //   // includeMiddleValue makes the sliders seem more acurate when sub-sliders are active.
  //   return {
  //     'hue': hueColors,
  //     'saturation': [
  //         color.withHue((hue ?? mode.hue.value) * 360 % 360).withSaturation(0).toColor(),
  //         param.multiValueActive == true ? color.withHue((hue ?? mode.hue.value) * 360 % 360).withSaturation(saturation).toColor() : null,
  //         color.withHue((hue ?? mode.hue.value) * 360 % 360).withSaturation(1).toColor(),
  //       ]..removeWhere((color) => color == null),
  //     'brightness': [
  //       Colors.black,
  //       param.multiValueActive == true ? color.withHue((hue ?? mode.hue.value) * 360 % 360).withSaturation(saturation ?? mode.saturation.value).withValue(brightness).toColor() : null,
  //       color.withHue((hue ?? mode.hue.value) * 360 % 360).withSaturation(saturation ?? mode.saturation.value).toColor(),
  //     ]..removeWhere((color) => color == null),
  //     'speed': [
  //       Color(0x44000000),
  //       Color(0x44FFFFFF),
  //     ],
  //     'density': [
  //       Color(0x44000000),
  //       Color(0x44FFFFFF),
  //     ]
  //   }[param.paramName] ?? null;
  // }
  //
  // bool showMultiProp(param) {
  //   if (param.paramName == 'brightness' && showMultiProp(param.getSiblingParam('saturation'))) return true;
  //   if (param.paramName == 'saturation' && showMultiProp(param.getSiblingParam('hue'))) return true;
  //
  //   if (param.groupIndex != null) return param.multiValueActive;
  //   return param.hasMultiValueChildren();
  // }
  //
  // bool showMultiRow(param) {
  //   bool showMultiRow = false;
  //   if (param.propIndex != null)
  //     return false;
  //   else if (param.groupIndex == null) {
  //     if (param.paramName == 'brightness' && (param.mode.saturation.multiValueActive || param.mode.hue.multiValueActive))
  //       showMultiRow = true;
  //     if (param.paramName == 'saturation' && param.mode.hue.multiValueActive)
  //       showMultiRow = true;
  //     showMultiRow = showMultiRow || param.mode.getParam(param.paramName).multiValueActive;
  //   }
  //   return showMultiRow || showMultiProp(param);
  // }
  //
  // List<Map<String, int>> distinctSliderRowIndexes(param) {
  //   List<Map<String, int>> rows = [];
  //
  //   if (showMultiRow(param))
  //     List.generate(Group.currentGroups.length, (currentGroupIndex) {
  //       if (param.groupIndex == null || param.groupIndex == currentGroupIndex) {
  //         if (showMultiProp(param)) {
  //           var propCount = Group.currentGroups[currentGroupIndex].props.length;
  //           List.generate(propCount, (i) => i).forEach((propIndex) {
  //             rows.add({
  //               'group': currentGroupIndex,
  //               'prop': propIndex,
  //             });
  //           }); 
  //         } else {
  //           rows.add({ 'group': currentGroupIndex });
  //         }
  //       }
  //     });
  //   else rows.add({'group': param.groupIndex});
  //
  //   return rows;
  // }
  //
  // List<double> gradientStops(param) {
  //   if (param.paramName != 'hue' && param.multiValueActive)
  //     return [0.0, param.getValue(), 1.0];
  // }
  //
  // List<List<Color>> gradients(param) {
  //   if (param.paramName == 'hue') return [hueColors];
  //   List<Map<String, int>> indexes;
  //   List<List<Color>> rows = [];
  //
  //   if (param.propIndex == null)
  //     indexes = distinctSliderRowIndexes(param);
  //   else
  //     indexes = [{'group': param.groupIndex, 'prop': param.propIndex}];
  //
  //
  //   return indexes.map((indexes) {
  //     return gradientColors(param,
  //       hue: param.mode.hue.getValue(indexes: [indexes['group'], indexes['prop']]),
  //       brightness: param.mode.brightness.getValue(indexes: [indexes['group'], indexes['prop']]),
  //       saturation: param.mode.saturation.getValue(indexes: [indexes['group'], indexes['prop']]),
  //     );
  //   }).toList();
  // }
}


