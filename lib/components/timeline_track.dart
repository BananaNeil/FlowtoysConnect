import 'package:flutter_hsvcolor_picker/flutter_hsvcolor_picker.dart';
import 'package:app/models/timeline_element.dart';
import 'package:app/helpers/duration_helper.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:async';
import 'dart:math';

class TimelineTrackWidget extends StatefulWidget {
  TimelineTrackWidget({
    Key key,
    this.onReorder,
    this.controller,
    this.windowStart,
    this.buildElement,
    this.onScrollUpdate,
    this.selectMultiple,
    this.onStretchUpdate,
    this.visibleDuration,
    this.timelineDuration,
    this.slideWhenStretching,
    this.futureVisibleDuration,
  }) : super(key: key);

  final TimelineTrackController controller;
  Duration futureVisibleDuration;
  Duration timelineDuration;
  bool slideWhenStretching;
  Duration visibleDuration;
  Function onStretchUpdate;
  Function onScrollUpdate;
  Function buildElement;
  Duration windowStart;
  bool selectMultiple;
  Function onReorder;

  @override
  _TimelineTrackState createState() => _TimelineTrackState();
}

class _TimelineTrackState extends State<TimelineTrackWidget> with TickerProviderStateMixin {
  _TimelineTrackState();

  TimelineTrackController get controller => widget.controller;
  List<TimelineElement> get selectedElements => controller.selectedElements;

  Duration get windowStart => widget.windowStart;
  bool get selectMultiple => widget.selectMultiple;

  bool get slideWhenStretching => widget.slideWhenStretching;
  bool get isActingOnSelected => isStretching || isReordering;
  bool get isStretching => selectionStretch['right'] != 1 || selectionStretch['left'] != 1;

  String get stretchedSide => selectionStretch.keys.firstWhere((key) => selectionStretch[key] != 1 );
  double get stretchedValue => selectionStretch[stretchedSide];

  Duration dragDelta = Duration();
  bool isReordering = false;
  Timer dragScrollTimer;

  Map<String, double> selectionStretch = {
    'left': 1.0,
    'right': 1.0,
  };

  double get milisecondsPerPixel => visibleMiliseconds / containerWidth;
  Duration get futureVisibleDuration => widget.futureVisibleDuration;
  int get visibleMiliseconds => visibleDuration.inMilliseconds;
  Duration get visibleDuration => widget.visibleDuration;
  Duration get windowEnd => windowStart + visibleDuration;

  double containerWidth = 0;


