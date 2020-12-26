import 'package:app/helpers/color_filter_generator.dart';
import 'package:app/models/base_mode.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/models/group.dart';
import 'package:app/models/mode.dart';
import 'dart:math';

class RadiallySlicedModeImage extends StatelessWidget {
  RadiallySlicedModeImage({this.mode, this.size});

  Mode mode;
  num size;

  @override
  Widget build(BuildContext context) {
    bool isMultivalue = mode.isMultivalue;
    int sliceCount = isMultivalue ? Group.currentProps.length : 1;
    return CircleAvatar(
      radius: size.toDouble(),
      backgroundColor: Colors.black,
      child: Stack(
        children: mapWithIndex(hsvColorsForProps(mode, multiprop: isMultivalue), (index, color) {
          return ClipPath(
            clipper: PieClipper(
              ratio: 1 / sliceCount,
              offset: index / sliceCount,
            ),
            child: ModeImageFilter(
              mode: mode,
              hsvColor: color,
              child: CircleAvatar(
                radius: size - (size > 20 ? 5.0 : size * 0.2),
                backgroundColor: Colors.transparent,
                backgroundImage: NetworkImage(mode.image),
              ),
            )
          );
        }).toList(),
      )
    );
  }
}

class BaseModeImage extends StatelessWidget {
  BaseModeImage({this.baseMode, this.size});

  BaseMode baseMode;
  num size;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size.toDouble(),
      backgroundColor: Colors.black,
      child: CircleAvatar(
        radius: size - (size > 20 ? 5.0 : size * 0.2),
        backgroundColor: Colors.transparent,
        backgroundImage: NetworkImage(baseMode.image),
      ),
    );
  }
}


class ModeImage extends StatelessWidget {
  ModeImage({this.mode, this.size});

  Mode mode;
  num size;

  @override
  Widget build(BuildContext context) {
    return Container(
      // This is a shadow, but it looks pretty bad:
      //
      // decoration: BoxDecoration(
      //   shape: BoxShape.circle,
      //   boxShadow: [
      //     BoxShadow(
      //       color: Color(0xFF000000),
      //       spreadRadius: 1.0,
      //       blurRadius: 1.0,
      //     ),
      //   ]
      // ),
      child: CircleAvatar(
        radius: size.toDouble(),
        backgroundColor: Colors.black,
        child: ModeImageFilter(
          mode: mode,
          child: CircleAvatar(
            radius: size - (size > 20 ? 5.0 : size * 0.2),
            backgroundColor: Colors.transparent,
            backgroundImage: NetworkImage(mode.image),
          ),
        )
      )
    );
  }
}

class ModeColumn extends StatelessWidget {
  ModeColumn({
    this.fit,
    this.mode,
    this.showImages,
    this.multigroup,
    this.multiprop,
    this.groupIndex,
    this.propIndex,
  });

  Mode mode;
  BoxFit fit;
  int propIndex;
  int groupIndex;
  bool multiprop = false;
  bool multigroup = false;
  bool showImages = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        var height = box.maxHeight;
        var width = box.maxWidth;
        if (mode == null)
          return Container(
            decoration: BoxDecoration(
              color: Colors.black,
            )
          );
        else return Column(
          children: showImages == true ?
            imagesForProps(mode,
              fit: fit,
              size: height,
              vertical: true,
              groupIndex: groupIndex,
              propIndex: propIndex
            ) :
            widgetsForProps(mode),
        );
      }
    );
  }
}

class ModeRow extends StatelessWidget {
  ModeRow({this.mode, this.showImages, this.fit});

  Mode mode;
  BoxFit fit;
  bool showImages = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        var height = box.maxHeight;
        var width = box.maxWidth;
        return Row(
          children: showImages == true ?
            imagesForProps(mode, size: height, fit: fit) :
            widgetsForProps(mode),
        );
      }
    );
  }
}

