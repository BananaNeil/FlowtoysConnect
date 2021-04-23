import 'package:flutter_reorderable_list/flutter_reorderable_list.dart';
import 'package:app/components/bridge_connection_status_icon.dart';
import 'package:app/helpers/color_filter_generator.dart';
import 'package:app/components/edit_mode_widget.dart';
import 'package:app/components/mode_list_widget.dart';
import 'package:app/helpers/animated_clip_rect.dart';
import 'package:app/components/now_playing_bar.dart';
import 'package:app/components/action_button.dart';
import 'package:app/components/global_params.dart';
import 'package:app/components/share_modal.dart';
import 'package:app/components/navigation.dart';
import 'package:app/helpers/filter_controller.dart';
import 'package:app/models/mode_list.dart';
import 'package:app/authentication.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/models/bridge.dart';
import 'package:app/models/group.dart';
import 'package:app/models/mode.dart';
import 'package:app/models/prop.dart';
import 'package:app/preloader.dart';
// import 'package:rxdart/rxdart.dart';
import 'package:badges/badges.dart';
import 'package:app/client.dart';
import 'dart:async';

class Modes extends StatelessWidget {
  Modes({this.id, this.hideNavigation, this.canShowDefaultLists});
  final String id; 

  final bool hideNavigation;
  final bool canShowDefaultLists;

  @override
  Widget build(BuildContext context) {
    // Bridge.oscManager.discoverServices();
    print("VERSION: ${AppController.version} ${AppController.buildNumber} ${AppController.operatingSystem}");
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
    // listenForAudio();
    super.initState();
  }

  // StreamSubscription<List<int>> audioListener;
  // listenForAudio() async {
  //   print("Start listen");
  //   var stream = await Bridge.getAudioStream();
  //   print("Start listening!!!!");
  //   audioListener ??= stream.listen((samples) => print(samples));
  // }

