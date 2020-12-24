import 'package:app/helpers/duration_helper.dart';
import 'package:app/components/mode_widget.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/models/show.dart';

class ShowPreview extends StatelessWidget {
  ShowPreview({this.show, this.duration, this.contentOffset});

  Show show;
  Duration duration;
  Duration contentOffset;

  @override
  Widget build(BuildContext context) {
    contentOffset ??= Duration.zero;
    duration ??= show.duration;
    return Container(child: Column(
      children: show.modeTracks.map((elements) {
        return Flexible(
          flex: 1,
          child: Row(
            children: mapWithIndex(elements, (index, element) {
              return Flexible(
                flex: (element.duration
                  - maxDuration(Duration.zero, contentOffset - element.startOffset)
                  - maxDuration(Duration.zero, element.endOffset - contentOffset - duration)
                ).inMilliseconds,
                child: Container(
                  child: (element.objectType == 'Mode') ?
                    ModeColumn(
                      mode: element.object,
                      groupIndex: show.groupIndexFromGlobalPropIndex(index),
                      propIndex: index,
                      showImages: true,
                    ) : (element.objectType == 'Show') ?
                    ShowPreview(
                      show: element.object
                    ) : Container(decoration: BoxDecoration(color: Colors.black))
                )
              );
            }).toList()
          )
        );
      }).toList()
    ));
  }
}
