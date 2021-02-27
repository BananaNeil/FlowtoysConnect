// import 'package:app/helpers/duration_helper.dart';
// import 'package:app/components/mode_widget.dart';
import 'package:app/components/reordable_list_simple.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:app/components/mode_list_item.dart';
import 'package:app/components/mode_widget.dart';
import 'package:app/models/mode_list.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/models/group.dart';
import 'package:app/models/mode.dart';
import 'package:rxdart/rxdart.dart';
import 'package:app/preloader.dart';
import 'package:app/client.dart';
// import 'package:app/models/prop.dart';
import 'dart:async';
import 'dart:math';

class ModeListWidget extends StatefulWidget {
  ModeListWidget({
    Key key,
    this.onRemove,
    this.isEditing,
    this.modeLists,
    this.filterBar,
    this.onRefresh,
    this.showTitles,
    this.isSelecting,
    this.filterStream,
    this.setCurrentLists,
    this.selectedModeIds,
    this.preventReordering,
    this.toggleSelectedMode,
    this.canChangeCurrentList,
  }) : super(key: key);


  bool isEditing;
  bool showTitles;
  bool isSelecting;
  Widget filterBar;
  Function onRemove;
  Function onRefresh;
  Stream filterStream;
  bool preventReordering;
  Function setCurrentLists;
  List<ModeList> modeLists;
  bool canChangeCurrentList;
  Function toggleSelectedMode;
  List<String> selectedModeIds;

  @override
  _ModeListWidget createState() => _ModeListWidget();

}


class _ModeListWidget extends State<ModeListWidget> with TickerProviderStateMixin {
  _ModeListWidget();


  @override
  initState() {
    super.initState();
    activeFilters = {};
    if (widget.canChangeCurrentList) _fetchAllLists();
    filtersSubscription = widget.filterStream.listen((filters) {
      setState(() => activeFilters = filters);
    });
  }

  @override
  dispose() {
    filtersSubscription.cancel();
    super.dispose(); 
  }

  List<ModeList> allLists;
  bool isFetchingAllLists = false;

  StreamSubscription filtersSubscription;

  List<ModeList> get modeLists => widget.modeLists;
  ModeList get firstList => modeLists.isEmpty ? null : modeLists[0];

  List<String> expandedModeIds = [];
  bool isExpanded(mode) => expandedModeIds.contains(mode.id);

  bool isAdjustingInlineParam = false;

