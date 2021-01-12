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
    this.snapping,
    this.onReorder,
    this.controller,
    this.onDoubleTap,
    this.buildElement,
    this.onScrollUpdate,
    this.onStretchUpdate,
    this.inflectionPoints,
    this.slideWhenStretching,
  }) : super(key: key);

  final TimelineTrackController controller;
  List<Duration> inflectionPoints;
  bool slideWhenStretching;
  Function onStretchUpdate;
  Function onScrollUpdate;
  Function buildElement;
  Function onDoubleTap;
  Function onReorder;
  bool snapping;

  Duration get futureVisibleDuration => controller.futureVisibleDuration;
  Duration get timelineDuration => controller.timelineDuration;
  Duration get visibleDuration => controller.visibleDuration;
  Duration get windowStart => controller.windowStart;

  @override
  _TimelineTrackState createState() => _TimelineTrackState();
}

class _TimelineTrackState extends State<TimelineTrackWidget> with TickerProviderStateMixin {
  _TimelineTrackState();

  TimelineTrackController get controller => widget.controller;
  List<TimelineElement> get selectedElements => controller.selectedElements;

  Duration get windowStart => widget.windowStart;

  bool get snapping => widget.snapping;
  bool get slideWhenStretching => widget.slideWhenStretching;
  bool get isActingOnSelected => isStretching || isReordering;
  bool get isStretching => selectionStretch['right'] != 1 || selectionStretch['left'] != 1;

  String get stretchedSide => selectionStretch.keys.firstWhere((key) => selectionStretch[key] != 1 );
  // double get stretchedValue => selectionStretch[stretchedSide];

  Duration dragDelta = Duration();
  bool isReordering = false;
  Timer dragScrollTimer;

  Map<String, double> selectionStretch = {
    'left': 1.0,
    'right': 1.0,
  };

  double get microsecondsPerPixel => visibleMicroseconds / containerWidth;
  Duration get futureVisibleDuration => widget.futureVisibleDuration;
  int get visibleMicroseconds => visibleDuration.inMicroseconds;
  Duration get visibleDuration => widget.visibleDuration;
  Duration get windowEnd => windowStart + visibleDuration;

  double containerWidth = 0;
  double containerHeight = 0;


  visibleDurationOf(element) {
    var elementVisibleDuration;
    if (element.startOffset < windowStart)
      elementVisibleDuration = minDuration(visibleDuration, element.endOffset - windowStart);
    else if (element.endOffset > windowEnd)
      elementVisibleDuration = minDuration(visibleDuration, windowEnd - element.startOffset);
    else elementVisibleDuration = element.duration;

    return minDuration(elementVisibleDuration, element.duration);
  }

  Widget buildElement(element) {
    return widget.buildElement(element);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        containerWidth = box.maxWidth;
        containerHeight = box.maxHeight;
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
      controller.toggleSelected(element, only: only);
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
    return controller.elementAtTime(time);
  }

  void triggerDragScroll(movementAmount) {
    dragScrollTimer?.cancel();
    dragScrollTimer = Timer(Duration(milliseconds: 50), () => setState(() {
      dragDelta += movementAmount;
      updateDragDelta();
    }));
  }

