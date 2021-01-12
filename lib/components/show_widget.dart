import 'package:app/helpers/duration_helper.dart';
import 'package:app/models/timeline_element.dart';
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
        var visibleElements = elements.where((element) {
          return element.endOffset > contentOffset && element.startOffset < contentOffset + duration;
        }).toList();
        var lastEndOffset = visibleElements.isEmpty ? Duration.zero : visibleElements.last.endOffset;
        visibleElements.add(TimelineElement(
          startOffset: lastEndOffset,
          duration: maxDuration(Duration.zero, duration - contentOffset - lastEndOffset),
        ));
        return Flexible(
          flex: 1,
          child: Row(
            children: mapWithIndex(visibleElements, (index, element) {
              var invisibleLeft = maxDuration(Duration.zero, contentOffset - element.startOffset);
              var invisibleRight = maxDuration(Duration.zero, element.endOffset - (duration + contentOffset));
              var visibleDuration = element.duration - invisibleLeft - invisibleRight;

              return Flexible(
                flex: visibleDuration.inMicroseconds,
                child: Stack(
                  children: [
                    Container(
                      child: (element.objectType == 'Mode') ?
                        ModeColumnForShow(
                          invisibleLeftRatio: durationRatio(invisibleLeft, element.duration),
                          invisibleRightRatio: durationRatio(invisibleRight, element.duration),
                          groupIndex: show.groupIndexFromGlobalPropIndex(index),
                          mode: element.object,
                          propIndex: index,
                          // showImages: true,
                        ) : (element.objectType == 'Show') ?
                        ShowPreview(
                          show: element.object,
                          duration: visibleDuration,
                        ) : Container(decoration: BoxDecoration(color: Colors.black))
                    ),
                    Container(
                      // height: 10,
                      width: 1,
                      decoration: BoxDecoration(
                        color: Color(0x88FFFFFF),
                      )
                    ),
                  ]
                )
              );
            }).toList()
          )
        );
      }).toList()
    ));
  }
}
