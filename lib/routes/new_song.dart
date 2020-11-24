import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:app/helpers/duration_helper.dart';
import 'package:icon_shadow/icon_shadow.dart';
import 'package:youtube_api/youtube_api.dart';
import 'package:app/models/mode_list.dart';
import 'package:app/app_controller.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:app/models/song.dart';
import 'package:app/models/show.dart';
import 'package:app/models/mode.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';

class NewSong extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return NewSongPage(title: 'NewSong');
  }
}

class NewSongPage extends StatefulWidget {
  NewSongPage({Key key, this.title}) : super(key: key);
  String title;

  @override
  _NewSongPageState createState() => _NewSongPageState();
}

class _NewSongPageState extends State<NewSongPage> {

  Song song;
  List<Mode> modes;
  String searchText;
  String previewUrl;
  String errorMessage;
  Timer updateSearchTimer;
  List<YT_API> videos = [];
  bool loadingPreview = false;
  bool waitingForYoutube = false;

  @override initState() {
    song = Song.fromMap({});
    super.initState();
  }

  @override dispose() {
    super.dispose();
  }

  Future<List<YT_API>> searchYoutube(query) {
    setState(() {
      videos = [];
      waitingForYoutube = true;
    });
    var key = AppController.config['youtube_key'];
    YoutubeAPI api = new YoutubeAPI(key);

    RegExp urlRegex = RegExp(r'.*(?:youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=)([^#\&\?]*).*');
    String urlId = urlRegex.firstMatch(query)?.group(1);
    if (urlId != null)
      return getVideoFromId(urlId);
    else return api.search(query, type: 'video');
  }

  Future<List<YT_API>> getVideoFromId(id) {
    Uri url = Uri.https("www.googleapis.com", "youtube/v3/videos", {
      'key': AppController.config['youtube_key'],
      'part': 'snippet,contentDetails',
      'id': id,
    });
    try {
      return http.get(url, headers: {"Accept": "application/json"}).timeout(Duration(seconds: 14),
        onTimeout: () {
          print("youtube ON TIMEOUT...........");
        }).then((res) {
        var jsonData = json.decode(res.body);
        if (jsonData == null) return [];
        return jsonData['items'].map<YT_API>((item) {
          var video = YT_API(item, getTrendingVideo: true);
          video.duration = getDuration(YT_VIDEO(item).duration);
          return video;
        }).toList();
      });
    } on TimeoutException catch (_) {
      print("youtube TIMEOUT EXCEPTION ===========================================");
    } on SocketException catch (_) {
      print("youtube SOCKET EXCEPTION ===========================================");
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: AppController.closeKeyboard,
      child: Scaffold(
        appBar: AppBar(
          title: Text("New Song"),
          backgroundColor: Color(0xff222222),
          leading: new IconButton(
            icon: new Icon(Icons.close),
            onPressed: () {
              Navigator.pop(context, null);
            },
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Visibility(
                visible: errorMessage != null,
                child: Container(
                  margin: EdgeInsets.only(top: 10),
                  child: Text(errorMessage ?? "",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppController.red)
                  ),
                )
              ),
              Container(
                margin: EdgeInsets.only(top: 50, bottom: 10),
                child: Text("Search the web for a song",
                  style: TextStyle(
                    fontSize: 22,
                  )
                )
              ),
              Container(
                padding: EdgeInsets.only(left: 20, right: 20, bottom: 10),
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Search any artist, song, or paste a youtube url',
                  ),
                  onChanged: (text) {
                    updateSearchTimer?.cancel();
                    updateSearchTimer = Timer(Duration(milliseconds: 300), () {
                      searchText = text;
                      searchYoutube(text).then((response) {
                        if (searchText == text)
                          setState(() {
                            videos = response.where((video) {
                              return !video.duration.isEmpty;
                            }).toList();
                            waitingForYoutube = false;
                            AppController.closeKeyboard();
                          });
                      });
                    });
                  }
                )
              ),
              waitingForYoutube ? SpinKitCircle(color: AppController.blue) : 
              Visibility(
                visible: videos.length > 0,
                child: Expanded(
                  child: ListView(
                    children: videos.where((video) => !video.duration.isEmpty).map((video) {
                      var song = Song(
                        thumbnailUrl: video.thumbnail['default']['url'],
                        name: (new HtmlUnescape()).convert(video.title),
                        duration: parseDuration(video.duration ?? "0:0"),
                        youtubeUrl: video.url,
                        status: 'created',
                      );

                      return Card(
                        elevation: 8.0,
                        child: ListTile(
                          leading: GestureDetector(
                            onTap: () {
                              setState(() {
                                loadingPreview = true;
                                if (previewUrl == video.url)
                                  previewUrl = null;
                                else previewUrl = video.url;
                              });
                            },
                            child: Container(
                              width: 60,
                              margin: EdgeInsets.symmetric(vertical: 5),
                              child: Stack(
                                children: [
                                  previewUrl == video.url ? 
                                  Container(
                                    child: Visibility(
                                      visible: previewUrl != null,
                                      child: Opacity(
                                        opacity: 0,
                                        child: YoutubePlayer(
                                          controller: YoutubePlayerController(
                                            initialVideoId: video.id,
                                            flags: YoutubePlayerFlags(
                                              autoPlay: true,
                                              mute: false,
                                            ),
                                          ),
                                          onReady: () {
                                            Timer(Duration(milliseconds: 500), () {
                                              setState(() {
                                                loadingPreview = false;
                                              });
                                            });
                                          }
                                        ),
                                      )
                                    )
                                  ) : Container(),
                                  Image.network(song.thumbnailUrl),
                                  previewUrl == video.url && loadingPreview ?
                                    SpinKitCircle(size: 40, color: Colors.white) : Container(),
                                  Positioned.fill(
                                    child: Align(
                                      alignment: Alignment.center,
                                      child: IconShadowWidget(
                                        Icon( previewUrl == video.url ?
                                          Icons.pause_circle_filled : Icons.play_circle_filled,
                                          color: Color(0xEEFFFFFF)),
                                        shadowColor: Colors.black,
                                      )
                                    )
                                  )
                                ]
                              )
                            )
                          ),
                          trailing: Text(song.durationString),
                          title: Text(song.name),
                          onTap: () {
                            Navigator.pop(context, song);
                          },
                        )
                      );

                    }).toList()
                  ),
                )
              ),
            ],
          ),
        ),
      )
    );
  }

}