  @override
  Widget build(BuildContext context) {
    modeLists ??= [AppController.getParams(context)['modeList']]..removeWhere((v) => v == null);
    canChangeCurrentList ??= AppController.getParams(context)['canChangeCurrentList'] ?? false;
    isSelecting ??= AppController.getParams(context)['isSelecting'] ?? false;
    selectedModes ??= AppController.getParams(context)['selectedModes'] ?? [];
    selectAction ??= AppController.getParams(context)['selectAction'];
    returnList ??= AppController.getParams(context)['returnList'];


    // audioListener ??= Bridge.audioStream.listen((samples) => print(samples));

    print("BUILD MODE ROUTEc!!cA;  ${id}");
    return Scaffold(
      floatingActionButton: _FloatingActionButton,
      backgroundColor: AppController.darkGrey,
      drawer: !hideNavigation && isTopLevelRoute ? Navigation() : null,
      appBar: AppBar(
        backgroundColor: Color(0xff222222),
        title: Column(
            children: [
              Text(_getTitle()),
              _ShareButton(),
            ]
        ),
        leading: isTopLevelRoute ? null : IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, returnList == true ? firstList : null);
          },
        ),
        actions: [

          hideNavigation ? Container() :
            BridgeConnectionStatusIcon(),
          // _EditGroupButton(),
          // _EditGroupButton(),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children:[
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
              !showNowPlaying ?
              _BottomBarExpandedActionButtons() :
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
                  switchCurrentPropsToComputedMode(modeBeforeMode);
                },
              ),
            ]
          ),
          Column(
            children: showOneColumn ? [] : [
              GlobalParams(filterController: filterController),
            ]
          ),
        ]
      ),
    );
  }

  bool get showNowPlaying => !showExpandedActionButtons && !isSelecting;

  Widget _BottomBarExpandedActionButtons() {
    if (isEditing) return Container();
    if (isSelecting) return Container();

    return Badge(
      toAnimate: false,
      position: BadgePosition.topEnd(top: -12, end: 7),
      badgeContent: GestureDetector(
        behavior: HitTestBehavior.translucent,
        child: Container(
            margin: EdgeInsets.all(5),
            padding: EdgeInsets.only(bottom: 1),
            child: Text('X', style: TextStyle(fontSize: 12)),
        ),
        onTap: () {
          showExpandedActionButtons = false;
          setState((){});
        }
      ),
      child: Row(
        children: [
          Visibility(
            visible: !isShowingMultipleLists,
            child: Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() { isEditing = true; });
                },
                child: Container(
                  padding: EdgeInsets.only(top: 15, bottom: 20),
                  decoration: BoxDecoration(color: Color(0xFF222222)),
                  child: Text('Edit Modes', textAlign: TextAlign.center),
                )
              )
            )
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                showExpandedActionButtons = false;
                setState(() { isSelecting = true; });
              },
              child: Container(
                padding: EdgeInsets.only(top: 15, bottom: 20),
                decoration: BoxDecoration(color: Color(0xFF222222)),
                child: Text('Select Modes', textAlign: TextAlign.center),
              )
            )
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
      return Client.getModeLists(creationType: 'system');
    else return Client.getModeList(id);
  }

  Future<void> requestFromCache() async {
    var query = showDefaultLists ? {'creation_type': 'system'} : {'id': id};
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
        if (this.mounted) // I don't know why this is needed, but I was seeing a memory leak here.
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
    Group.current.forEach((group) {
      // This commented out code was writen to handle multiple props within a group that have
      // different modes, and need to go to the next mode. Maybe just scrap all of it?
      //
      // String groupId = group.id;
      // Group group = props.first.group;
      // bool isEntireGroup = group.props.length == props.length;
      // bool allPropsHaveSameMode;
      // if (isEntireGroup)
      //   allPropsHaveSameMode = props.every((prop) => prop.currentModeId == props.first.currentModeId);
      //
      // if (isEntireGroup && allPropsHaveSameMode)
        group.currentMode = computeMode(group.props.first.currentMode);
      // else
      //   props.forEach((prop) {
      //     prop.currentMode = computeMode(prop.currentMode);
      //   });
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
      return [_ModeList(modeLists)];
    else return modeLists.map<Widget>((list) {
      return _ModeList([list]);
    }).toList();
  }

  bool get showOneColumn => modeLists.length <= 1 || AppController.screenWidth < 300 * modeLists.length;

  FilterController filterController = FilterController();


  Widget _ModeList(lists) {
    return ModeListWidget(
      modeLists: lists,
      isEditing: isEditing,
      onRemove: _removeMode,
      isSelecting: isSelecting,
      hideFilters: !showOneColumn,
      onRefresh: _forceFetchModes,
      selectedModeIds: selectedModeIds,
      setCurrentLists: _setCurrentLists,
      showTitles: isShowingMultipleLists,
      filterController: filterController,
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




  Widget get _FloatingActionButton {
    if (showNowPlaying) return null;
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
      return null;
    else return GestureDetector(
      onTap: () {
        setState(() { showExpandedActionButtons = true; });
      },
      child: Container(
        padding: EdgeInsets.only(right: AppController.isSmallScreen ? 10 : 25, top: 10),
        child: Icon(
          Icons.more_horiz,
          color: Colors.white,
        ),
      ),
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
              _CloseExpandedButtons(),
            ]
          )
        )
      ]
    );
  }

  Widget _CloseExpandedButtons() {
    return Container(
      height: 20,
      width: 20,
      child: FloatingActionButton.extended(
        backgroundColor: AppController.red,
        label: Text("X"),
        heroTag: "cancel",
        onPressed: () {
          setState(() {
            showExpandedActionButtons = true;
            isSelecting = false;
            selectedModes = [];
          });
        },
      )
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

  Widget _ShareButton() {
    return Visibility(
      visible: isShowingOneList,
      child: GestureDetector(
        onTap: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => StatefulBuilder(
              builder: (BuildContext context, setState) => ShareModal(shareable: modeLists.first),
            ),
          );
        },
        child: Container(
          margin: EdgeInsets.only(top:3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                margin: EdgeInsets.only(right: 4),
                child: Text('SHARE', style:TextStyle(fontSize: 12)),
              ),
              Icon(Icons.share, size: 14),
            ]
          )
        )
      )
    );
  }

  String _getTitle() {
    if (isSelecting)
      return "${selectedModes.length} item selected";
    else if (isShowingOneList)
      return firstList?.name ?? 'Modes';
    else return "Modes";
  }

  bool get isShowingMultipleLists => modeLists.length > 1;
  bool get isShowingOneList => modeLists.length == 1;

}



