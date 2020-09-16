import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:app/models/mode_list.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
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
  List<ModeList> lists = [];
  bool isTopLevelRoute;
  String errorMessage;

  Future<void> fetchLists() {
    setState(() {
      errorMessage = null;
      awaitingResponse = true;
    });
    return Client.getModeLists(type: 'custom').then((response) {
      setState(() {
        awaitingResponse = false;
        if (!response['success'])
          setState(() => errorMessage = response['message'] );
        else lists = response['modeLists'];
      });
    });
  }

  @override initState() {
    isTopLevelRoute = !Navigator.canPop(context);
    super.initState();
    fetchLists();
  }

  @override
  Widget build(BuildContext context) {
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: RefreshIndicator(
                  onRefresh: fetchLists,
                  child: ListView(
                    padding: EdgeInsets.only(top: 5),
                    children: _Lists()
                  ),
                ),
              )
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
    else return lists.map((list) {
      return Card(
        elevation: 8.0,
        child: ListTile(
          trailing: Icon(Icons.arrow_forward),
          onTap: () {
            Navigator.pushNamed(context, "/lists/${list.id}", arguments: {
              'modeList': list,
            });
          },
          title: Text(list.name),
        )
      );
    }).toList();
  }

}


