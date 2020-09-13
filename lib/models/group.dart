import 'package:app/models/prop.dart';

class Group {
  List<Prop> props;
  String name;
  num id;

  Group({
    this.id,
    this.name,
    this.props,
  });

  // static List<Prop> get currentProps {
  //   return currentGroups.map((group) => group.props).expand((g) => g).toList();
  // }

  static Group currentGroupAt(index) {
    if ((currentGroups ?? []).length > 0 && index != null)
      return currentGroups[index % currentGroups.length];
  }

  static List<Group> get currentGroups {
    return [
      Group(
          id: 1,
          name: "Neil's Clubs",
          props: List.generate(7, (index) => Prop(id: index, index: index)),
      ),
      Group(
          id: 2,
          name: "Ben's Clubs",
          props: List.generate(5, (index) => Prop(id: 200 + index, index: index)),
      ),
      // Group(
      //     id: 3,
      //     name: "Seans's Props",
      //     props: List.generate(3, (index) => Prop(id: 300 + index, index: index)),
      // ),
      // Group(
      //     id: 3,
      //     name: "G's Props",
      //     props: List.generate(4, (index) => Prop(id: 300 + index, index: index)),
      // ),
    ];
  }

}
