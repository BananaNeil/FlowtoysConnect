import 'package:flutter_reorderable_list/flutter_reorderable_list.dart';
import 'package:app/components/reordable_list_simple.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:app/models/mode_list.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/models/mode.dart';
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
  bool isTopLevelRoute;
  List<Mode> modes = [];
  bool isEditing = false;
  List<ModeList> modeLists;
  List<Mode> selectedModes = [];
  bool awaitingResponse = false;
  bool showExpandedActionButtons = false;

  Future<void> _fetchModes() {
    setState(() { awaitingResponse = true; });
    return Client.getModeList(id ?? 'default').then((response) {
      setState(() {
        if (response['success']) {
          awaitingResponse = false;
          var list = response['modeList'];
          if (list != null) modeLists = [list];
          else modeLists = response['modeLists'] ?? [];
        } else errorMessage = response['message'];
      });
    });
  }

  @override initState() {
    isTopLevelRoute = !Navigator.canPop(context);
    super.initState();
    _fetchModes();
  }

  @override
  Widget build(BuildContext context) {
    // _fetchModes();
    modeLists = modeLists ?? [AppController.getParams(context)['modeList']]..removeWhere((v) => v == null);
    isSelecting = isSelecting ?? AppController.getParams(context)['isSelecting'] ?? false;

    return Scaffold(
      floatingActionButton: _FloatingActionButton(),
      backgroundColor: AppController.darkGrey,
      drawer: isTopLevelRoute ? AppController.drawer() : null,
      appBar: AppBar(
        title: Text(_getTitle()), backgroundColor: Color(0xff222222),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.content_paste),
          ),
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
                    children: _ListItems(),
                    onReorder: (int start, int current) {
                      if (isShowingMultipleLists) return;
                      var list = modeLists[0];
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

  List<Widget> _ListItems() {
    return modeLists.map((list) {
      var items = list.modes.map(_ModeItem).toList();
      if (isShowingMultipleLists)
        items.insert(0, _ListTitle(list));
      return items;
    }).expand((i) => i).toList();
  }

  List<Mode> allModes() {
    return modeLists.map((list) => list.modes).expand((i) => i).toList();
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
          isShowingMultipleLists ? Container() : FloatingActionButton.extended(
            backgroundColor: AppController.green,
            label: Text("Edit Modes"),
            heroTag: "save_list",
            onPressed: () {
              setState(() { isEditing = true; });
            },
          ),
          SizedBox(height: 10),
          FloatingActionButton.extended(
            backgroundColor: AppController.green,
            label: Text("Select Modes"),
            heroTag: "save_list",
            onPressed: () {
              setState(() { isSelecting = true; });
            },
          ),
          SizedBox(height: 10),
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              shape: BoxShape.circle,
            ),
            child: FloatingActionButton(
              onPressed: () {
                setState(() { showExpandedActionButtons = false; });
              },
              child: Icon(
                Icons.expand_more,
                color: Colors.white,
              ),
              backgroundColor: AppController.darkGrey,
            ),
          )
        ]
      );
    else return Container(
      height: 40,
      width: 40,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 3),
        shape: BoxShape.circle,
      ),
      child: FloatingActionButton(
        onPressed: () {
          setState(() { showExpandedActionButtons = true; });
        },
        child: Icon(
          Icons.more_horiz,
          color: Color(0xffFFFFFF)
        ),
        backgroundColor: AppController.darkGrey,
      ),
    );
  }

  Widget _SelectionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton.extended(
          backgroundColor: AppController.green,
          label: Text("Save (${selectedModes.length}) to list"),
          heroTag: "save_list",
          onPressed: () {
            Navigator.pushNamed(context, '/lists/new', arguments: {
              'selectedModes': selectedModes,
            }).then((_) => _fetchModes());
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
      child: ListTile(
        onTap: () {
          if (isSelecting)
            setState(() {
              if (selectedModes.contains(mode))
                selectedModes.removeWhere((item) => item == mode);
              else selectedModes.add(mode);
            });
          else
            Navigator.pushNamed(context, '/modes/${mode.id}', arguments: {
              'mode': mode,
            }).then((_) => _fetchModes());
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
        title: Text(mode.name),
      ),
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
                removeMode(mode);
							},
						}]
					);
        },
        child: Icon(Icons.delete_forever, color: AppController.red),
      );
    else if (isSelecting)
      return null;
    else return Icon(Icons.arrow_forward);
  }

  Future<void> removeMode(mode) {
    Client.removeMode(mode).then((response) {
      var list = modeLists[0];
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
      return modeLists[0]?.name ?? 'Modes';
    else return "Modes";
  }

  bool get isShowingMultipleLists => modeLists.length > 1;

}

