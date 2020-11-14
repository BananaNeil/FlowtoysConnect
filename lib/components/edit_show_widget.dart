import 'package:flutter_reorderable_list/flutter_reorderable_list.dart';
import 'package:app/components/reordable_list_simple.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:app/helpers/duration_helper.dart';
import 'package:app/components/mode_widget.dart';
import 'package:app/components/waveform.dart';
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
  EditShowWidget({Key key, this.show}) : super(key: key);
  Show show;

  @override
  _EditShowWidgetState createState() => _EditShowWidgetState(
    show: show,
  );
}

class _EditShowWidgetState extends State<EditShowWidget> {
  _EditShowWidgetState({this.show});

  Show show;
  String errorMessage;
  Map<String, WaveformController> waveforms = {};


  double modeDurationInput = 0.1;
  double get acceleratedModeDurationInput => pow(modeDurationInput, 2);
  double get modeDurationRatio => (acceleratedModeDurationInput * (1 - minModeDurationRatio)) + minModeDurationRatio;

  Duration get minModeDuration => Duration(milliseconds: 500);
  double get minModeDurationRatio => (minModeDuration.inMicroseconds / show.duration.inMicroseconds);

  Duration get modeDuration => Duration(microseconds: (show.duration.inMicroseconds * modeDurationRatio).floor());
  int get totalModeCount => (show.duration.inMicroseconds / modeDuration.inMicroseconds).ceil();
  Duration get lastModeDuration => Duration(microseconds: show.duration.inMicroseconds - ((totalModeCount-1) * modeDuration.inMicroseconds));

  @override initState() {
    super.initState();
    loadSongs();
  }

  void _saveAndFinish() {
    if ((show.name ?? '').isEmpty) return;

    setState(() => errorMessage = null);
    show.save(modeDuration: modeDuration).then((response) {
      if (response['success']) {
        setState(() {
          show = response['show'];
          Navigator.pushReplacementNamed(context, "/shows/${show.id}", arguments: {'show': show});
        });
      } else setState(() => errorMessage = response['message']);
    });
  }

  Future<dynamic> loadSongs() {
    return show.downloadSongs().then((_) {
      setState(() {
        show.songs.forEach((song) {
          waveforms[song.id.toString()] = WaveformController.open(song.localPath);
        });
      });
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
                initialValue: show.name,
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
            show.isPersisted ? Container() : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    margin: EdgeInsets.only(left: 20, top: 20),
                  child: Text("Initial Mode Duration",
                    style: TextStyle(
                      color: Color(0xFFBBBBBB),
                      fontSize: 13,
                    ),
                  )
                ),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: modeDurationInput,
                        onChanged: (value){
                          setState(() {
                            modeDurationInput = value;
                          });
                        }
                      )
                    ),
                    Text(twoDigitString(modeDuration, includeMilliseconds: true), style: TextStyle(fontSize: 13)),
                  ]
                ),
              ]
            ),
            Container(
              height: 50,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white),
                  right: BorderSide(color: Colors.white),
                  left: BorderSide(color: Colors.white),
                )
              ),
              margin: EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox.expand(
                child: Row(
                  children: show.isPersisted ? mapWithIndex(show.modes, (index, mode) {
                    return Flexible(
                      flex: mode.duration.inMilliseconds,
                      child: Container(
                        // decoration: BoxDecoration(
                        //   color: [Colors.red, Colors.blue][index %2],
                        // ),
                        child: ModeColumn(mode: mode, showImages: true),
                      )
                    );
                  }).toList() : List<Widget>.generate(totalModeCount, (index) {
                    return Flexible(
                      flex: (index == totalModeCount - 1) ? lastModeDuration.inMicroseconds : modeDuration.inMicroseconds,
                      child: Container(
                        child: show.modes.isEmpty ? Container() : ModeColumn(mode: show.modes[index % show.modes.length], showImages: true),
                      )
                    );
                  }).toList(),
                )
              )
            ),
            Container(
              height: show.songs.isEmpty ? 0 : 50,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white),
                  right: BorderSide(color: Colors.white),
                  left: BorderSide(color: Colors.white),
                )
              ),
              margin: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: show.songs.map((song) {
                  var waveform = waveforms[song.id.toString()];
                  var color = [Colors.blue, Colors.red][waveforms.values.toList().indexOf(waveform) % 2];
                  return Flexible(
                    flex: ((song.duration.inMilliseconds / show.duration.inMilliseconds).clamp(0.0, 1.0) * 1000.0).ceil(),
                    child: waveform == null ? SpinKitCircle(color: color, size: 30) :
                      Waveform(
                        controller: waveform,
                        color: color,
                      )
                  );
                }).toList()
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
                  setState((){});
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
                        else {
                          song.id = response['song'].id;
                          song.filePath = response['song'].filePath;
                          song.downloadFile().then((_) {
                            setState(() {
                              waveforms[song.id.toString()] = WaveformController.open(song.localPath);
                            });
                          });
                        }
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
                  setState(() {
                    show.songs.remove(song);
                  });
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
                children: song.thumbnailUrl == null ? [] : [
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