  TimelineElement get stretchedSibling {
    var index;
    if (!isStretching || selectedElements.isEmpty) return null;
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
              elementVisibleDuration = visibleSelectedDuration;
            else elementVisibleDuration = Duration();

          return Flexible(
            flex: ((elementVisibleDuration.inMicroseconds / (futureVisibleDuration.inMicroseconds)).clamp(0.0, 1.0) * 20000.0).ceil(),
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
                    isStretching && !slideWhenStretching ? buildElement(stretchedSibling) : Container(
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
                     buildElement(element),
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
        }).toList()
      )
    );
  }

  List<double> _stretchInflectionPoints;
  List<double> get stretchInflectionPoints {
    if (_stretchInflectionPoints != null)
      return _stretchInflectionPoints;

    List<Duration> inflectionPoints = [];
    var startOffset = selectedElements.first.startOffset;
    var endOffset = selectedElements.first.endOffset;
    if (stretchedSide == 'right') {
      return widget.inflectionPoints.map((point) => durationRatio((point - startOffset), selectedDuration)).toList();
    } else if (stretchedSide == 'left') {
      return widget.inflectionPoints.map((point) => durationRatio((endOffset - point), selectedDuration)).toList();
    }
  }

  void updateStretch({side, dx, maxStretch, visiblySelectedRatio}) {
    setState(() {
      selectionStretch[side] += 3 * dx / visiblySelectedRatio;
      selectionStretch[side] = selectionStretch[side].clamp(0.0, maxStretch);
    });
  }

  double selectionStretchValue(side) {
    if (!isStretching) return 1.0;
    double value;
    if (snapping)
      value = stretchInflectionPoints.firstWhere((point) {
        return (1 - (point / selectionStretch[side])).abs() < 0.05;
      }, orElse: () => null);
    return max(0.0, value ?? selectionStretch[side]);
  }

  List<int> get selectedElementIndexes => controller.selectedElementIndexes;

  bool get selectedElementsAreConsecutive => controller.selectedElementsAreConsecutive;

  List<TimelineElement> get consecutivelySelectedElements => controller.consecutivelySelectedElements;

  Duration get selectedDuration => controller.selectedDuration;
  Duration get visibleSelectedDuration => controller.consecutivelySelectedElements.map((element) {
    return visibleDurationOf(element);
  }).reduce((a, b) => a+b);

  Widget _SelectedElementHandles() {
    if (consecutivelySelectedElements.isEmpty)
      return Container();

    var firstElement = consecutivelySelectedElements.first;
    var lastElement = consecutivelySelectedElements.last;
    // var visibleSelectedDuration;
    var end;
    var start;

    if (isReordering) {
      start = maxDuration(Duration(), firstElement.startOffset - windowStart + dragDelta);
      end = start + selectedDuration;// + dragDelta;
      end = minDuration(end, visibleDuration);
    } else {
      end = maxDuration(Duration(), (firstElement.startOffset - windowStart)) +
          (visibleSelectedDuration * selectionStretchValue('right'));

      start = visibleDuration - maxDuration(Duration(), windowEnd - lastElement.endOffset) -
          (visibleSelectedDuration * selectionStretchValue('left'));

      start = maxDuration(start, Duration());
      end = minDuration(end, visibleDuration);
    }


    var startWidth = (start.inMicroseconds / microsecondsPerPixel);
    var endWidth = (visibleDuration - end).inMicroseconds / microsecondsPerPixel;

		var visiblySelectedRatio = (visibleSelectedDuration.inMicroseconds / visibleDuration.inMicroseconds);
    var selectedElementsVisibleInWindow = lastElement.endOffset + dragDelta > windowStart && firstElement.startOffset + dragDelta < windowEnd;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Visibility(
          visible: firstElement.startOffset + dragDelta > windowStart && selectedElementsVisibleInWindow,
          child: Flexible(
            flex: start.inMicroseconds,
            child: Container(
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanEnd: (details) {
                    widget.onStretchUpdate('left', selectionStretchValue('left'));
                    setState(() { selectionStretch['left'] = 1.0; });
                  },
                  onPanStart: (details) {
                    selectionStretch['left'] = 1;
                    _stretchInflectionPoints = null;
                  },
                  onPanUpdate: (details) {
                    updateStretch(
                      side: 'left',
                      dx: -1 * details.delta.dx / containerWidth,
                      visiblySelectedRatio: visiblySelectedRatio,
                      maxStretch: end.inMicroseconds / visibleSelectedDuration.inMicroseconds,
                    );
                  },
                  child: Container(
                    width: start <= Duration() ? 0 : 30,
                    child: Transform.translate(
                      offset: Offset(2 - max(30 - startWidth, 0.0), min(0, (containerHeight - 40) / 2)),
                      child: Icon(Icons.arrow_left, size: 40),
                    )
                  )
                ),
              )
            )
          ),
        ),
        Flexible(
          flex: max(1, (end - start).inMicroseconds),
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
                  var el = element;
                  // if (!stretchSubshows) {
                  //   el = element.dup();
                  //   el.startOffset = windowStart + start;
                  //   el.duration = windowStart + end - el.startOffset;
                  // }
                  return Flexible(
                    flex: element.duration.inMicroseconds,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: buildElement(el),
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
            flex: (visibleDuration - end).inMicroseconds,
            child: Container(
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanEnd: (details) {
                    widget.onStretchUpdate('right', selectionStretchValue('right'));
                    setState(() { selectionStretch['right'] = 1.0; });
                  },
                  onPanStart: (details) {
                    selectionStretch['right'] = 1;
                    _stretchInflectionPoints = null;
                  },
                  onPanUpdate: (details) {
                    updateStretch(
                      side: 'right',
                      dx: details.delta.dx / containerWidth,
                      visiblySelectedRatio: visiblySelectedRatio,
                      maxStretch: (visibleDuration - start).inMicroseconds / visibleSelectedDuration.inMicroseconds,
                    );
                  },
                  child: Container(
                    width: end >= visibleDuration ? 0 : 30,
                    child: Transform.translate(
                      offset: Offset(-12, min(0, (containerHeight - 40) / 2)),
                      child: Icon(slideWhenStretching ? Icons.arrow_right : Icons.arrow_right, size: 40),
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
      controller._elements.insert(selectedElementIndexes.first, controller._elements.removeAt(nextIndex));
    } 
    if (prevIndex != -1 && selectedElements.first.startOffset + dragDelta < controller.elements.elementAt(prevIndex).midPoint) {
      var prevElement = controller.elements.elementAt(prevIndex);
      prevElement.startOffset += selectedDuration;
      dragDelta += prevElement.duration;
      selectedElements.forEach((element) => element.startOffset -= prevElement.duration);
      controller._elements.insert(selectedElementIndexes.last, controller._elements.removeAt(prevIndex));
    }

    scrollWithDragDelta();
  }

  String initialSelectionOverflowSide = 'right';
  Duration initialVisibleSelectedDuration;

  void scrollWithDragDelta() {
    var thresholdEnd;
    var thresholdStart;
    var triggerPoint = visibleDuration * 0.05;
    var firstElement = consecutivelySelectedElements.first;
    var movementAmount = minDuration(Duration(seconds: 5), controller.timelineDuration * 0.01);

    thresholdStart = maxDuration(Duration(), firstElement.startOffset - windowStart + dragDelta);
    thresholdEnd = thresholdStart + selectedDuration;

    if (initialSelectionOverflowSide == 'right')
      thresholdEnd = thresholdStart + initialVisibleSelectedDuration * 0.65;
    else if (initialSelectionOverflowSide == 'left')
      thresholdStart = initialVisibleSelectedDuration * 0.30 + dragDelta;

    if (thresholdStart <= triggerPoint) {
      movementAmount *= -1;
      // controller.windowStart += minDuration(movementAmount, thresholdStart);
      controller.windowStart += movementAmount;
      controller.windowStart = maxDuration(Duration(), controller.windowStart);
      widget.onScrollUpdate(windowStart);
      if (windowStart.inMicroseconds > 0)
        triggerDragScroll(movementAmount);

    } else if (thresholdEnd > visibleDuration - triggerPoint) {
      controller.windowStart += movementAmount;
      controller.windowStart = minDuration(controller.timelineDuration - visibleDuration, controller.windowStart);
      widget.onScrollUpdate(controller.windowStart);
      if (windowStart < (controller.timelineDuration - visibleDuration))
        triggerDragScroll(movementAmount);
    }
  }

  Map<Type, GestureRecognizerFactory> get timelineGestures => {
    DoubleTapGestureRecognizer: GestureRecognizerFactoryWithHandlers<DoubleTapGestureRecognizer>(() => new DoubleTapGestureRecognizer(),
      (DoubleTapGestureRecognizer instance) {
        instance
          ..onDoubleTapDown = (details) {
            var element = elementAtTime(windowStart + visibleDuration * (details.localPosition.dx / containerWidth));
            toggleSelected(element, only: 'select');
            widget.onDoubleTap(element);
          };
      }
    ),
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
          if (!selectedElementsAreConsecutive) {
            controller.deselectAll();
            toggleSelected(element, only: 'select');
          }
          setState(() => isReordering = true);

          var firstElement = consecutivelySelectedElements.first;
          initialVisibleSelectedDuration = visibleSelectedDuration;

          if (firstElement.startOffset + selectedDuration >= windowEnd)
            initialSelectionOverflowSide = 'right';
          else if (firstElement.startOffset + dragDelta < windowStart)
            initialSelectionOverflowSide = 'left';
          else initialSelectionOverflowSide = null;

          return LongPressDraggable(
            onUpdate: (details) {
              setState(() {
                dragDelta += Duration(microseconds: (details.delta.dx * microsecondsPerPixel).toInt());
                updateDragDelta();
              });
            },
            onEnd: (details) {
              dragDelta = Duration();
              setState(() => isReordering = false);
              widget.onReorder();
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
  TimelineTrackController({
    elements,
    this.timelineIndex,
    this.selectMultiple,
    onSelectionUpdate,
  }) {
    this._elements = elements;
    this.onSelectionUpdate = onSelectionUpdate ?? (_) => null;
  }

  void set elements(elements) => _elements = elements;

  Duration futureVisibleDuration = Duration();
  Duration timelineDuration = Duration();
  Duration visibleDuration = Duration();
  Duration windowStart = Duration();

  bool get isEmpty {
    return elements.isEmpty || elements.every((el) => el.object == null);
  }

  List<TimelineElement> _elements;
  List<TimelineElement> selectedElements = [];
  Function onSelectionUpdate;
  bool selectMultiple;
  int timelineIndex;

  void setWindow({windowStart, visibleDuration, futureVisibleDuration, timelineDuration}) {
    this.futureVisibleDuration = futureVisibleDuration;
    this.timelineDuration = timelineDuration;
    this.visibleDuration = visibleDuration;
    this.windowStart = windowStart;
  }

  List<int> get selectedElementIndexes {
    return selectedElements.map((element) => elements.indexOf(element)).toList()..sort();
  }

  bool get allElementsSelected => selectedElements.length == elements.length;

  void deselectAll({before, after}) {
    if (after != null)
      selectedElements = selectedElements.where((element) {
        return element.startOffset < after;
      }).toList();
    else if (before != null)
      selectedElements = selectedElements.where((element) {
        return element.endOffset > before;
      }).toList();
    else selectedElements = [];
    onSelectionUpdate(this);
  }

  void selectAll({before, after}) {
    if (after != null)
      selectedElements = elements.where((element) {
        return selectedElements.contains(element) ||
          element.endOffset > after;
      }).toList();
    else if (before != null)
      selectedElements = elements.where((element) {
        return selectedElements.contains(element) ||
            element.startOffset < before;
      }).toList();
    else
      selectedElements = List.from(elements);
    onSelectionUpdate(this);
  }

  void toggleSelectMultiple() {
    selectMultiple = !selectMultiple;
  }

  void toggleSelected(element, {only}) {
    var isSelected = selectedElements.contains(element);
    if (isSelected && only == 'select') return;
    else if (isSelected)
      selectedElements.remove(element);
    else if (selectMultiple == true)
      selectedElements.add(element);
    else
      selectedElements = [element];

    selectedElements.sort((a, b) => a.startOffset.compareTo(b.startOffset));
    onSelectionUpdate(this);
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

  TimelineElement blankElement = TimelineElement();

  Duration get visibleEnd => minDuration(windowStart + visibleDuration, timelineDuration);

  List<TimelineElement> get elements {
    return List<TimelineElement>.from(_elements);
  }

  TimelineElement elementAtTime(time) {
    return elements.firstWhere((element) {
       return element.startOffset <= time &&
           element.endOffset > time;
    }, orElse: () => null);
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
