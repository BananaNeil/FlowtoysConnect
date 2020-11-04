import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/models/show.dart';
import 'package:app/client.dart';

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
        backgroundColor: AppController.darkGrey,
        drawer: isTopLevelRoute ? AppController.drawer() : null,
        appBar: AppBar(
          title: Text("My Shows"),
          backgroundColor: Color(0xff222222),
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
                                Navigator.pushNamed(context, '/shows/new', arguments: {'modes': modes});
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
            });
          },
          title: Text(show.name ?? 'null'),
        )
      );
    }).toList();
  }

}



