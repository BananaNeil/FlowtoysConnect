import 'package:flutter_reorderable_list/flutter_reorderable_list.dart';
import 'package:app/components/reordable_list_simple.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:app/components/edit_mode_widget.dart';
import 'package:app/components/edit_groups.dart';
import 'package:app/components/mode_widget.dart';
import 'package:app/models/mode_list.dart';
import 'package:app/authentication.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/models/group.dart';
import 'package:app/models/mode.dart';
import 'package:app/preloader.dart';
import 'package:app/client.dart';

class Modes extends StatelessWidget {
  Modes({this.id});

  final String id; 

  @override
  Widget build(BuildContext context) {
    return ModesPage(id: id);
  }
}

class ModesPage extends StatefulWidget {
  ModesPage({Key key, this.id}) : super(key: key);
  final String id;

  @override
  _ModesPageState createState() => _ModesPageState(id);
}

class _ModesPageState extends State<ModesPage> {
  _ModesPageState(this.id);

  final String id;

  bool isSelecting;
  String errorMessage;
  String selectAction;
  bool isTopLevelRoute;
  List<Mode> modes = [];
  bool isEditing = false;
  List<ModeList> modeLists;
  Mode currentlyEditingMode;
  List<Mode> selectedModes = [];
  bool awaitingResponse = false;
  ModeList get firstList => modeLists.isEmpty ? null : modeLists[0];
  bool showExpandedActionButtons = false;


  List<String> get selectedModesIds => selectedModes.map((mode) => mode.id).toList();

  List<Mode> get allModes => modeLists.map((list) => list.modes).expand((m) => m).toList();

  Future<Map<dynamic, dynamic>> _makeRequest() {
    if (id == null)
      return Client.getModeLists(creationType: 'auto');
    else return Client.getModeList(id);
  }

  Future<void> requestFromCache() async {
    var query = id == null ? {'creation_type': 'auto'} : {'id': id};
    return Preloader.getModeLists(query).then((lists) {
      setState(() => modeLists = lists);
    });
  }

  Future<void> _fetchModes({initialRequest}) {
    print("authed? ${Authentication.isAuthenticated()} **** lists: ${modeLists.length}");
    if (!Authentication.isAuthenticated() && modeLists.length > 0) return Future.value(null);
    setState(() { awaitingResponse = true; });
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
  }

