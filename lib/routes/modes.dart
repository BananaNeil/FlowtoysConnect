import 'package:flutter_reorderable_list/flutter_reorderable_list.dart';
import 'package:flutter_hsvcolor_picker/flutter_hsvcolor_picker.dart';
import 'package:app/components/reordable_list_simple.dart';
import 'package:app/helpers/color_filter_generator.dart';
import 'package:app/components/inline_mode_params.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:app/components/edit_mode_widget.dart';
import 'package:app/components/action_button.dart';
import 'package:app/components/edit_groups.dart';
import 'package:app/components/mode_widget.dart';
import 'package:app/models/mode_list.dart';
import 'package:app/authentication.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/models/group.dart';
import 'package:app/models/mode.dart';
import 'package:app/models/prop.dart';
import 'package:app/preloader.dart';
import 'package:app/client.dart';
import 'dart:async';

class Modes extends StatelessWidget {
  Modes({this.id});

  final String id; 

  @override
  Widget build(BuildContext context) {
    return ModesPage(id: id);
  }
}

class ModesPage extends StatefulWidget {
  ModesPage({Key key, this.id, this.hideNavigation, this.canShowDefaultLists}) : super(key: key);
  bool canShowDefaultLists = true;
  bool hideNavigation = false;
  final String id;

  @override
  _ModesPageState createState() => _ModesPageState(id);
}

class _ModesPageState extends State<ModesPage> {
  _ModesPageState(this.id);
  bool get hideNavigation => widget.hideNavigation ?? false;

  final String id;

  bool returnList;
  bool isSelecting;
  String errorMessage;
  String selectAction;
  bool isTopLevelRoute;
  List<Mode> modes = [];
  bool isEditing = false;
  List<ModeList> allLists;
  List<ModeList> modeLists;
  Mode currentlyEditingMode;
  bool canChangeCurrentList;
  List<Mode> selectedModes = [];
  bool awaitingResponse = false;
  bool isFetchingAllLists = false;
  bool isAdjustingInlineParam = false;
  ModeList get firstList => modeLists.isEmpty ? null : modeLists[0];
  bool showExpandedActionButtons = false;

  List<Mode> expandedModes = [];
  bool isExpanded(mode) => expandedModes.contains(mode);

  bool get showDefaultLists => (widget.canShowDefaultLists ?? true) && id == null;


  List<String> get selectedModesIds => selectedModes.map((mode) => mode.id).toList();

  List<Mode> get allModes => modeLists.map((list) => list.modes).expand((m) => m).toList();

  Future<Map<dynamic, dynamic>> _makeRequest() {
    if (showDefaultLists)
      return Client.getModeLists(creationType: 'auto');
    else return Client.getModeList(id);
  }

  Future<void> requestFromCache() async {
    var query = showDefaultLists ? {'creation_type': 'auto'} : {'id': id};
    return Preloader.getModeLists(query).then((lists) {
      setState(() => modeLists = lists);
    });
  }

  Future<void> _fetchAllLists({initialRequest}) {
    setState(() { isFetchingAllLists = true; });
    return Client.getModeLists().then((response) {
      isFetchingAllLists = false;
      setState(() {
        if (response['success']) {
          allLists = response['modeLists'] ?? [];
        } else if (initialRequest != true || modeLists.isEmpty)
          errorMessage = response['message'];
      });
    });
  }

  Future<void> _fetchModes({initialRequest}) {
    if (!Authentication.isAuthenticated() && modeLists.length > 0) return Future.value(null);
    setState(() { awaitingResponse = true; });
    return Preloader.downloadData().then((_) {
      return _makeRequest().then((response) {
        setState(() {
          if (response['success']) {
            awaitingResponse = false;


            var list = response['modeList'];
            if (list != null) modeLists = [list];
            else modeLists = response['modeLists'] ?? [];
          } else if (initialRequest != true || modeLists.isEmpty)
            errorMessage = response['message'];
        });
      });
    });
  }

