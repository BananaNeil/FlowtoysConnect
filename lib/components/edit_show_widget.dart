import 'package:flutter_reorderable_list/flutter_reorderable_list.dart';
import 'package:app/components/reordable_list_simple.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:app/models/timeline_element.dart';
import 'package:app/helpers/duration_helper.dart';
import 'package:app/components/mode_widget.dart';
import 'package:app/components/show_widget.dart';
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
  EditShowWidget({
    Key key,
    this.bpm,
    this.show,
    this.modes,
    this.onSave,
    this.canEditShowDuration,
    this.onlyShowCycleGeneration,
  }) : super(key: key);
  bool onlyShowCycleGeneration = false;
  bool canEditShowDuration;
  List<Mode> modes;
  Function onSave;
  Show show;
  double bpm;


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

  void onSave(show) {
    if (widget.onSave != null) widget.onSave(show);
  }


  String bpmError;
  bool useBPM = false;
  double modeDurationInput;
  bool get onlyShowCycleGeneration => widget.onlyShowCycleGeneration ?? false;
  double get durationInputToFill => 1 / modes.length;
  double get acceleratedModeDurationInput => modeDurationInput;
  double get modifiedModeDurationInput => acceleratedModeDurationInput - (acceleratedModeDurationInput % 0.005);
  int get chosenBeatsPerMode => max(1, (modeDurationInput * 20).floor());
  double get chosenCycleCount => max(1/modes.length, (modeDurationInput * 20 * 20).floor()/20);
  double get modeDurationRatio => (modifiedModeDurationInput * (1 - minModeDurationRatio)) + minModeDurationRatio;
  Duration get modeDurationForSingleCycle => divideDuration(show.duration, modes.length);
  double get cycleCount => exactModeCount / modes.length;

  Duration get minModeDuration => Duration(milliseconds: 500);
  double get minModeDurationRatio => (minModeDuration.inMicroseconds / show.duration.inMicroseconds);

  Duration _maximumDuration;
  Duration get maximumDuration => _maximumDuration ??= maxDuration(show.duration * 2, Duration(minutes: 10));

  List<Mode> get modes => widget.modes ?? [];

  Duration _futureDuration;

  Duration get modeDuration {
    if (!useBPM) {
      if (modes.length == 0)
        return show.duration; 
      else return show.duration * (1 / (chosenCycleCount * modes.length)); 
      // return show.duration * modeDurationRatio;
    }

    var beatsPerMinute;
    if (onlyShowCycleGeneration)
      beatsPerMinute = widget.bpm;
    else beatsPerMinute = show.audioElements.first.object.bpm;

    return Duration(milliseconds: (1000 * chosenBeatsPerMode / (beatsPerMinute / 60)).floor());
  }
  int get totalModeCount => exactModeCount.ceil();
  double get exactModeCount => modes.length == 0 ? 0 : (show.duration.inMicroseconds / modeDuration.inMicroseconds);
  Duration get lastModeDuration => Duration(microseconds: show.duration.inMicroseconds - ((totalModeCount-1) * modeDuration.inMicroseconds));

  @override initState() {
    super.initState();
     modeDurationInput = onlyShowCycleGeneration ? durationInputToFill : 0.5;
    loadSongs();
  }

  bool _isSaving = false;
  void _saveAndFinish() {
    if (onlyShowCycleGeneration) {
      show.generateTimeline(modes, modeDuration);
      Navigator.pop(context, show);
    }

    var isNewShow = !show.isPersisted;
    if ((show.name ?? '').isEmpty) return;

    setState(() => errorMessage = null);
    if (isNewShow)
      show.generateTimeline(modes, modeDuration);

    setState(() => _isSaving = true);
    show.save().then((response) {
      _isSaving = false;
      if (response['success']) {
        onSave(response['show']);
        setState(() {
          show = response['show'];
        });
      } else setState(() => errorMessage = response['message']);

      if (isNewShow)
        Navigator.pushReplacementNamed(context, "/shows/${show.id}", arguments: {
          'messageColor': Colors.red,
          'message': errorMessage,
          'show': show,
        });
      else Navigator.pop(context, null);
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
        if (response['success'])
          if (response['song'].status == 'failed')
            song.status = 'failed';
          else {
            song.assignAttributesFromCopy(response['song']);
            // song.id = response['song'].id;
            // song.filePath = response['song'].filePath;
            setState(() {});
            song.downloadFile().then((_) {
              setState(() {
                waveforms[song.id ?? song.hashCode.toString()] = WaveformController.open(song.localPath);
              });
            });
            if (show.isPersisted) show.save();
          }
        else setState(() => errorMessage = response['message']); 
      });
    }
  }

  Future<dynamic> loadSongs() {
    return show?.downloadSongs().then((_) {
      setState(() {
        show.audioElements.forEach((element) {
          if (element.object != null)
            waveforms[element.objectId] = WaveformController.open(element.object.localPath);
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (show == null) return Container();
    if (show.audioElements.isNotEmpty) bpmError = null;
    return GestureDetector(
      onTap: AppController.closeKeyboard,
      child: SingleChildScrollView(
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
                    // Add a spinner here!!
                    child: _isSaving ? SpinKitCircle(color: Colors.blue, size: 24) : Text('SAVE',
                      style: TextStyle(
                        color: (show.name ?? '').isEmpty && !onlyShowCycleGeneration ? Colors.grey : Colors.blue,
                      )
                    ),
                  ),
                )
              ],
            ),
            Visibility(
              visible: !onlyShowCycleGeneration,
              child: Container(
                padding: EdgeInsets.only(left: 20, right: 20, bottom: 10),
                child: TextFormField(
                  initialValue: show.name,
                  textCapitalization: TextCapitalization.sentences,
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
            ),
            ..._SongsListWidgets,
            Visibility(
              visible: !onlyShowCycleGeneration,
              child: Container(
                margin: EdgeInsets.only(top: 20, bottom: 10),
                child: Text("Timeline Preview",
                  style: TextStyle(
                    fontSize: 22,
                  )
                )
              )
            ),
            show.isPersisted || modes.length == 0 ? Container() : Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  margin: EdgeInsets.only(left: 20, top: 0, bottom: 5),
                  child: Text("Generate Mode Sequence:",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFBBBBBB),
                      fontSize: 15,
                    ),
                  )
                ),
                Visibility(
                  visible: bpmError != null,
                  child: Text(bpmError ?? "", style: TextStyle(color: Colors.red)),
                ),
                Visibility(
                  visible: !onlyShowCycleGeneration || widget.bpm != null,
                  child: Container(
                    margin: EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(color: Color(0x22FFFFFF)),
                    child: ToggleButtons(
                      isSelected: [!useBPM, useBPM],
                      onPressed: (int index) {
                        if (index == 1 && !onlyShowCycleGeneration)
                          if (show.audioElements.isEmpty)
                            return setState(() => bpmError = "You must add an audio element to use BPM matching.");
                          else if (show.audioElements.first.object?.bpm == null)
                            return setState(() => bpmError = "Wait a moment, we are anazlying to song to determine the BPM");
                        bpmError = null;
                        useBPM = !useBPM;
                        setState(() {});
                      },
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text("By Duration"),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text("Match Audio BPM"),
                        ),
                      ]
                    ),
                  ),
                ),
                Align(
                  alignment: FractionalOffset.topLeft,
                  child: Container(
                    margin: EdgeInsets.only(left: 20, top: 20),
                    child: Text("Mode Durartion: ${twoDigitString(modeDuration, includeMilliseconds: true)}",
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: Color(0xFFBBBBBB),
                        fontSize: 13,
                      ),
                    )
                  ),
                ),
                 !useBPM ? Container() : Align(
                  alignment: FractionalOffset.topLeft,
                  child: Container(
                    margin: EdgeInsets.only(left: 20, top: 20),
                    child: Text("Change Mode Every ${chosenBeatsPerMode} Beats",
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: Color(0xFFBBBBBB),
                        fontSize: 13,
                      ),
                    )
                  ),
                ),
                Align(
                  alignment: FractionalOffset.topLeft,
                  child: Container(
                    margin: EdgeInsets.only(left: 20, top: 5),
                    child: Text(
                        "Cycle Count: ${cycleCount.toStringAsFixed(2)}",
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: Color(0xFFBBBBBB),
                        fontSize: 13,
                      ),
                    )
                  ),
                ),
                Align(
                  alignment: FractionalOffset.topLeft,
                  child: Slider(
                    value: modeDurationInput,
                    onChanged: (value){
                      setState(() {
                        modeDurationInput = value;
                      });
                    }
                  )
                ),
              ]
            ),
            Container(
              height: 50,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0x44FFFFFF)),
                  bottom: BorderSide(color: Colors.white),
                  right: BorderSide(color: Colors.white),
                  left: BorderSide(color: Colors.white),
                )
              ),
              margin: EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox.expand(
                child: show.isPersisted ? ShowPreview(show: show) : Row(
                  children: List<Widget>.generate(totalModeCount, (index) {
                    var element = modes[index % modes.length];
                    return Flexible(
                      flex: (index == totalModeCount - 1) ? lastModeDuration.inMicroseconds : modeDuration.inMicroseconds,
                      child: Container(
                        child: modes.isEmpty ? Container() : ModeColumn(mode: element, showImages: true),
                      )
                    );
                  }).toList(),
                )
              )
            ),
            _AudioPreview(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("00:00"),
                Text(twoDigitString(show.duration)),
              ]
            ),
            Visibility(
              visible: !show.isPersisted,
              child: GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/modes',
                    arguments: {
                      'selectedModes': widget.modes,
                      'canChangeCurrentList': true,
                      'selectAction': "Save",
                      'isSelecting': true,
                    }
                  ).then((_modes) {
                    if (_modes != null) {
                      widget.modes = List<Mode>.from(_modes);
                      setState(() {});
                    }
                  });
                },
                child: Text("Edit Modes (${modes.length})", style: TextStyle(color: Colors.blue)),
              )
            ),
            Visibility(
              visible: widget.canEditShowDuration == true,
              child: Column(
                children: [
                  Align(
                    alignment: FractionalOffset.topLeft,
                    child: Container(
                      margin: EdgeInsets.only(left: 20, top: 20),
                      child: Text("Total Duration: ${twoDigitString(_futureDuration ?? show.duration, includeMilliseconds: true)}",
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          color: Color(0xFFBBBBBB),
                          fontSize: 13,
                        ),
                      )
                    ),
                  ),
                  Align(
                    alignment: FractionalOffset.topLeft,
                    child: Slider(
                      value: durationRatio(_futureDuration ?? show.duration, maximumDuration),
                      onChangeEnd: (value) {
                        setState(() {
                          // show.duration = Duration(minutes: 12) * value;
                          show.setDuration(_futureDuration);
                        });
                      },
                      onChanged: (value){
                        setState(() {
                          _futureDuration = maxDuration(Duration(seconds: 10), maximumDuration * value);
                          // if (show.audioIsEmpty)
                            show.setDuration(_futureDuration);
                        });
                        // setState(() {
                        // //   // show.duration = Duration(minutes: 12) * value;
                        // });
                      }
                    )
                  ),
                ]
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _AudioPreview() {
    if (onlyShowCycleGeneration || show.audioIsEmpty) return Container(height: 0);
    var visibleElements = show.audioElements.where((el) => el.startOffset < show.duration).toList();
    if (visibleElements.last.endOffset < show.duration)
      visibleElements.add(TimelineElement(
        duration: show.duration - visibleElements.last.endOffset,
      ));
    return Container(
      height: 50,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white),
          right: BorderSide(color: Colors.white),
          left: BorderSide(color: Colors.white),
        )
      ),
      margin: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: mapWithIndex(visibleElements, (index, element) {
          var waveform = waveforms[element.object?.id ?? element.object.hashCode.toString()];
          var color = [Colors.blue, Colors.red][index % 2];
          var visibleDuration = minDuration(show.duration, element.endOffset) - element.startOffset;
          return Flexible(
            flex: (durationRatio(visibleDuration, show.duration).clamp(0.0, 1.0) * 20000.0).ceil(),
            child: Waveform(
              scale: durationRatio(visibleDuration, show.duration),
              // // why is this not working ?
              // futureScale: durationRatio(_futureDuration ?? show.duration, show.duration) * durationRatio(visibleDuration, show.duration),
              startOffset: element.contentOffset,
              visibleDuration: visibleDuration,
              controller: waveform,
              song: element.object,
              color: color,
            )
          );
        }).toList()
      )
    );
  }

  Widget _SongCard(element) {
    var elementName = element.object == null ? "${twoDigitString(element.duration)} of empty space" : "\"${element.object?.name}\"";
    return Card(
      elevation: 8.0,
      child: ListTile(
        trailing: GestureDetector(
          onTap: () {
            AppController.openDialog("Are you sure?", "This will remove ${elementName} from this show.",
              buttonText: 'Cancel',
              buttons: [{
                'text': 'Remove',
                'color': Colors.red,
                'onPressed': () {
                  setState(() {
                    show.removeAudioElement(element);
                    if (show.isPersisted) show.save();
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
                children: [
                  element.object?.thumbnailUrl == null ? Container() : Container(
                    height: 40,
                    width: 70,
                    margin: EdgeInsets.only(bottom: 2),
                    decoration: BoxDecoration(
                      color: Colors.black,
                    ),
                    child: Image.network(element.object?.thumbnailUrl),
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
                    child: Text(element.object?.name ?? "Empty Space", style: TextStyle(fontSize: 14))
                  ),
                  element.object?.status == 'failed' ? Text("Failed! Something went wrong...", style: TextStyle(color: Colors.red, fontSize: 14))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(element.durationString, style: TextStyle(fontSize: 11)),
                        element.object == null ? Container() :
                          element.object.bpm == null ? SpinKitCircle(color: Colors.white, size: 12) :
                            Text("${element.object.bpm.round()} BPM", style: TextStyle(fontSize: 11)),
                      ]
                  )
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

  List<Widget> get _SongsListWidgets {
    if (onlyShowCycleGeneration) return [];
    return [
      Container(
        margin: EdgeInsets.only(top: 20, bottom: 10),
        child: Text("Audio",
          style: TextStyle(
            fontSize: 22,
          )
        )
      ),
      // Flexible(
      //   child:
      ReorderableListSimple(
          allowReordering: true,
          childrenAlreadyHaveListener: true,
          onReorder: (int start, int current) {
            var elements = show.audioElements;
            var element = elements[start];
            elements.remove(element);
            elements.insert(min(elements.length, current), element);
            elements.asMap().forEach((index, other) {
              other.position = index + 1;
            });
            if (show.isPersisted) show.save();
            setState((){});
          },
          children: show.audioIsEmpty ? [] : [
            ...show.audioElements.map((element) {
              return _SongCard(element);
            }),
          ],
        ),
      // ),
      GestureDetector(
        onTap: () {
          Navigator.pushNamed(context, '/songs/new').then(_addNewSong);
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("+ Add a song", style: TextStyle(color: Colors.blue))
          ]
        ),
      )
    ];
  }

}

