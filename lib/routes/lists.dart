import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:app/components/mode_widget.dart';
import 'package:app/models/mode_list.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/routes/modes.dart';
import 'package:app/preloader.dart';
import 'package:app/client.dart';

class Lists extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListsPage(title: 'Lists');
  }
}

class ListsPage extends StatefulWidget {
  ListsPage({Key key, this.title}) : super(key: key);
  String title;

  @override
  _ListsPageState createState() => _ListsPageState();
}

class _ListsPageState extends State<ListsPage> {

  bool awaitingResponse = false;
  ModeList selectedList = null;
  bool singlePageMode = false;
  List<ModeList> lists = [];
  bool isTopLevelRoute;
  String errorMessage;

  // Future<void> _deleteList(list) {
  //   return Client.deleteList(list.id, append: selectedModes);
  // }

  Future<void> requestFromCache() {
    return Preloader.getModeLists({'creation_type': 'user'}).then((modeLists) {
      setState(() => lists = modeLists);
    });
  }

  Future<void> fetchLists({initialRequest}) {
    setState(() {
      errorMessage = null;
      awaitingResponse = true;
    });
    return Client.getModeLists(creationType: 'user').then((response) {
      setState(() {
        awaitingResponse = false;
        if (response['success'])
          lists = response['modeLists'];
        else if (initialRequest != true || lists.isEmpty)
          setState(() => errorMessage = response['message'] );

        print(lists.map((list) => list.creationType));
      });
    });
  }

  @override initState() {
    isTopLevelRoute = !Navigator.canPop(context);
    super.initState();
    requestFromCache().then((_) => fetchLists(initialRequest: true));
  }

  @override
  Widget build(BuildContext context) {
    singlePageMode = AppController.screenWidth > 600;

    return GestureDetector(
      onTap: AppController.closeKeyboard,
      child: Scaffold(
        backgroundColor: AppController.darkGrey,
        drawer: isTopLevelRoute ? AppController.drawer() : null,
        appBar: AppBar(
          title: Text("My Lists"),
          backgroundColor: Color(0xff222222),
        ),
        body: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                child: Expanded(
                  child: RefreshIndicator(
                    onRefresh: fetchLists,
                    child: ListView(
                      padding: EdgeInsets.only(top: 5),
                      children: _Lists()
                    ),
                  ),
                )
              ),
              Container(
                child: singlePageMode ? Expanded(
                  child: ModesPage(id: selectedList?.id, hideNavigation: true, canShowDefaultLists: false),
                ) : null
              ),
            ],
          ),
        ),
      )
    );
  }

  List<Widget> _Lists() {
    if (errorMessage != null)
      return [Text(errorMessage, textAlign: TextAlign.center, style: TextStyle(color: AppController.red))];
    else if (lists.length == 0)
      return [
        Container(
          margin: EdgeInsets.only(top: 20, bottom: 20),
          child: awaitingResponse ?
            SpinKitCircle(color: AppController.blue) :
            Column(
              children: [
                Text("You have not created any lists yet!", textAlign: TextAlign.center),
                GestureDetector(
                  child: Text("CREATE ONE", textAlign: TextAlign.center, style: TextStyle(color: AppController.blue)),
                  onTap: () {
                    Navigator.pushReplacementNamed(context, '/modes', arguments: {'isSelecting': true});
                  }
                ),
              ]
            )
        ),
      ];
    else return (lists..removeWhere((value) => value == null)).map((list) {
      return Card(
        elevation: 8.0,
        child: ListTile(
          trailing: Icon(Icons.arrow_forward),
          onTap: () {
            if (singlePageMode) {
              setState(() {
                selectedList = (selectedList == list) ? [] : list;
              });
              return; 
            }

            Navigator.pushNamed(context, "/lists/${list.id}", arguments: {
              'modeList': list,
              'returnList': true,
            }).then((newList) {
              setState(() {
                lists[lists.indexOf(list)] = newList;
              });
            });
          },
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: EdgeInsets.only(top: 6, bottom: 10),
                child: Text(list.name, style: TextStyle(fontSize: 17)),
              ),
              Wrap(
                children: list.modes.map((mode) {
                  return Container(
                    margin: EdgeInsets.only(right: 4, bottom: 4),
                    child: ModeImage(mode: mode, size: 12)
                  );
                }).toList(),
              )
            ]
          ),
        )
      );
    }).toList();
  }

}