  @override initState() {
    isTopLevelRoute = !Navigator.canPop(context);
    requestFromCache().then((_) => _fetchModes(initialRequest: true));
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    modeLists ??= [AppController.getParams(context)['modeList']]..removeWhere((v) => v == null);
    canChangeCurrentList ??= AppController.getParams(context)['canChangeCurrentList'] ?? false;
    isSelecting ??= AppController.getParams(context)['isSelecting'] ?? false;
    selectAction ??= AppController.getParams(context)['selectAction'];
    returnList ??= AppController.getParams(context)['returnList'];
    var propCount = Group.currentQuickGroup.props.length;

    return Scaffold(
      floatingActionButton: _FloatingActionButton,
      backgroundColor: AppController.darkGrey,
      drawer: !hideNavigation && isTopLevelRoute ? AppController.drawer() : null,
      appBar: AppBar(
        title: Text(_getTitle()), backgroundColor: Color(0xff222222),
        leading: isTopLevelRoute ? null : IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, returnList == true ? firstList : null);
          },
        ),
        actions: hideNavigation ? [] : <Widget>[
          GestureDetector(
            onTap: () {
              showDialog(context: context,
                builder: (context) => Dialog(
                  child: _editGroupsWidget(),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                )
              ).then((_) { setState(() {}); });
            },
            child: Container(
              padding: EdgeInsets.all(15),
              child: Icon(
                  propCount <= 0 ? Icons.warning : {
                    1: Icons.filter_1,
                    2: Icons.filter_2,
                    3: Icons.filter_3,
                    4: Icons.filter_4,
                    5: Icons.filter_5,
                    6: Icons.filter_6,
                    7: Icons.filter_7,
                    8: Icons.filter_8,
									}[propCount] ?? Icons.filter_9_plus,
                  size: 24,
              ),
            ),
          )
        ],
      ),
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _ModeLists,
        ),
      ),
    );
  }

  List<Widget> get _ModeLists {
    if (AppController.screenWidth < 300 * modeLists.length)
      return [_ModeList(modeLists)];
    else return modeLists.map<Widget>((list) {
      return _ModeList([list]);
    }).toList();
  }

  Widget _ModeList(lists) {
    return Container(
      width: AppController.screenWidth > 600 && modeLists.length == 1 ? 600 : null,
      child: Expanded(
        child: RefreshIndicator(
          onRefresh: _fetchModes,
          child: Container(
            decoration: BoxDecoration(color: Color(0xFF2F2F2F)),
            child: ReorderableListSimple(
              physics: BouncingScrollPhysics(),
              childrenAlreadyHaveListener: true,
              allowReordering: isEditing,
              children: [
                _SelectCurrentList,
                ..._ListItems(lists),
                _AddMoreModes,
              ],
              onReorder: (int start, int current) {
                if (isShowingMultipleLists) return;
                var list = firstList;
                var mode = list.modes[start];
                list.modes.remove(mode);
                list.modes.insert(current, mode);
                list.modes.asMap().forEach((index, other) => other.position = index + 1);
                Client.updateMode(mode);
              }
            ),
          )
        ),
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
          Navigator.pushNamed(context, '/modes', arguments: {'isSelecting': true, 'selectAction': "Add to \"${firstList.name}\""}).then((selectedModes) {
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
            //   Navigator.pushNamed(context, '/shows/new', arguments: {'modes': modes});
          });
        },
        child: Container(
          margin: EdgeInsets.only(top: 10, bottom: 15),
          child: Text("+ Add more modes"),
        )
      )
    );
  }

  Widget get _SelectCurrentList {
    if (!canChangeCurrentList) return Container();
    if (allLists == null && !isFetchingAllLists) _fetchAllLists();

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
                value: firstList?.id,
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
                          ...list.modes.map((mode) {
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
                  modeLists = [allLists.firstWhere((list) => list.id == value)];
                      print("ON CHANGED");
                  setState(() {});
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

  List<Widget> _ListItems(List<ModeList> lists) {
    return lists.map((list) {
      var items = list.modes.map(_ModeItem).toList();
      if (isShowingMultipleLists)
        items.insert(0, _ListTitle(list));
      return items;
    }).expand((i) => i).toList();
  }

  Widget get _FloatingActionButton {
    if (isSelecting)
      return _SelectionButtons();
    else if (isEditing)
      return FloatingActionButton.extended(
        backgroundColor: AppController.darkGrey,
        label: Text("Done",
          style: TextStyle(
            color: Colors.white,
          )
        ),
        heroTag: "save_list",
        onPressed: () {
          setState(() { isEditing = false; showExpandedActionButtons = false; });
        },
      );
    else if (showExpandedActionButtons)
      return Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ActionButton(
            visible: !isShowingMultipleLists,
            text: "Edit Modes",
            onPressed: () {
              setState(() { isEditing = true; });
            },
          ),
          ActionButton(
            text: "Select Modes",
            onPressed: () {
              setState(() { isSelecting = true; });
            },
          ),
          ActionButton(
            // visible: !isShowingMultipleLists,
            child: Icon(
              Icons.expand_more,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() { showExpandedActionButtons = false; });
            },
          ),
        ]
      );
    else return ActionButton(
      // visible: !isShowingMultipleLists,
      child: Icon(
        Icons.more_horiz,
        color: Colors.white,
      ),
      onPressed: () {
        setState(() { showExpandedActionButtons = true; });
      },
    );
  }

  Widget _SelectionButtons() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        !(selectAction == 'Create Show' && selectedModes.length == 0) ? Container() : ActionButton(
          rightMargin: 25.0,
          text: 'Skip',
          onPressed: () {
            Navigator.pop(context, []);
          },
        ),
        ActionButton(
          visible: selectedModes.length < allModes.length,
          text: "Select All",
          rightMargin: 25.0,
          onPressed: () {
            setState(() => selectedModes = allModes);
          },
        ),
        ActionButton(
          visible: !isShowingMultipleLists && selectedModes.length > 0 && selectAction == null,
          text: "Remove (${selectedModes.length})",
          rightMargin: 25.0,
          onPressed: () {
            if (selectedModes.length > 0)
              AppController.openDialog("Are you sure?", "This will remove ${selectedModes.length} modes from this list along with any customizations made to them.",
                buttonText: 'Cancel',
                buttons: [{
                  'text': 'Delete',
                  'color': Colors.red,
                  'onPressed': () {
                    selectedModes.forEach((mode) => _removeMode(mode));
                    selectedModes = [];
                  },
                }]
              );
          },
        ),
        ActionButton(
          visible: !isShowingMultipleLists && selectedModes.length > 0 && selectAction == null,
          text: "Duplicate (${selectedModes.length})",
          rightMargin: 25.0,
          onPressed: _duplicateSelected,
        ),
        ActionButton(
          visible: selectedModes.length > 0,
          text: "Deselect All",
          rightMargin: 25.0,
          onPressed: () {
            setState(() => selectedModes = []);
          },
        ),
        ActionButton(
          visible: selectAction == null && !isShowingMultipleLists && selectedModes.length > 0,
          text: "Create Show (${selectedModes.length})",
          rightMargin: 25.0,
          onPressed: () {
            Navigator.pushNamed(context, '/shows/new',
              arguments: {'modes': firstList.modes}
            ).then((saved) {
              if (saved) {
                showExpandedActionButtons = false;
                isSelecting = false;
                selectedModes = [];
                _fetchModes();
              }
            });
          },
        ),
        Container(
          margin: EdgeInsets.only(top: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              selectAction != null ? ActionButton(
                margin: EdgeInsets.only(bottom: 0),
                text: selectAction,
                onPressed: () {
                  Navigator.pop(context, selectedModes);
                },
              ) : ActionButton(
                margin: EdgeInsets.only(bottom: 0),
                text: "Save (${selectedModes.length}) to list",
                onPressed: () {
                  if (selectedModes.length > 0)
                    Navigator.pushNamed(context, '/lists/new', arguments: {
                      'selectedModes': selectedModes,
                    }).then((saved) {
                      if (saved) {
                        showExpandedActionButtons = false;
                        isSelecting = false;
                        selectedModes = [];
                        _fetchModes();
                      }
                    });
                },
              ),
              Container(
                height: 20,
                width: 20,
                child: FloatingActionButton.extended(
                  backgroundColor: AppController.red,
                  label: Text("X"),
                  heroTag: "cancel",
                  onPressed: () {
                    setState(() {
                      isSelecting = false;
                      selectedModes = [];
                    });
                  },
                )
              )
            ]
          )
        )
      ]
    );
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


  Widget _ModeItem(mode) {
    var index = selectedModes.indexOf(mode) + 1;
    var isSelected = index > 0;
    return Card(
      key: Key(mode.id.toString()),
      elevation: 8.0,
      margin: EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      child: Column(
        children: [
          Container(
            child: ListTile(
              onTap: () {
                if (isSelecting)
                  setState(() {
                    if (selectedModes.contains(mode))
                      selectedModes.removeWhere((item) => item == mode);
                    else selectedModes.add(mode);
                  });
                else {
                  if (isAdjustingInlineParam) return;
                  Group.currentProps.forEach((prop) => prop.currentMode = mode );
                  setState(() {});
                }
              },
              contentPadding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 5.0),
              leading: isEditing ? ReorderableListener(child: Icon(Icons.drag_indicator, color: Color(0xFF888888))) : (!isSelecting ? null : Container(
                width: 22,
                padding: EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected ? Color(0xFF4f8adb) : null,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                child: Text(
                  isSelected ? index.toString() : "",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                  )
                ),
              )),
              trailing: _TrailingIcon(mode),
              title: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        margin: EdgeInsets.only(right: 15),
                        child: ModeImage(
                          mode: mode,
                          size: 30.0,
                        )
                      ),
                      GestureDetector(
                        onTap: () {
                          if (isExpanded(mode))
                            expandedModes.remove(mode);
                          else expandedModes.add(mode);
                          setState(() {});
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(child: Text(mode.name,
                                  overflow: TextOverflow.ellipsis,
                                )),
                                Container(
                                  child: isSelecting ? null :
                                    isExpanded(mode) ? Icon(Icons.expand_more) : Icon(Icons.chevron_right),
                                )
                              ]
                            ),
                            Container(
                              child: !Prop.connectedModeIds.contains(mode.id) ? null : Text(
                                "${Prop.connectedModeIds.where((id) => mode.id == id).length} props activated",
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppController.purple,
                                )
                              ),
                            ),
                          ]
                        )
                      )
                    ]
                  ),
                ]
              )
            ),
          ),
          Container( child:
            !isExpanded(mode) || isSelecting ? null : Stack(
              children: [
                Positioned.fill(
                  child: ColorFiltered(
                    colorFilter: ColorFilter.matrix(
                      ColorFilterGenerator.brightnessAdjustMatrix(
                        initialValue: 0.5,
                        value: 0.56,
                      )
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage("assets/images/dark-texture.jpg"),
                          fit: BoxFit.fill,
                        ),
                      )
                    )
                  ),
                ),
                //TODO: turn the following container into a:
                //   HorizontalLineShadow(spreadRadius: 2.0, blurRadius: 2.0),
                Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xAA000000),
                        spreadRadius: 2.0,
                        blurRadius: 2.0,
                      ),
                    ]
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                    )
                  )
                ),
                Container(
                  child: Container(
                    margin: EdgeInsets.only(top: 12, bottom: 14, right: 26, left: 10),
                    child: _ModeTileParams(mode),
                  ),
                  // decoration: BoxDecoration(
                  //   boxShadow: [
                  //     const BoxShadow(
                  //       color: Color(0xAA000000),
                  //     ),
                  //     const BoxShadow(
                  //       color: Color(0xFF888888),
                  //       offset: Offset(0.0, 2),
                  //       spreadRadius: -2.0,
                  //       blurRadius: 8.0,
                  //     ),
                  //   ],
                  // ),
                ),
              ]
            )
          ),
          Container(
            height: 15,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Color(0xAA000000),
                  spreadRadius: 2.0,
                  blurRadius: 2.0,
                ),
              ]
            ),
            child: ModeRow(
              mode: mode,
              showImages: true,
              fit: BoxFit.fill,
            ),
          ),
        ]
      ),
    );
  }

  Timer _adjustingInlineParamTimer;
  Widget _ModeTileParams(mode) {
    return InlineModeParams(
      onTouchDown: () {
        _adjustingInlineParamTimer?.cancel();
        isAdjustingInlineParam = true;
      },
      onTouchUp: () {
        _adjustingInlineParamTimer = Timer(Duration(seconds: 1), () => isAdjustingInlineParam = false);
        setState(() {});
      },
      mode: mode,
    );
  }

  Widget _TrailingIcon(mode) {
    if (isEditing)
      return GestureDetector(
        onTap: () {
					AppController.openDialog("Are you sure?", "This will remove \"${mode.name}\" from this list along with any customizations made to it.",
            buttonText: 'Cancel',
						buttons: [{
							'text': 'Delete',
              'color': Colors.red,
							'onPressed': () {
                _removeMode(mode);
							},
						}]
					);
        },
        child: Icon(Icons.delete_forever, color: AppController.red),
      );
    else if (isSelecting)
      return null;
    else return GestureDetector(
      onTap: () {
        var replacement = mode.dup();
        Navigator.pushNamed(context, '/modes/${replacement.id}', arguments: {
          'mode': replacement,
        }).then((saved) {
          if (saved == true)
            setState(() {
              mode.updateFromCopy(replacement).then((_) {
                _fetchModes();
              });
            });
        });
      },
      child: Column(
        children: [
          // Icon(Icons.edit),
          Text("EDIT", style: TextStyle(fontSize: 12)),
        ]
      )
    );
  }

  Widget _editGroupsWidget() {
    return Container(
      width: 300,
      height: 500,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      child: EditGroups(),
    );
  }

  Future<void> _duplicateSelected() {
    Client.updateList(firstList.id, {'append': selectedModesIds}).then((response) {
      var list = firstList;
      setState(() {
        if (!response['success'])
          errorMessage = response['message'];
        else modeLists[0] = response['modeList'];
        showExpandedActionButtons = false;
        isSelecting = false;
      });
    });
  }

  Future<void> _removeMode(mode) {
    Client.removeMode(mode).then((response) {
      var list = firstList;
      setState(() {
        if (!response['success'])
          errorMessage = response['message'];
        else list.modes.remove(mode);
      });
    });
  }

  String _getTitle() {
    if (isSelecting)
      return "${selectedModes.length} item selected";
    else if (modeLists.length != 0 && !isShowingMultipleLists)
      return firstList?.name ?? 'Modes';
    else return "Modes";
  }

  bool get isShowingMultipleLists => modeLists.length > 1;

}

