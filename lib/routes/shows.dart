import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:app/components/action_button.dart';
import 'package:app/components/mode_widget.dart';
import 'package:app/app_controller.dart';
import 'package:filesize/filesize.dart';
import 'package:flutter/material.dart';
import 'package:app/models/show.dart';
import 'package:app/client.dart';
import 'dart:math';

class Shows extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ShowsPage(title: 'Shows');
  }
}

class ShowsPage extends StatefulWidget {
  ShowsPage({Key key, this.title}) : super(key: key);
  String title;

  @override
  _ShowsPageState createState() => _ShowsPageState();
}

class _ShowsPageState extends State<ShowsPage> {

  bool awaitingResponse = false;
  bool isSelecting = false;
  List<Show> selected = [];
  List<Show> shows = [];
  bool isTopLevelRoute;
  String errorMessage;

  // Future<void> _deleteShow(show) {
  //   return Client.deleteShow(show.id);
  // }

  Future<void> fetchShows() {
    setState(() {
      errorMessage = null;
      awaitingResponse = true;
    });
    return Client.getShows().then((response) {
      setState(() {
        awaitingResponse = false;
        if (!response['success'])
          setState(() => errorMessage = response['message'] );
        else shows = response['shows'];
      });
    });
  }

  @override initState() {
    isTopLevelRoute = !Navigator.canPop(context);
    super.initState();
    fetchShows();
  }


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: AppController.closeKeyboard,
      child: Scaffold(
        floatingActionButton: isSelecting ? _SelectionButtons : null,
        backgroundColor: AppController.darkGrey,
        drawer: isTopLevelRoute ? AppController.drawer() : null,
        appBar: AppBar(
          title: Text("My Shows"),
          backgroundColor: Color(0xff222222),
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () {
                isSelecting = true;
                setState(() {});
              }
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: RefreshIndicator(
                  onRefresh: fetchShows,
                  child: ListView(
                    padding: EdgeInsets.only(top: 5),
                    children: [
                      ..._Shows(),
                      Container(
                        margin: EdgeInsets.all(5),
                        child: GestureDetector(
                          child: Text("CREATE A NEW SHOW", textAlign: TextAlign.center, style: TextStyle(color: AppController.blue)),
                          onTap: () {
                            Navigator.pushNamed(context, '/modes', arguments: {'isSelecting': true, 'selectAction': 'Create Show'}).then((modes) {
                              if (modes != null)
                                Navigator.pushNamed(context, '/shows/new', arguments: {'modes': modes}).then((_) {
                                  fetchShows();
                                });
                            });
                          }
                        )
                      ),
                    ]
                  ),
                ),
              )
            ],
          ),
        ),
      )
    );
  }

  List<Widget> _Shows() {
    if (errorMessage != null)
      return [Text(errorMessage, textAlign: TextAlign.center, style: TextStyle(color: AppController.red))];
    else if (shows.length == 0)
      return [
        Container(
          margin: EdgeInsets.only(top: 20, bottom: 20),
          child: awaitingResponse ?
            SpinKitCircle(color: AppController.blue) :
            Column(
              children: [
                Text("You have not created any shows yet!", textAlign: TextAlign.center),
              ]
            )
        ),
      ];
    else return shows.map((show) {
      return Card(
        elevation: 8.0,
        child: ListTile(
          trailing: Icon(Icons.arrow_forward),
          onTap: () {
            Navigator.pushNamed(context, "/shows/${show.id}", arguments: {
              'show': show,
            }).then((_) => setState(() {}));
          },
          title: Container(
            margin: EdgeInsets.only(bottom: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 25,
                      margin: EdgeInsets.only(right: 10),
                      child: show.audioDownloadedPending ? SpinKitCircle(color: Colors.white, size: 20) :
                        (show.audioDownloaded ? 
                          Icon(Icons.cloud_done, color: Color(0xFFffB0EEB0)) : Icon(Icons.cloud_download)
                        ),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(child: Text(show.name), margin: EdgeInsets.only(right: 6)),
                          // Don't forget to remove this minimum byte size after you figure out show json size
                          Text("${show.durationString}  -  (${filesize(max(1500, show.audioByteSize))})", style: TextStyle(
                            fontSize: 12,
                          )),
                        ]
                      )
                    )
                  ]
                ),
                ...show.audioElements.map((element) {
                  return Row(
                    children: [
                      // element.object
                      // Text(element.object.name),
                      Flexible(
                        child: Container(
                          margin: EdgeInsets.only(top: 5),
                          child: Text( "(${element.durationString}) - ${element.object.name}",
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppController.purple,
                              fontSize: 13,
                            )
                          )
                        )
                      ),
                    ]
                  );
                }).toList(),
              ]
            )
          )
        )
      );
    }).toList();
  }

  Widget get _SelectionButtons {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ActionButton(
          visible: selected.length < shows.length,
          text: "Select All",
          rightMargin: 25.0,
          onPressed: () {
            setState(() => selected = shows);
          },
        ),
        ActionButton(
          visible: selected.length > 0,
          text: "Remove (${selected.length})",
          rightMargin: 25.0,
          onPressed: () {
            if (selected.length > 0)
              AppController.openDialog("Are you sure?", "This will remove ${selected.length} modes from this list along with any customizations made to them.",
                buttonText: 'Cancel',
                buttons: [{
                  'text': 'Delete',
                  'color': Colors.red,
                  'onPressed': () {
                    // selected.forEach((mode) => _removeMode(mode));
                    selected = [];
                  },
                }]
              );
          },
        ),
        ActionButton(
          visible: selected.length > 0,
          text: "Duplicate (${selected.length})",
          rightMargin: 25.0,
          onPressed: _duplicateSelected,
        ),
        ActionButton(
          visible: selected.length > 0,
          text: "Deselect All",
          rightMargin: 25.0,
          onPressed: () {
            setState(() => selected = []);
          },
        ),
        Container(
          margin: EdgeInsets.only(top: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ActionButton(
                margin: EdgeInsets.only(bottom: 0),
                text: "Save (${selected.length}) to list",
                onPressed: () {
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
                      selected = [];
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

  void _duplicateSelected() {
  }

}



