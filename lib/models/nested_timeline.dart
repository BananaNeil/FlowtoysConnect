import 'package:app/models/timeline_element.dart';

class NestedTimeline {
  List<List<TimelineElement>> elements;

  NestedTimeline({
    this.elements
  });

  void addElements(newElements) {
    // There is more to do here!!!!!!!!!!!!!!!!!!!!!!!1
    // There is more to do here!!!!!!!!!!!!!!!!!!!!!!!1
    elements.addAll(newElements);
  }
}