  double containerWidth;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          containerWidth = box.maxWidth;
          return  RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: Container(
                height: double.infinity,
              decoration: BoxDecoration(color: Color(0xFF2F2F2F)),
              child: ReorderableListSimple(
                physics: AlwaysScrollableScrollPhysics(),
                childrenAlreadyHaveListener: true,
                allowReordering: widget.isEditing,
                children: [
                  widget.filterBar ?? Container(),
                  _SelectCurrentList,
                  ..._ListItems(modeLists),
                  _AddMoreModes,
                ],
                onReorder: (int start, int current) {
                  if (widget.preventReordering) return;
                  var list = firstList;
                  var mode = list.modes[start];
                  list.modes.remove(mode);
                  list.modes.insert(current, mode);
                  list.modes.asMap().forEach((index, other) => other.position = index + 1);
                  Client.updateMode(mode);
                }
              ),
            )
          );
        }
      )
    );
  }

  Widget get _SelectCurrentList {
    if (!widget.canChangeCurrentList) return Container();

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        isFetchingAllLists ?
          Container(
            height: 40,
            margin: EdgeInsets.only(bottom: 5),
            child: SpinKitCircle(size: 25, color: Colors.white)
          ) : Container(
            margin: EdgeInsets.all(5),
            child: Container(height: 35,
              child: DropdownButton(
                isExpanded: true,
                value: modeLists.firstWhere((list) => list.id != null)?.id,
                items: allLists.map((ModeList list) {
                  return DropdownMenuItem<String>(
                    value: list.id,
                    child: Container(
                      margin: EdgeInsets.only(bottom: 5),
                      child: Wrap(
                        clipBehavior: Clip.antiAlias,
                        children: [
                          Container(
                            margin: EdgeInsets.only(right: 10, top: 3),
                            child: Text(list.name),
                          ),
                          ...list.modes.sublist(0, min(list.modes.length, 9)).map((mode) {
                            return Container(
                              margin: EdgeInsets.only(right: 4, bottom: 3),
                              child: ModeImage(mode: mode, size: 12)
                            );
                          }).toList(),
                        ]
                      )
                    )
                  );
                }).toList(),
                onChanged: (value) {
                  var lists = [allLists.firstWhere((list) => list.id == value)];
                  widget.setCurrentLists(lists);
                },
              )
            )
          ),
        Container(
          height: 15,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF2f2f2f),
                  Colors.black,
                ],
            )
          )
        )
      ]
    );
  }

  Map<String, dynamic> activeFilters = {};
  List<Widget> _ListItems(List<ModeList> lists) {
    return lists.map((list) {
      List<Mode> filteredModes = list.modes;
      filteredModes = filteredModes.where((mode) {
        return (activeFilters['activeFilters'] ?? []).every((filter) => mode.booleanAttributes[filter]) &&
            (activeFilters['keywordFilter'] ?? []).every((word) {
              return mode.description.toLowerCase().contains(word) || mode.name.toLowerCase().contains(word);
            });
      }).toList();
      List<Widget> items = filteredModes.map<Widget>((mode) {
        return ModeListItem(
          mode: mode,
          removeMode: widget.onRemove,
          fetchModes: widget.onRefresh,
          isExpanded: isExpanded(mode),
          containerWidth: containerWidth,
          isAdjustingInlineParam: (boolean) {
            isAdjustingInlineParam = boolean;
          },
          toggleExpand: () {
            if (isExpanded(mode))
              expandedModeIds.remove(mode.id);
            else expandedModeIds.add(mode.id);
          },
          onTap: () {
            if (widget.isSelecting)
              widget.toggleSelectedMode(mode);
            else {
              if (isAdjustingInlineParam) return;
              Group.currentQuickGroup.currentMode = mode;
              setState(() {});
            }
          },
          isEditing: widget.isEditing,
          isSelecting: widget.isSelecting,
          selectedModeIndex: widget.selectedModeIds.indexOf(mode.id) + 1,
        );
      }).toList();
      if (widget.showTitles)
        items.insert(0, _ListTitle(list));
      return items;
    }).expand((i) => i).toList();
  }

  Widget _ListTitle(list) {
    return Container(
      color: Theme.of(context).canvasColor,
      padding: EdgeInsets.all(8.0),
      child: Text(
        list.name,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  bool addingMore = false;

  Widget get _AddMoreModes {
    if (firstList?.creationType != 'user') return Container();
    if (addingMore) return Container(
      child: SpinKitCircle(color: Colors.blue),
      margin: EdgeInsets.all(10),
    );
    return Center(
      child: GestureDetector(
        onTap: () {
          Navigator.pushNamed(context, '/modes', arguments: {
            'isSelecting': true,
            'canChangeCurrentList': true,
            'selectAction': "Add to \"${firstList.name}\"",
          }).then((selectedModes) {
            if (selectedModes != null) {
              setState(() => addingMore = true);
              List<Mode> modes = selectedModes;
              Client.updateList(firstList.id, {'append': modes.map((mode) => mode.id).toList()}).then((response) {
                if (response['success'])
                  setState(() {
                    addingMore = false;
                    modeLists[0] = response['modeList'];
                  });
              });
            }
          });
        },
        child: Container(
          margin: EdgeInsets.only(top: 10, bottom: 15),
          child: Text("+ Add more modes"),
        )
      )
    );
  }

  Future<void> _fetchAllLists({initialRequest}) {
    // Pulling from cache... maybe you'll need to request too?
    isFetchingAllLists = true;
    return Preloader.getModeLists().then((lists) {
      isFetchingAllLists = false;
      setState(() {
        allLists = lists;
      });
    });
    // setState(() { isFetchingAllLists = true; });
    // return Client.getModeLists().then((response) {
    //   isFetchingAllLists = false;
    //   setState(() {
    //     if (response['success']) {
    //       allLists = response['modeLists'] ?? [];
    //     } else if (initialRequest != true || modeLists.isEmpty)
    //       errorMessage = response['message'];
    //   });
    // });
  }
}
