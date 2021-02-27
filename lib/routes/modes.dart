import 'package:flutter_reorderable_list/flutter_reorderable_list.dart';
import 'package:app/components/bridge_connection_status.dart';
import 'package:app/helpers/color_filter_generator.dart';
import 'package:app/components/modes_filter_bar.dart';
import 'package:app/components/edit_mode_widget.dart';
import 'package:app/components/mode_list_widget.dart';
import 'package:app/helpers/animated_clip_rect.dart';
import 'package:app/components/now_playing_bar.dart';
import 'package:app/components/action_button.dart';
import 'package:app/components/navigation.dart';
import 'package:app/models/mode_list.dart';
import 'package:app/authentication.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/models/bridge.dart';
import 'package:app/models/group.dart';
import 'package:app/models/mode.dart';
import 'package:app/models/prop.dart';
import 'package:app/preloader.dart';
import 'package:rxdart/rxdart.dart';
import 'package:badges/badges.dart';
import 'package:app/client.dart';

class Modes extends StatelessWidget {
  Modes({this.id, this.hideNavigation, this.canShowDefaultLists});
  final String id; 

  final bool hideNavigation;
  final bool canShowDefaultLists;

  @override
  Widget build(BuildContext context) {
    // Bridge.oscManager.discoverServices();
    print("BUILD MODES: ${Authentication.currentAccount.toMap()}");
    return ModesPage(
      canShowDefaultLists: canShowDefaultLists,
      hideNavigation: hideNavigation,
      key: Key(id),
      id: id,
    );
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
  final String id;

  @override initState() {
    AppController.initConnectionManagers();
    isTopLevelRoute = !Navigator.canPop(context);
    requestFromCache().then((_) => _fetchModes(initialRequest: true));
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    modeLists ??= [AppController.getParams(context)['modeList']]..removeWhere((v) => v == null);
    canChangeCurrentList ??= AppController.getParams(context)['canChangeCurrentList'] ?? false;
    isSelecting ??= AppController.getParams(context)['isSelecting'] ?? false;
    selectedModes ??= AppController.getParams(context)['selectedModes'] ?? [];
    selectAction ??= AppController.getParams(context)['selectAction'];
    returnList ??= AppController.getParams(context)['returnList'];

    print("BUILD MODE ROUTEc!!cA;  ${id}");
    return Scaffold(
      floatingActionButton: _FloatingActionButton,
      backgroundColor: AppController.darkGrey,
      drawer: !hideNavigation && isTopLevelRoute ? Navigation() : null,
      appBar: AppBar(
        backgroundColor: Color(0xff222222),
        title: Text(_getTitle()),
        leading: isTopLevelRoute ? null : IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, returnList == true ? firstList : null);
          },
        ),
        actions: [

          hideNavigation ? Container() :
            BridgeConnectionStatus(),
          // _EditGroupButton(),
          // _EditGroupButton(),
        ],
      ),
      body: Column(
        children:[
          showOneColumn ? Container() : _FilterBar(),
          Container(width: double.infinity,
            height: errorMessage == null ? 0 : null,
            padding: errorMessage == null ? null : EdgeInsets.symmetric(vertical: 5),
            child: Text(errorMessage ?? "",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppController.red
              )
            )
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _ModeLists,
            )
          ),
          NowPlayingBar(
            shuffle: shuffle,
            toggleShuffle: () {
              setState(() => shuffle = !shuffle);
            },
            onMenuTap: () {
              setState(() { showExpandedActionButtons = true; });
            },
            onNext: () {
              switchCurrentPropsToComputedMode(modeAfterMode);
            },
            onPrevious: () {
              switchCurrentPropsToComputedMode( modeBeforeMode);
            },
          ),

        ]
      )
    );
  }

  bool returnList;
  bool isSelecting;
  String errorMessage;
  String selectAction;
  bool isTopLevelRoute;
  List<Mode> modes = [];
  bool isEditing = false;
  List<ModeList> modeLists;
  Mode currentlyEditingMode;
  bool canChangeCurrentList;
  List<Mode> selectedModes;
  bool awaitingResponse = false;
  ModeList get firstList => modeLists.isEmpty ? null : modeLists[0];
  bool showExpandedActionButtons = false;




  List<String> get selectedModeIds => selectedModes.map((mode) => mode.id).toList();

  List<Mode> get allModes => modeLists.map((list) => list.modes).expand((m) => m).toList();
  List<String> get allModesIds => allModes.map((mode) => mode.id).toList();

  bool shuffle = false;
  List<Mode> _shuffledModes;
  List<Mode> get shuffledModes => _shuffledModes ??= List.from(allModes)..shuffle();
  List<String> get shuffledModesIds => shuffledModes.map((mode) => mode.id).toList();

  bool get hideNavigation => widget.hideNavigation ?? false;
  bool get showDefaultLists => (widget.canShowDefaultLists ?? true) && id == null;

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

  Future<void> _forceFetchModes() {
    return _fetchModes(forceReload: true);
  }

  Future<void> _fetchModes({initialRequest, forceReload}) {
    if (!Authentication.isAuthenticated && modeLists.length > 0 && forceReload != true) return Future.value(null);
    setState(() { awaitingResponse = true; });
    return Preloader.downloadData().then((_) {
      errorMessage = null;
      return _makeRequest().then((response) {
        setState(() {
          if (response['success']) {
            awaitingResponse = false;


            // There is bug where selected modes get overridden when the fetch finishes...


            var list = response['modeList'];
            if (list != null) modeLists = [list];
            else modeLists = response['modeLists'] ?? [];


            _prependSelectedModes();
          } else if (initialRequest != true || modeLists.isEmpty)
            errorMessage = response['message'];
        });
      });
    });
  }

  void _setCurrentLists(lists) {
    modeLists = lists;
    _prependSelectedModes();
    setState(() {});
  }

  _prependSelectedModes() {
    ModeList selectedModeList = ModeList(name: "Selected", modes: []);
    selectedModes.forEach((mode) {
      if (!allModesIds.contains(mode.id))
        selectedModeList.modes.insert(0, mode);
    });
    if (selectedModeList.modes.isNotEmpty)
      modeLists.insert(0, selectedModeList);
  }

  void switchCurrentPropsToComputedMode(computeMode) {
    Prop.quickGroupPropsByGroupId.forEach((groupId, props) {
      Group group = props.first.group;
      bool isEntireGroup = group.props.length == props.length;
      bool allPropsHaveSameMode;
      if (isEntireGroup)
        allPropsHaveSameMode = props.every((prop) => prop.currentModeId == props.first.currentModeId);

      if (isEntireGroup && allPropsHaveSameMode)
        group.currentMode = computeMode(props.first.currentMode);
      else
        props.forEach((prop) {
          prop.currentMode = computeMode(prop.currentMode);
        });
    });

    setState(() {});
  }

  Mode modeBeforeMode(mode) {
    var ids = shuffle ? shuffledModesIds : allModesIds;
    var modes = shuffle ? shuffledModes : allModes;

    var currentModeIndex = ids.indexOf(mode.id);
    if (currentModeIndex <= 0)
      currentModeIndex = modes.length - 1;
    else currentModeIndex -= 1;
    return modes[currentModeIndex];
  }

  Mode modeAfterMode(mode) {
    var ids = shuffle ? shuffledModesIds : allModesIds;
    var modes = shuffle ? shuffledModes : allModes;

    var currentModeIndex = ids.indexOf(mode.id);
    if (currentModeIndex >= modes.length - 1)
      currentModeIndex = 0;
    else currentModeIndex += 1;
    return modes[currentModeIndex];
  }

  List<Widget> get _ModeLists {
    if (showOneColumn)
      return [_ModeList(modeLists, filterBar: _FilterBar())];
    else return modeLists.map<Widget>((list) {
      return _ModeList([list]);
    }).toList();
  }

  bool get showOneColumn => modeLists.length <= 1 || AppController.screenWidth < 300 * modeLists.length;

  static BehaviorSubject<Map<String, dynamic>> filterController = BehaviorSubject<Map<String, dynamic>>();

  Widget _ModeList(lists, {filterBar}) {
    return ModeListWidget(
      modeLists: lists,
      filterBar: filterBar,
      isEditing: isEditing,
      onRemove: _removeMode,
      isSelecting: isSelecting,
      onRefresh: _forceFetchModes,
      selectedModeIds: selectedModeIds,
      setCurrentLists: _setCurrentLists,
      showTitles: isShowingMultipleLists,
      filterStream: filterController.stream,
      toggleSelectedMode: _toggleSelectedMode,
      preventReordering: isShowingMultipleLists,
      canChangeCurrentList: canChangeCurrentList,
    );
  }

  void _toggleSelectedMode(mode) {
    setState(() {
      if (selectedModeIds.contains(mode.id))
        selectedModes.removeWhere((item) => item.id == mode.id);
      else selectedModes.add(mode);
    });
  }

  Widget _FilterBar() {
    return ModesFilterBar(filterController: filterController);
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
                      if (saved == true) {
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

  Future<void> _duplicateSelected() {
    Client.updateList(firstList.id, {'append': selectedModeIds}).then((response) {
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