  @override initState() {
    isTopLevelRoute = !Navigator.canPop(context);
    requestFromCache().then((_) => _fetchModes(initialRequest: true));
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    modeLists = modeLists ?? [AppController.getParams(context)['modeList']]..removeWhere((v) => v == null);
    isSelecting = isSelecting ?? AppController.getParams(context)['isSelecting'] ?? false;
    selectAction = selectAction ?? AppController.getParams(context)['selectAction'];
    var propCount = Group.currentQuickGroup.props.length;

    return Scaffold(
      floatingActionButton: _FloatingActionButton(),
      backgroundColor: AppController.darkGrey,
      drawer: isTopLevelRoute ? AppController.drawer() : null,
      appBar: AppBar(
        title: Text(_getTitle()), backgroundColor: Color(0xff222222),
        leading: isTopLevelRoute ? null : IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, null);
          },
        ),
        actions: <Widget>[
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
              child: Text(
                  propCount <= 0 ? "warning" :
                 'filter_${propCount > 8 ? '9_plus': propCount}',
                style: TextStyle(
                  fontFamily: 'MaterialIcons',
                  fontSize: 24,
                )
              ),
            ),
          )
          // IconButton(
          //   icon: Icon(Icons.filter_7),
          // ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchModes,
                child: Container(
                  decoration: BoxDecoration(color: Color(0xFF2F2F2F)),
                  child: ReorderableListSimple(
                    childrenAlreadyHaveListener: true,
                    allowReordering: isEditing,
                    children: [
                      ..._ListItems,
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
          ],
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

  List<Widget> get _ListItems {
    return modeLists.map((list) {
      var items = list.modes.map(_ModeItem).toList();
      if (isShowingMultipleLists)
        items.insert(0, _ListTitle(list));
      return items;
    }).expand((i) => i).toList();
  }

  Widget _FloatingActionButton() {
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
          _ActionButton(
            visible: !isShowingMultipleLists,
            text: "Edit Modes",
            onPressed: () {
              setState(() { isEditing = true; });
            },
          ),
          _ActionButton(
            visible: !isShowingMultipleLists,
            text: "Create Show",
            onPressed: () {
              Navigator.pushNamed(context, '/shows/new', arguments: {'modes': firstList.modes});
            },
          ),
          _ActionButton(
            text: "Select Modes",
            onPressed: () {
              setState(() { isSelecting = true; });
            },
          ),
          _ActionButton(
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
    else return _ActionButton(
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
        _ActionButton(
          visible: selectedModes.length < allModes.length,
          text: "Select All",
          rightMargin: 25.0,
          onPressed: () {
            setState(() => selectedModes = allModes);
          },
        ),
        _ActionButton(
          visible: !isShowingMultipleLists && selectedModes.length > 0,
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
        _ActionButton(
          visible: !isShowingMultipleLists && selectedModes.length > 0,
          text: "Duplicate (${selectedModes.length})",
          rightMargin: 25.0,
          onPressed: _duplicateSelected,
        ),
        _ActionButton(
          visible: selectedModes.length > 0,
          text: "Deselect All",
          rightMargin: 25.0,
          onPressed: () {
            setState(() => selectedModes = []);
          },
        ),
        Container(
          margin: EdgeInsets.only(top: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              selectAction != null ? _ActionButton(
                margin: EdgeInsets.only(bottom: 0),
                text: selectAction,
                onPressed: () {
                  Navigator.pop(context, selectedModes);
                },
              ) : _ActionButton(
                margin: EdgeInsets.only(bottom: 0),
                text: "Save (${selectedModes.length}) to list",
                onPressed: () {
                  if (selectedModes.length > 0)
                    Navigator.pushNamed(context, '/lists/new', arguments: {
                      'selectedModes': selectedModes,
                    }).then((_) {
                      showExpandedActionButtons = false;
                      isSelecting = false;
                      selectedModes = [];
                      _fetchModes();
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
              subtitle: isSelecting ? null : Container(
                margin: EdgeInsets.only(top: 10),
                child: _ModeTileParams(mode),
              ),
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
                      Column(
                        children: [
                          Text(mode.name),
                        ]
                      )
                    ]
                  ),
                ]
              )
            ),
          ),
          Container(
            height: 15,
            child: ModeRow(
              mode: mode,
              showImages: true,
              fit: BoxFit.fill,
            ),
          )
        ]
      ),
    );
  }

  List<Color> get hueColors {
    var color = HSVColor.fromColor(Colors.blue);
    return List<int>.generate(7, (int index) => index * 60 % 360).map((degree) {
      return color.withHue(1.0 * degree).toColor();
    }).toList();
  }

  Widget _ModeTileParams(mode) {
    var color = mode.getHSVColor();
    var colors = {
      'hue': color.withSaturation(1.0).withValue(1.0).toColor(),
      'saturation': color.withValue(1.0).toColor(),
      'brightness': color.toColor(),
    };

    Map<String, List<Color>> gradients = {
      'hue': hueColors,
      'saturation': [color.withValue(1.0).withSaturation(0.0).toColor(), color.withValue(1.0).withSaturation(1.0).toColor()],
      'brightness': [color.withValue(0.0).toColor(), color.withValue(1.0).toColor()],
    };
    var icons = {
      'brightness': 'brightness_medium',
      'saturation': 'opacity',
      'speed': 'fast_forward',
      'hue': 'color_lens',
      'density': 'waves',
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        null,
        'hue',
        'saturation',
        'brightness',
        'density',
        'speed',
      ].map<Widget>((paramName) {
        if (paramName == null)
          return Container(width: 0);
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 37,
              width: 37,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF333333),
                    spreadRadius: 2.0,
                    blurRadius: 2.0,
                  ),
                ],
                color: color.toColor(),
                shape: BoxShape.circle,
              )
            ),
            Container(
                height: 30,
                width: 30,
                padding: EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                ),
                child: Text(icons[paramName],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                    fontFamily: 'MaterialIcons',
                    fontSize: 22,
                  )
            )
          ]
        );
      }).toList()
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
      child: Icon(Icons.donut_small),
      onTap: () {
        currentlyEditingMode = mode;

        showModalBottomSheet(
          context: context,
          builder: (context) => _editModeWidget(mode),
        );
      },
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

  Widget _editModeWidget(mode) {
    return Container(
      height: mode.accessLevel == 'frozen' ? 300 : 450,
      child: EditModeWidget(
        editDetails: true,
        onChange: (mode) {
           setState((){}); 
        },
        sliderHeight: 20.0,
        mode: mode,
      )
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

  Widget _ActionButton({text, child, onPressed, visible, margin, rightMargin}) {
    return Visibility(
      visible: visible ?? true,
      child: Container(
        height: 40,
        width: child != null ? 40 : null,
        margin: margin ?? EdgeInsets.only(top: 10, right: rightMargin ?? 0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: child != null ? FloatingActionButton(
          backgroundColor: AppController.darkGrey,
          onPressed: onPressed,
          heroTag: "icon child",
          child: child,
        ) : FloatingActionButton.extended(
          backgroundColor: AppController.darkGrey,
          label: Text(text, style: TextStyle(color: Colors.white)),
          heroTag: text,
          onPressed: onPressed,
        ),
      )
    );
  }

}