Widget ModeImageFilter({mode, hsvColor, child}) {
  hsvColor = hsvColor ?? mode.getHSVColor();


  // return ColorFiltered(
  //   colorFilter: ColorFilter.matrix(
  //     ColorFilterGenerator.brightnessAdjustMatrix(
  //       initialValue: mode.initialValue('brightness'),
  //       value: hsvColor.value,
  //     )
  //   ),
  //   child: child
  // );



  // THIS IS NOT WORKING IN WEB:::::::::::::::::::::::::::::::
  // THIS IS NOT WORKING IN WEB:::::::::::::::::::::::::::::::
  // THIS IS NOT WORKING IN WEB:::::::::::::::::::::::::::::::
  // THIS IS NOT WORKING IN WEB:::::::::::::::::::::::::::::::
  return ColorFiltered(
    colorFilter: ColorFilter.matrix(
      ColorFilterGenerator.brightnessAdjustMatrix(
        initialValue: mode.initialValue('brightness'),
        value: hsvColor.value,
      )
    ),
    child: ColorFiltered(
      colorFilter: ColorFilter.matrix(
        ColorFilterGenerator.saturationAdjustMatrix(
          initialValue: mode.initialValue('saturation'),
          value: hsvColor.saturation,
        )
      ),
      child: ColorFiltered(
        colorFilter: ColorFilter.matrix(
          ColorFilterGenerator.hueAdjustMatrix(
            initialValue: mode.initialValue('hue'),
            value: hsvColor.hue / 360,
          )
        ),
        child: child,
      )
    )
  );
}

List<HSVColor> hsvColorsForProps(mode, {multiprop, multigroup, groupIndex, propIndex}) {
  groupIndex ??= mode.groupIndex;
  propIndex ??= mode.propIndex;
  List<HSVColor> params = [];
  eachWithIndex(Group.currentGroups, (_groupIndex, group) {
    if (groupIndex == null || groupIndex == _groupIndex)
      eachWithIndex(group.props, (_propIndex, prop) {
        if (propIndex == null || propIndex == _propIndex)
          params.add(mode.getHSVColor(groupIndex: _groupIndex, propIndex: _propIndex));
      });
  });
  if (params.isEmpty)
    params = [mode.getHSVColor()];
  return params;
}


List<Color> colorsForProps(mode) {
  bool isMultivalue = mode.isMultivalue;
  return hsvColorsForProps(mode, multiprop: mode.isMultivalue).map((hsvColor) {
    return hsvColor.toColor();
  }).toList();
}

List<Widget> widgetsForProps(mode) {
  var colors = colorsForProps(mode);
  return colors.map((color) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: color,
        )
      )
    );
  }).toList();
}

List<Widget> imagesForProps(mode, {size, fit, vertical, groupIndex, propIndex, multiprop, multigroup}) {
  // var colors = hsvColorsForProps(mode, multiprop: mode.isMultivalue);
  var colors = hsvColorsForProps(mode, groupIndex: groupIndex, propIndex: propIndex, multiprop: multiprop);
  vertical = vertical ?? false;
  return colors.map((color) {
    return Expanded(
      child: ClipRect(
        child: SingleChildScrollView(
          physics: NeverScrollableScrollPhysics(),
          child: Container(
            height: (mode.hasTrailImage ? 1 : 4) * (size ?? 500) / (vertical ? colors.length : 1),
            child: ModeImageFilter(
              hsvColor: color,
              mode: mode,
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    fit: fit ?? BoxFit.cover,
                    image: NetworkImage(mode.hasTrailImage ? mode.trailImage : mode.image),
                  ),
                )
              )
            )
          ),
        )
      )
    );
  }).toList();
}

  Widget ModeColumnForShow({Mode mode, int groupIndex, int propIndex, double invisibleLeftRatio, double invisibleRightRatio}) {
    invisibleRightRatio ??= 0.0;
    invisibleLeftRatio ??= 0.0;
    var colors = hsvColorsForProps(mode, groupIndex: groupIndex, propIndex: propIndex);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        var height = box.maxHeight;
        var width = box.maxWidth;
        if (mode == null)
          return Container( decoration: BoxDecoration( color: Colors.black));
        else {
          return Column(
            children: colors.map((color) {
              double xAlignment = invisibleLeftRatio == 0 ? -1.0 : 1.0; 
              if (invisibleLeftRatio > 0 && invisibleRightRatio > 0)
                xAlignment = (invisibleLeftRatio - invisibleRightRatio) / (invisibleLeftRatio + invisibleRightRatio);
              return Expanded(
                child: ClipRect(
                    child: FractionallySizedBox(
                      widthFactor: max(0, 1 / (1 - (invisibleRightRatio + invisibleLeftRatio))),
                      heightFactor: (mode.hasTrailImage ? 1 : 4),
                      alignment: Alignment(xAlignment, 1),
                      child: ModeImageFilter(
                        hsvColor: color,
                        mode: mode,
                        child: Container(
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              fit: BoxFit.cover,
                              image: NetworkImage(mode.hasTrailImage ? mode.trailImage : mode.image),
                            ),
                          )
                        )
                      )
                    )
                  )
                // )
              );
            }).toList()
          );
        }
      });
  }

