import 'package:flutter_reorderable_list/flutter_reorderable_list.dart';
import 'package:app/components/reordable_list_simple.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:app/helpers/duration_helper.dart';
import 'package:app/models/mode_list.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/models/group.dart';
import 'package:app/models/show.dart';
import 'package:app/models/mode.dart';
import 'package:app/models/song.dart';
import 'package:app/client.dart';
import 'dart:math';

class EditShowWidget extends StatefulWidget {
  EditShowWidget({Key key, this.show, this.modes}) : super(key: key);
  List<Mode> modes;
  Show show;

  @override
  _EditShowWidgetState createState() => _EditShowWidgetState(
    modes: modes,
    show: show,
  );
}

class _EditShowWidgetState extends State<EditShowWidget> {
  _EditShowWidgetState({this.show, this.modes});

  Show show;
  List<Mode> modes;
  String errorMessage;
  int propCount = 4;


  double modeDurationInput = 0.1;
  double get acceleratedModeDurationInput => pow(modeDurationInput, 2);
  double get modeDurationRatio => (acceleratedModeDurationInput * (1 - minModeDurationRatio)) + minModeDurationRatio;

  Duration get minModeDuration => Duration(milliseconds: 500);
  double get minModeDurationRatio => (minModeDuration.inMicroseconds / show.duration.inMicroseconds);

  Duration get modeDuration => Duration(microseconds: (show.duration.inMicroseconds * modeDurationRatio).floor());
  int get totalModeCount => (show.duration.inMicroseconds / modeDuration.inMicroseconds).ceil();
  Duration get lastModeDuration => Duration(microseconds: show.duration.inMicroseconds - ((totalModeCount-1) * modeDuration.inMicroseconds));

  @override initState() {
    show = Show.create();
    super.initState();
  }

  void _saveAndFinish() {
    if ((show.name ?? '').isEmpty) return;
    var isEditing = show.isPersisted;
    show.save().then((response) {
      if (response['success']) {
        setState(() {
          show = response['show'];
        });
      } else setState(() => errorMessage = response['message']);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: AppController.closeKeyboard,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Visibility(
              visible: errorMessage != null,
              child: Text(errorMessage ?? "", textAlign: TextAlign.center, style: TextStyle(color: AppController.red)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  margin: EdgeInsets.only(top: 20, right: 20),
                  child: GestureDetector(
                    onTap: _saveAndFinish,
                    child: Text('SAVE',
                      style: TextStyle(
                        color: (show.name ?? '').isEmpty ? Colors.grey : Colors.blue,
                      )
                    ),
                  ),
                )
              ],
            ),
            Container(
              padding: EdgeInsets.only(left: 20, right: 20, bottom: 10),
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: 'Name your show...',
                ),
                onChanged: (text) {
                  setState(() {
                    show.name = text;
                  });
                }
              )
            ),
            Container(
              margin: EdgeInsets.only(top: 20, bottom: 10),
              child: Text("Timeline Preview",
                style: TextStyle(
                  fontSize: 22,
                )
              )
            ),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: modeDurationInput,
                    onChanged: (value){
                      print("AAAA: ${modeDuration.inMicroseconds}");
                      setState(() {
                        modeDurationInput = value;
                      });
                    }
                  )
                ),
                Text(twoDigitString(modeDuration, includeMilliseconds: true), style: TextStyle(fontSize: 13)),
              ]
            ),
            Container(
              height: 50,
              margin: EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox.expand(
                child: Row(
                  children: List<Widget>.generate(totalModeCount, (index) {
                    return Flexible(
                      flex: (index == totalModeCount - 1) ? lastModeDuration.inMicroseconds : modeDuration.inMicroseconds,
                      child: Container(
                        child: Column(
                          children: List<Widget>.generate(Group.currentProps.length, (ii) {
                            return Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: [Colors.red, Colors.blue, Colors.green, Colors.purple, Colors.yellow][ (index + ii) % 5],
                                )
                              )
                            );
                          })
                        )
                      )
                    );
                  }).toList(),
                )
              )
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("00:00"),
                Text(twoDigitString(show.duration)),
              ]
            ),
            Container(
              margin: EdgeInsets.only(top: 20, bottom: 10),
              child: Text("Songs",
                style: TextStyle(
                  fontSize: 22,
                )
              )
            ),
            Flexible(
              child: ReorderableListSimple(
                allowReordering: true,
                childrenAlreadyHaveListener: true,
                onReorder: (int start, int current) {
                  var song = show.songs[start];
                  show.songs.remove(song);
                  show.songs.insert(min(show.songs.length, current), song);
                  show.songs.asMap().forEach((index, other) => other.position = index + 1);
                  if (show.isPersisted) show.save();
                },
                children: [
                  ...show.songs.map((song) {
                    return _SongCard(song);
                  }),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/songs/new').then((obj) {
                  Song song = obj;
                  setState(() {
                    if (song != null) {
                      show.songs.add(song);
                      song.save().then((response) {
                        if (response['success'] && response['song'].status == 'failed')
                          song.status = 'failed';
                      });
                    }
                  });
                });
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("+ Add a song")
                ]
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _SongCard(song) {
    return Card(
      elevation: 8.0,
      child: ListTile(
        trailing: GestureDetector(
          onTap: () {
            AppController.openDialog("Are you sure?", "This will remove \"${song.name}\" from this show.",
              buttonText: 'Cancel',
              buttons: [{
                'text': 'Remove',
                'color': Colors.red,
                'onPressed': () {
                  setState(() => show.songs.remove(song));
                  if (show.isPersisted) show.save();
                },
              }]
            );
          },
          child: Icon(Icons.delete_forever, color: AppController.red),
        ),
        title: Row(
          children: [
            ReorderableListener(
              child: Container(
                padding: EdgeInsets.only(right: 10),
                child: Icon(Icons.drag_indicator),
              )
            ),
            Container(
              margin: EdgeInsets.only(right: 10, top: 2, bottom: 2),
              child: Column(
                children: [
                  Container(
                    height: 40,
                    margin: EdgeInsets.only(bottom: 2),
                    child: Image.network(song.thumbnailUrl),
                  ),
                ]
              )
            ),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: EdgeInsets.only(bottom: 2),
                    child: Text(song.name, style: TextStyle(fontSize: 14))
                  ),
                  song.status == 'failed' ? Text("Failed! Something went wrong...", style: TextStyle(color: Colors.red, fontSize: 14))
                  : Text(song.durationString, style: TextStyle(fontSize: 11)),
                ]
              )
            )
          ]
        ),
        onTap: () {
        },
      )
    );
  }

}

