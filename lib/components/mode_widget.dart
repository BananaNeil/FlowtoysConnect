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
  ModeColumn({this.mode, this.showImages, this.fit});

  Mode mode;
  BoxFit fit;
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
            imagesForProps(mode, size: height, fit: fit, vertical: true) :
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

List<HSVColor> hsvColorsForProps(mode, {multiprop, multigroup}) {
  List<HSVColor> params = [];
  if (multiprop == true) {
    if (mode.childType == null)
      params.add(mode.getHSVColor(groupIndex: mode.groupIndex, propIndex: mode.propIndex));
    else if (mode.childType == 'prop')
      List.generate(mode.childCount, (childIndex) {
        params.add(mode.getHSVColor(groupIndex: mode.groupIndex, propIndex: childIndex));
      });
    else
      eachWithIndex(Group.currentGroups, (groupIndex, group) {
        eachWithIndex(group.props, (propIndex, prop) {
          params.add(mode.getHSVColor(groupIndex: groupIndex, propIndex: propIndex));
        });
      });
  } else if (multigroup == true)
    if (mode.childType == null)
      params.add(mode.getHSVColor(groupIndex: mode.groupIndex, propIndex: mode.propIndex));
    else if (mode.childType == 'prop')
      params.add(mode.getHSVColor(groupIndex: mode.groupIndex));
    else
      eachWithIndex(Group.currentGroups, (groupIndex, group) {
        params.add(mode.getHSVColor(groupIndex: groupIndex));
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

List<Widget> imagesForProps(mode, {size, fit, vertical}) {
  // var colors = hsvColorsForProps(mode, multiprop: mode.isMultivalue);
  var colors = hsvColorsForProps(mode, multiprop: true);
  if (!mode.isMultivalue)
    colors = colors.sublist(0, min(colors.length, 6));
  vertical = vertical ?? false;
  return colors.map((color) {
    return Expanded(
      child: ClipRect(
        child: SingleChildScrollView(
          physics: NeverScrollableScrollPhysics(),
          child: Container(
              // height: size,
              // height: size / colors.length,
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
