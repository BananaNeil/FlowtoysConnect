import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:app/models/mode_list.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/models/mode.dart';
import 'package:app/client.dart';

class NewList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return NewListPage(title: 'NewList');
  }
}

class NewListPage extends StatefulWidget {
  NewListPage({Key key, this.title}) : super(key: key);
  String title;

  @override
  _NewListPageState createState() => _NewListPageState();
}

class _NewListPageState extends State<NewListPage> {

  List<ModeList> modeLists = [];
  List<Mode> selectedModes = [];
  bool awaitingResponse = false;
  bool isSelecting = false;
  String newListName = '';
  String listErrorMessage;
  String errorMessage;

  void fetchLists() {
    setState(() { awaitingResponse = true; });
    Client.getModeLists(type: 'custom').then((response) {
      setState(() {
        awaitingResponse = false;
        if (!response['success'])
          setState(() => listErrorMessage = response['message'] );
        else modeLists = response['modeLists'];
      });
    });
  }

  @override initState() {
    super.initState();
    fetchLists();
  }

  Future<void> _createNewList() {
    if (newListName.length == 0) return null;
    return Client.createNewList(newListName, selectedModes).then((response) {
      var list = response['modeList'];
      if (!response['success'])
        setState(() => errorMessage = response['message'] );
      else Navigator.pushReplacementNamed(context, "/lists/${list.id}", arguments: {
          'modeList': list,
        });
    });
  }

  Future<void> _updateList(list) {
    return Client.updateList(list.id, append: selectedModes);
  }

  @override
  Widget build(BuildContext context) {
    selectedModes = (ModalRoute.of(context).settings.arguments as Map)['selectedModes']; 
      return GestureDetector(
        onTap: AppController.closeKeyboard,
        child: Scaffold(
        appBar: AppBar(
          title: Text("Save ${selectedModes.length} Modes to a List"),
          backgroundColor: Color(0xff222222),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 10),
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Create a new list...',
                  ),
                  onChanged: (text) {
                    setState(() {
                      newListName = text;
                    });
                  }
                )
              ),
              Visibility(
                visible: errorMessage != null,
                child: Text(errorMessage ?? "", textAlign: TextAlign.center, style: TextStyle(color: AppController.red)),
              ),
              Container(
                margin: EdgeInsets.only(top: 10),
                child: GestureDetector(
                  onTap: _createNewList,
                  // Add a spinner here!!
                  child: Text('SAVE',
                    style: TextStyle(
                      color: newListName.length == 0 ?
                      AppController.grey :
                      AppController.blue,
                    )
                  ),
                ),
              ),
              Visibility(
                visible: listErrorMessage == null && modeLists.length > 0,
                child: Container(
                  margin: EdgeInsets.only(top: 50),
                  child: Text("Add to an existing List",
                    style: TextStyle(
                      fontSize: 22,
                    )
                  )
                ),
              ),
              Visibility(
                visible: listErrorMessage == null && modeLists.length > 0,
                child: Expanded(
                  child: ListView(
                    children: _ExistingLists()
                  ),
                )
              ),
            ],
          ),
        ),
      )
    );
  }

  List<Widget> _ExistingLists() {
    if (listErrorMessage != null)
      return [Text(listErrorMessage, textAlign: TextAlign.center, style: TextStyle(color: AppController.red))];
    else if (modeLists.length == 0)
      return [
        Container(
          margin: EdgeInsets.only(top: 20, bottom: 20),
          child: awaitingResponse ?
            SpinKitCircle(color: AppController.blue) :
            Text("You have no existing lists.", textAlign: TextAlign.center),
        )
      ];
    else return modeLists.map((modeList) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          Client.updateList(modeList.id, append: selectedModes).then((response) {
            if (!response['success'])
              setState(() => listErrorMessage = response['message'] );
            else Navigator.pushReplacementNamed(context, "/lists/${modeList.id}", arguments: {
                'modeList': modeList,
              });
          });
        },
        child: Container(
          padding: EdgeInsets.all(20.0),
          child: Row(
            children: [
              Text(modeList.name),
            ]
          )
        )
      );
    }).toList();
  }

}