  visibleDurationOf(element) {
    var elementVisibleDuration;
    if (element.startOffset < windowStart)
      elementVisibleDuration = minDuration(visibleDuration, element.endOffset - windowStart);
    else if (element.endOffset > windowEnd)
      elementVisibleDuration = minDuration(visibleDuration, windowEnd - element.startOffset);
    else elementVisibleDuration = element.duration;

    return minDuration(elementVisibleDuration, element.duration);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        containerWidth = box.maxWidth;
        return Stack(
          children: [
            _Elements(),
            _SelectedElementHandles(),
          ]
        );
      }
    );
  }

  void toggleSelected(element, {only}) {
    setState(() {
      var isSelected = selectedElements.contains(element);
      if (isSelected && only != 'select') 
        controller.selectedElements.remove(element);
      else if (selectMultiple)
        controller.selectedElements.add(element);
      else
        controller.selectedElements = [element];

      controller.selectedElements.sort((a, b) => a.startOffset.compareTo(b.startOffset));
    });
  }

  // Visible Elements
  List<TimelineElement> get elements {
    return controller.elements.where((element) {
      return element.startOffset <= windowEnd &&
        element.endOffset >= windowStart;
    }).toList();
  }

  TimelineElement elementAtTime(time) {
    return elements.firstWhere((element) {
       return element.startOffset <= time &&
           element.endOffset > time;
    });
  }

  void triggerDragScroll(movementAmount) {
    dragScrollTimer?.cancel();
    dragScrollTimer = Timer(Duration(milliseconds: 50), () => setState(() {
      dragDelta += movementAmount;
    }));
  }

  TimelineElement get stretchedSibling {
    var index;
    if (!isStretching) return null;
    if (stretchedSide == 'left')
      index = elements.indexOf(selectedElements.first) - 1;
    else
      index = elements.indexOf(selectedElements.last) + 1;
    return elements.elementAt(index);
  }

  // Duration get invisibleDurationOfLastVisibleWaveform {
  //   if (audioPlayers.isEmpty || futureScale == scale) return Duration();
  //   var waveform = visibleWaveforms.last;
  //   return waveform.endOffset - windowEnd;
  // }

  Widget _Elements() {
    return RawGestureDetector(
      gestures: timelineGestures,
      child:  Row(
        children: mapWithIndex(elements, (index, element) {
          var isSelected = selectedElements.contains(element);
          Duration elementVisibleDuration = visibleDurationOf(element);
          if (isSelected && isReordering)
            if (element == selectedElements[0])
              elementVisibleDuration = selectedDuration;
            else elementVisibleDuration = Duration();

          return Flexible(
            flex: ((elementVisibleDuration.inMilliseconds / (futureVisibleDuration.inMilliseconds)).clamp(0.0, 1.0) * 1000.0).ceil(),
              child: Container(
                decoration: BoxDecoration(
                  border: (isSelected && !isActingOnSelected) ? Border.all(color: Colors.white, width: 2) : 
                    Border(
                      top: BorderSide(color: Color(0xFF555555), width: 2),
                      bottom: BorderSide(color: Color(0xFF5555555), width: 2),
                    )
                ),
                child: Stack(
                  children: (isSelected && isActingOnSelected) ? [
                    isStretching && !slideWhenStretching ? widget.buildElement(stretchedSibling) : Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          const BoxShadow(
                            color: Color(0xAA000000),
                          ),
                          const BoxShadow(
                            color: Color(0xFF333333),
                            spreadRadius: -4.0,
                            blurRadius: 4.0,
                          ),
                        ],
                      ),
                    )
                  ] : [
                     widget.buildElement(element),
                     Container(
                       width: stretchedSibling == element ? 0 : 1,
                       decoration: BoxDecoration(
                          color: Color(0xBBFFFFFF),
                          border: Border(
                            top: BorderSide(color: Color(0x00000000), width: 2),
                            bottom: BorderSide(color: Color(0x00000000), width: 2),
                          )
                       ),
                     )
                  ]
                )
              )
          );
        }).toList() + [
        //   Flexible(
        //   flex: ((!timelineContainsEnd ? 0 : invisibleDurationOfLastVisibleWaveform.inMilliseconds / futureVisibleMiliseconds) * 1000).toInt(),
        //   child: Container(),
        // )
        ]
      )
    );
  }

  void updateStretch({side, dx, maxStretch, visiblySelectedRatio}) {
    setState(() {
      selectionStretch[side] += 3 * dx / visiblySelectedRatio;
      selectionStretch[side] = selectionStretch[side].clamp(0.0, maxStretch);
    });
  }

  List<int> get selectedElementIndexes => controller.selectedElementIndexes;

  bool get selectedElementsAreConsecutive => controller.selectedElementsAreConsecutive;

  List<TimelineElement> get consecutivelySelectedElements => controller.consecutivelySelectedElements;

  Duration get selectedDuration => controller.selectedDuration;

  Widget _SelectedElementHandles() {
    if (consecutivelySelectedElements.isEmpty)
      return Container();

    var firstElement = consecutivelySelectedElements.first;
    var lastElement = consecutivelySelectedElements.last;
    var visibleSelectedDuration;
    var end;
    var start;

    if (isReordering) {
      visibleSelectedDuration = selectedDuration;
      start = maxDuration(Duration(), firstElement.startOffset - windowStart + dragDelta);
      start = minDuration(start, visibleDuration - selectedDuration);
      end = start + selectedDuration;

      // This is a bunch of logic that auto scrolls the timeline
      // when dragging modes close to the start or end and probably
      // needs to be moved into a gesterdetector? Bleh...
      var triggerPoint = visibleDuration * 0.05;
      var movementAmount = minDuration(Duration(seconds: 5), widget.timelineDuration * 0.01);

      if (start <= triggerPoint) {
        movementAmount *= -1;
        widget.windowStart += minDuration(movementAmount, start);
        widget.onScrollUpdate(windowStart);
        if (windowStart.inMilliseconds > 0)
          triggerDragScroll(movementAmount);

      } else if (end >= visibleDuration - triggerPoint) {
        widget.windowStart += movementAmount;
        widget.onScrollUpdate(windowStart);
        if (windowStart < (widget.timelineDuration - visibleDuration))
          triggerDragScroll(movementAmount);
      }
    } else { // if !isReordering
      visibleSelectedDuration = consecutivelySelectedElements.map((element) {
        return visibleDurationOf(element);
      }).reduce((a, b) => a+b);

      end = maxDuration(Duration(), (firstElement.startOffset - windowStart)) +
          (visibleSelectedDuration * max(0, selectionStretch['right']));

      start = visibleDuration - maxDuration(Duration(), windowEnd - lastElement.endOffset) -
          (visibleSelectedDuration * max(0, selectionStretch['left']));

      start = maxDuration(start, Duration());
      end = minDuration(end, visibleDuration);
    }


    var startWidth = (start.inMilliseconds / milisecondsPerPixel);
    var endWidth = (visibleDuration - end).inMilliseconds / milisecondsPerPixel;

		var visiblySelectedRatio = (visibleSelectedDuration.inMilliseconds / visibleDuration.inMilliseconds);
    var selectedElementsVisibleInWindow = lastElement.endOffset + dragDelta > windowStart && firstElement.startOffset + dragDelta < windowEnd;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Visibility(
          visible: firstElement.startOffset + dragDelta > windowStart && selectedElementsVisibleInWindow,
          child: Flexible(
            flex: start.inMilliseconds,
            child: Container(
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanEnd: (details) {
                    widget.onStretchUpdate('left', stretchedValue);
                    setState(() { selectionStretch['left'] = 1.0; });
                  },
                  onPanStart: (details) {
                    selectionStretch['left'] = 1;
                  },
                  onPanUpdate: (details) {
                    updateStretch(
                      side: 'left',
                      dx: -1 * details.delta.dx / containerWidth,
                      visiblySelectedRatio: visiblySelectedRatio,
                      maxStretch: end.inMilliseconds / visibleSelectedDuration.inMilliseconds,
                    );
                  },
                  child: Container(
                    width: start <= Duration() ? 0 : 30,
                    child: Transform.translate(
                      offset: Offset(2 - max(30 - startWidth, 0.0), 0),
                      child: Icon(Icons.arrow_left, size: 40),
                    )
                  )
                ),
              )
            )
          ),
        ),
        Flexible(
          flex: max(1, (end - start).inMilliseconds),
          child: Opacity(
            opacity: isActingOnSelected ? 1 : 0,
            child: Container(
              height: isActingOnSelected ? null : 0,
							decoration: BoxDecoration(
								boxShadow: [
									BoxShadow(
										color: Colors.black.withOpacity(0.5),
										spreadRadius: 5,
										blurRadius: 7,
										offset: Offset(0, 3), // changes position of shadow
									),
								],
							),
              child: Row(
                children: selectedElements.map((element) {
                  return Flexible(
                    flex: element.duration.inMilliseconds,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: widget.buildElement(element),
                    )
                  );
                }).toList(),
              )
            )
          )
        ),
        Visibility(
          visible: lastElement.endOffset + dragDelta < windowEnd && selectedElementsVisibleInWindow,
          child: Flexible(
            flex: (visibleDuration - end).inMilliseconds,
            child: Visibility(
              visible: endWidth > 0,
              child: Container(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanEnd: (details) {
                      widget.onStretchUpdate('right', stretchedValue);
                      setState(() { selectionStretch['right'] = 1.0; });
                    },
                    onPanStart: (details) {
                      selectionStretch['right'] = 1;
                    },
                    onPanUpdate: (details) {
                      updateStretch(
                        side: 'right',
                        dx: details.delta.dx / containerWidth,
                        visiblySelectedRatio: visiblySelectedRatio,
                        maxStretch: (visibleDuration - start).inMilliseconds / visibleSelectedDuration.inMilliseconds,
                      );
                    },
                    child: Container(
                      width: 30,
                      child: Transform.translate(
                        offset: Offset(-12, 0),
                        child: Icon(Icons.arrow_right, size: 40),
                      )
                    )
                  )
                )
              )
            )
          )
        ),
      ]
    );
  }

  void updateDragDelta() {
    var prevIndex = selectedElementIndexes.first - 1;
    var nextIndex = selectedElementIndexes.last + 1;

    if (nextIndex != controller.elements.length && selectedElements.last.endOffset + dragDelta > controller.elements.elementAt(nextIndex).midPoint) {
      var nextElement = controller.elements.elementAt(nextIndex);
      nextElement.startOffset -= selectedDuration;
      dragDelta -= nextElement.duration;
      selectedElements.forEach((element) => element.startOffset += nextElement.duration);
      controller.elements.insert(selectedElementIndexes.first, controller.elements.removeAt(nextIndex));
    } 
    if (prevIndex != -1 && selectedElements.first.startOffset + dragDelta < controller.elements.elementAt(prevIndex).midPoint) {
      var prevElement = controller.elements.elementAt(prevIndex);
      prevElement.startOffset += selectedDuration;
      dragDelta += prevElement.duration;
      selectedElements.forEach((element) => element.startOffset -= prevElement.duration);
      controller.elements.insert(selectedElementIndexes.last, controller.elements.removeAt(prevIndex));
    }
  }

  Map<Type, GestureRecognizerFactory> get timelineGestures => {
    ForcePressGestureRecognizer: GestureRecognizerFactoryWithHandlers<ForcePressGestureRecognizer>(() => new ForcePressGestureRecognizer(),
      (ForcePressGestureRecognizer instance) {
        instance..onStart = (details) {
          print("FORCE START: ${details}");
        };
        instance..onUpdate = (details) {
          print("FORCE UPDATE: ${details}");
        };
      }
    ),
    DelayedMultiDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<DelayedMultiDragGestureRecognizer>(() => new DelayedMultiDragGestureRecognizer(),
      (DelayedMultiDragGestureRecognizer instance) {
        instance..onStart = (Offset offset) {
          var element = elementAtTime(windowStart + visibleDuration * (offset.dx / containerWidth));
          toggleSelected(element, only: 'select');
          if (!selectedElementsAreConsecutive) controller.selectedElements = [element];
          setState(() => isReordering = true);
          return LongPressDraggable(
            onUpdate: (details) {
              setState(() {
                dragDelta += Duration(milliseconds: (details.delta.dx * milisecondsPerPixel).toInt());
                updateDragDelta();
              });
            },
            onEnd: (details) {
              dragDelta = Duration();
              setState(() => isReordering = false);
              widget.onReorder();
              eachWithIndex(controller.elements, (index, element) => element.object.position = index + 1);
              selectedElements.forEach((element) => element.object.save());
            }
          );
        };
      },
    ),
    TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(() => TapGestureRecognizer(),
      (TapGestureRecognizer instance) {
        instance
          ..onTapUp = (details) {
            var element = elementAtTime(windowStart + visibleDuration * (details.localPosition.dx / containerWidth));
            toggleSelected(element);
            setState(() {
              dragDelta = Duration();
              isReordering = false;
            });
        };
      },
    ),
  };

}
class TimelineTrackController {
  TimelineTrackController({ this.elements });

