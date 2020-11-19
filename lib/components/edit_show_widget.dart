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
    var isNewShow = !show.isPersisted;
    if ((show.name ?? '').isEmpty) return;

    setState(() => errorMessage = null);
    show.save(modeDuration: modeDuration).then((response) {
      if (response['success']) {
        setState(() {
          show = response['show'];
          if (isNewShow)
            Navigator.pushReplacementNamed(context, "/shows/${show.id}", arguments: {'show': show});
          else Navigator.pop(context, null);
        });
      } else setState(() => errorMessage = response['message']);
    });
  }

  void _addNewSong(obj) {
    var element;
    Song song = obj;

    if (song != null) {
      setState(() {
        element = show.addAudioElement(song);
      });
      song.save().then((response) {
        if (response['success'] && response['song'].status == 'failed')
          song.status = 'failed';
        else {
          song.id = response['song'].id;
          song.filePath = response['song'].filePath;
          element.save().then((response) {
            element = response['timelineElement'] ?? element;
            setState(() {});
            song.downloadFile().then((_) {
              setState(() {
                waveforms[element.id ?? element.hashCode.toString()] = WaveformController.open(song.localPath);
              });
            });
          });
        }
      });
    }
  }

  Future<dynamic> loadSongs() {
    return show.downloadSongs().then((_) {
      setState(() {
        show.songElements.forEach((element) {
          waveforms[element.id ?? element.hashCode.toString()] = WaveformController.open(element.object.localPath);
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
                  children: show.isPersisted ? mapWithIndex(show.modeElements, (index, element) {
                    return Flexible(
                      flex: element.duration.inMilliseconds,
                      child: Container(
                        child: ModeColumn(mode: element.object, showImages: true),
                      )
                    );
                  }).toList() : List<Widget>.generate(totalModeCount, (index) {
                    var element = show.modeElements[index % show.modeElements.length];
                    return Flexible(
                      flex: (index == totalModeCount - 1) ? lastModeDuration.inMicroseconds : modeDuration.inMicroseconds,
                      child: Container(
                        child: show.modeElements.isEmpty ? Container() : ModeColumn(mode: element.object, showImages: true),
                      )
                    );
                  }).toList(),
                )
              )
            ),
            Container(
              height: show.songElements.isEmpty ? 0 : 50,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white),
                  right: BorderSide(color: Colors.white),
                  left: BorderSide(color: Colors.white),
                )
              ),
              margin: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: mapWithIndex(show.songElements, (index, element) {
                  var waveform = waveforms[element.id ?? element.hashCode.toString()];
                  var color = [Colors.blue, Colors.red][index % 2];
                  return Flexible(
                    flex: ((element.duration.inMilliseconds / show.duration.inMilliseconds).clamp(0.0, 1.0) * 1000.0).ceil(),
                    child: Waveform(
                      controller: waveform,
                      song: element.object,
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
                  var elements = show.songElements;
                  var element = elements[start];
                  elements.remove(element);
                  elements.insert(min(elements.length, current), element);
                  elements.asMap().forEach((index, other) {
                    other.position = index + 1;
                    other.save();
                  });
                  if (show.isPersisted) show.save();
                  setState((){});
                },
                children: [
                  ...show.songElements.map((element) {
                    return _SongCard(element);
                  }),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/songs/new').then(_addNewSong);
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

  Widget _SongCard(element) {
    return Card(
      elevation: 8.0,
      child: ListTile(
        trailing: GestureDetector(
          onTap: () {
            AppController.openDialog("Are you sure?", "This will remove \"${element.object.name}\" from this show.",
              buttonText: 'Cancel',
              buttons: [{
                'text': 'Remove',
                'color': Colors.red,
                'onPressed': () {
                  setState(() {
                    show.timelineElements.remove(element);
                    Client.removeTimelineElement(element);
                  });
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
                children: element.object.thumbnailUrl == null ? [] : [
                  Container(
                    height: 40,
                    margin: EdgeInsets.only(bottom: 2),
                    child: Image.network(element.object.thumbnailUrl),
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
                    child: Text(element.object.name, style: TextStyle(fontSize: 14))
                  ),
                  element.object.status == 'failed' ? Text("Failed! Something went wrong...", style: TextStyle(color: Colors.red, fontSize: 14))
                  : Text(element.object.durationString, style: TextStyle(fontSize: 11)),
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

