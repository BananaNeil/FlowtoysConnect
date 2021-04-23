import 'package:app/app_controller.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:app/models/group.dart';

class EditGroups extends StatefulWidget {
  EditGroups({
    Key key,
  }) : super(key: key);


  @override
  _EditGroupsWidgetState createState() => _EditGroupsWidgetState();
}

class _EditGroupsWidgetState extends State<EditGroups> {
  _EditGroupsWidgetState();

  List<String> _expandedGroupIds = [];

  @override initState() {
    super.initState();
    _expandedGroupIds = Group.currentGroups.map((group) => group.groupId).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _quickGroups(),
          ...Group.connectedGroups.map((group) => _groupWidget(group)).toList(),
        ]
      )
    );
  }

  Widget _quickGroups() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: Group.quickGroups.map((group) {
        Set<String> groupIds = group.props.map((prop) => prop.groupId).toSet();
        return GestureDetector(
          onTap: () {
            setState(() => Group.currentQuickGroup = group);
          },
          child: Container(
            decoration: BoxDecoration(
              border: Group.currentQuickGroup.groupId != group.groupId ? Border(bottom: BorderSide(color: Colors.transparent, width: 4)) : 
                Border(bottom: BorderSide(color: Colors.white, width: 4))
            ),
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 15),
            child: Text("${groupIds.length}",
              style: TextStyle(
                color: group.props.length == 0 ? Color(0xFF555555) : Colors.white,
                fontSize: 26,
              )
            ),
          ),
        );
      }).toList()
    );
  }

  Widget _groupWidget(group) {
    var isExpanded = _expandedGroupIds.contains(group.groupId);
    return Card(
      elevation: 8.0,
      margin: EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
        child: Column(
          children: [
            _groupTitle(group, isExpanded: isExpanded),
            // ...(isExpanded ? _propsForGroup(group) : []),
          ]
        )
      )
    );
  }

  Widget _groupTitle(group, {isExpanded}) {
    Set unSelectedPropIds = group.propIds.toSet().difference(Group.currentQuickGroup.propIds.toSet());
    bool allPropsSelected = unSelectedPropIds.length == 0;
    return GestureDetector(
      onTap: () {
        setState(() {
          // if (isExpanded)
          //   _expandedGroupIds.remove(group.groupId);
          // else _expandedGroupIds.add(group.groupId);
          setState(() {
            group.props.forEach((prop) {
              if (allPropsSelected)
                Group.currentQuickGroup.props.removeWhere((p) => p.id == prop.id);
              else if (!Group.currentQuickGroup.propIds.contains(prop.id))
                Group.currentQuickGroup.props.add(prop);
            });
          });
        });
      },
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
            },
            child: Container(
              width: 30,
              height: 30,
              child: allPropsSelected ? Icon(Icons.check) : Container(),
            ),
          ),
          Text(group.name),
          // isExpanded ? Icon(Icons.expand_more) : Icon(Icons.chevron_right), 
        ]
      ),
    );
  }

  List<Widget> _propsForGroup(group) {
    return group.props.map<Widget>((prop) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          var propIds = Group.currentQuickGroup.propIds;
          var props = Group.currentQuickGroup.props;
          setState(() {
            if (propIds.contains(prop.id))
              props.removeWhere((quickProp) => quickProp.id == prop.id);
            else props.add(prop);
          });
        },
        child: Row(
          children: [
            Container( width: 25),
            Container(
              width: 25,
              height: 30,
              // decoration: BoxDecoration(color: Colors.blue),
              child: Group.currentQuickGroup.propIds.contains(prop.id) ?
                     Icon(Icons.check) : Container(),
            ),
            Text("Prop #"),
          ]
        )
      );
    }).toList();
  }

}