  List<TimelineElement> elements;
  List<TimelineElement> selectedElements = [];

  List<int> get selectedElementIndexes {
    return selectedElements.map((element) => elements.indexOf(element)).toList()..sort();
  }

  bool get selectedElementsAreConsecutive {
    int index;
    int lastIndex;
    bool isConsecutive;
    return selectedElementIndexes.every((index) {
      isConsecutive = lastIndex == null || (index - lastIndex).abs() == 1;
      lastIndex = index;
      return isConsecutive;
    });
  }

  List<TimelineElement> get consecutivelySelectedElements {
    if (selectedElementsAreConsecutive) return selectedElements;
    else return [];
  }

  Duration get selectedDuration => consecutivelySelectedElements.map((element) {
    return element.duration;
  }).reduce((a, b) => a+b);

  List<dynamic> get selectedObjects {
    return selectedElements.map((element) => element.object).toList();
  }

  TimelineElement elementAtTime(time) {
    return elements.firstWhere((element) {
       return element.startOffset <= time &&
           element.endOffset > time;
    });
  }
}

class LongPressDraggable extends Drag {
  final GestureDragUpdateCallback onUpdate;
  final GestureDragEndCallback onEnd;

  LongPressDraggable({this.onUpdate, this.onEnd});

  @override
  void update(DragUpdateDetails details) {
    super.update(details);
    onUpdate(details);
  }

  @override
  void end(DragEndDetails details) {
    super.end(details);
    onEnd(details);
  }
}
