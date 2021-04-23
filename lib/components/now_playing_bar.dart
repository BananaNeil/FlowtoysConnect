import 'package:flutter_hsvcolor_picker/flutter_hsvcolor_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:app/helpers/animated_clip_rect.dart';
import 'package:app/helpers/duration_helper.dart';
import 'package:app/components/mode_widget.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/models/group.dart';
import 'package:app/models/prop.dart';
import 'package:app/models/mode.dart';
import 'package:app/client.dart';
import 'dart:async';
import 'dart:math';

class NowPlayingBar extends StatefulWidget {
  NowPlayingBar({
    Key key,
    this.onNext,
    this.shuffle,
    // this.onMenuTap,
    this.onPrevious,
    this.toggleShuffle,
  }) : super(key: key);


  Function onNext;
  Function onPrevious;
  Function toggleShuffle;
  // Function onMenuTap;

  bool shuffle;

  @override
  _NowPlayingBar createState() => _NowPlayingBar();

}


class _NowPlayingBar extends State<NowPlayingBar> with TickerProviderStateMixin {
  _NowPlayingBar();

  bool isPlaying = false;
  Timer cycleDurationChangeTimer; 
  AnimationController isPlayingAnimation;
  Duration cycleDuration = Duration(seconds: 8);

  @override
  initState() {
    super.initState();
  }

  @override
  dispose() {
    cycleDurationChangeTimer?.cancel();
    currentModeSubscription.cancel();
    animationTimer?.cancel();
    super.dispose(); 
  }

  StreamSubscription currentModeSubscription;

  bool waitingForFavorite = false;

  @override
  Widget build(BuildContext context) {
    currentModeSubscription ??= Prop.propUpdateStream.listen((prop) {
      // This is not yet fully working!!!!!!!!!!
      // This is not yet fully working!!!!!!!!!!
      // This is not yet fully working!!!!!!!!!!
      // This is not yet fully working!!!!!!!!!!
      // This is not yet fully working!!!!!!!!!!
      isPlayingAnimation.value = 0.0;
      startAnimationTimer();
      setState(() {});
    });
    return Visibility(
      // visible: Group.connectedProps.length > 0,
      visible: true,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          decoration: BoxDecoration(
            color: Color(0xEa000000),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NowPlayingProgressBar,
              Container(
                margin: EdgeInsets.only(bottom: 10),
                padding: EdgeInsets.only(bottom: AppController.bottomPadding * 0.75),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Prop.current.length == 0 ?  Container() :
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              child: PropImage(prop: firstOrNull(Prop.currentAndOn) ?? Prop.current.first, size: 25),
                              margin: EdgeInsets.only(left: 20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x66FFFFFF),
                                    offset: Offset(0, 0),
                                    spreadRadius: 1.0,
                                    blurRadius: 1.0,
                                  )
                                ]
                              ),
                            )
                          ]
                      ),
                    ),
                    _PlayControlers,
                    Expanded(
                      // width: double.infinity,
                      child: Align(
                        alignment: Alignment.centerRight,
                        // visible: !isShowingMultipleLists,
                        child: Visibility(
                          visible: mode != null,
                          child: GestureDetector(
                            onTap: () {
                              // widget.onMenuTap();
                              Mode newMode = mode.dup();
                              newMode.mergeGlobalParams();
                              waitingForFavorite = true;
                              setState(() {});
                              newMode.save().then((response) {
                                if (response['success'])
                                  Client.updateList('liked-modes', {'append': [response['mode'].id]}).then((response) {
                                    waitingForFavorite = false;
                                    if (response['success'])
                                      mode.wasFavorited = true;
                                    setState(() {});
                                  });
                                else setState(() => waitingForFavorite = false);
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.only(right: AppController.isSmallScreen ? 10 : 25, top: 10),
                              child: waitingForFavorite ? SpinKitCircle(size: 25, color: Colors.white) : Icon(
                                mode?.wasFavorited == true ? Icons.favorite : Icons.favorite_border,
                                color: mode?.wasFavorited == true ? Colors.red : Colors.white,
                              ),
                            ),
                          ),
                        )
                      )
                    ),
                  ]
                )
              ),
            ]
          )
        ),
      )
    );
  }

  Timer animationTimer;
  Widget get _PlayControlers {
    return Column(
      children: [
        Text("Autoplay"),//, style: TextStyle(fontWeight: FontWeight.bold)),
        Container(
          margin: EdgeInsets.all(3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => showModalBottomSheet(
                  builder: (context) => StatefulBuilder(
                    builder: (BuildContext context, setState) => _CycleDurationSliderModal(setState),
                  ),
                  context: context,
                ).then((_) => setState((){})),
                child: Container(
                  margin: EdgeInsets.only(top: 3, right: 15),
                  child: Column(
                    children: [
                      Icon(Icons.av_timer, size: 20),
                      Text("${cycleDuration.inSeconds} sec",style: TextStyle(fontSize: 11)),
                    ]
                  ),
                )
              ),
              GestureDetector(
                onTap: () => onPrevious(),
                child: Icon(Icons.skip_previous, size: 38),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    isPlaying = !isPlaying;
                    if (isPlaying) {
                      startAnimationTimer();
                    } else {
                      animationTimer?.cancel();
                      isPlayingAnimation.stop();
                    }
                  });
                },
                child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, size: 38),
              ),
              GestureDetector(
                onTap: () => onNext(),
                child: Icon(Icons.skip_next, size: 38),
              ),
              Container(
                width: 25,
                margin: EdgeInsets.only(left: 15, top: 2),
                child: GestureDetector(
                  onTap: () => widget.toggleShuffle(),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(widget.shuffle ? Colors.green : Colors.white, BlendMode.srcATop),
                    child: Image(
                      image: AssetImage('assets/images/shuffle.png'),
                    )
                  )
                )
              ),
            ]
          )
        ),
        _ModeTitleAndList(),
      ]
    );
  }

  Widget _CycleDurationSliderModal(setState) {
    return Container(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Choose Mode Duration:", textAlign: TextAlign.left),
                Text(twoDigitString(cycleDuration)),
              ]
            ),
            margin: EdgeInsets.only(bottom: 10),
          ),
          _CycleDurationSlider(setState),
        ]
      ),
      padding: EdgeInsets.only(left: 30, right: 30, top: 20, bottom: 30),
      decoration: BoxDecoration(
        color: Color(0xFF111111)
      ),
    );
  }

  double cycleDurationRatio = 0.2;
  Widget _CycleDurationSlider(setState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(child:
          SliderPicker(
            value: cycleDurationRatio,
            thumbColor: Colors.black,
            height: 25,
            min: 0.0,
            max: 1.0,
            child: Row(
              children: List<int>.generate(24, (int index) => index+1).map((size) {
                return Flexible(
                    flex: size * size,
                    child: Container(
                    height: 30,
                      decoration: BoxDecoration(
                        border: Border(right: BorderSide(color: Colors.grey, width: 1)),
                      ),
                    )
                );
              }).toList()
            ),
            onChanged: (value) {
              cycleDurationRatio = value;
              cycleDuration = Duration(milliseconds: 500 + (Duration(minutes: 1).inMilliseconds * pow(value, 1.2)).toInt());
              cycleDurationChangeTimer?.cancel();
              cycleDurationChangeTimer = Timer(Duration(milliseconds: 200), () {
                isPlayingAnimation.duration = cycleDuration;
              });
              setState((){});
            },
          )
        ),
        // Container(
        //   margin: EdgeInsets.only(left: 5),
        //   child: Text(
        //     twoDigitString(cycleDuration),
        //     style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        //   ),
        // )
      ]
    );
  }

  void startAnimationTimer() {
    animationTimer?.cancel();
    if (isPlaying) {
      animationTimer = Timer(cycleDuration - (cycleDuration * isPlayingAnimation.value), onNext);
      isPlayingAnimation.stop();
      isPlayingAnimation.forward();
    }
  }

  void onPrevious() {
    isPlayingAnimation.value = 0.0;
    startAnimationTimer();
    widget.onPrevious();
  }

  void onNext() {
    print("ON NEXT: ${isPlaying}");
    widget.onNext();
    if (isPlaying) {
      Timer(Duration(milliseconds: 20), () => setState((){})); 
      isPlayingAnimation.value = 0.0;
      startAnimationTimer();
    }
  }

  Mode get mode => Prop.currentModes.length == 0 ? null : Prop.currentModes.first;

  Widget _ModeTitleAndList() {
    if (Prop.currentModes.length == 0)
      return Container();

    print("NAME: ${mode.name}");
    return Container(
      margin: EdgeInsets.only(top: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          mode != null ? Text(mode.name ?? "") : null,
          // Container(
          //   margin: EdgeInsets.symmetric(horizontal: 3),
          //   child: mode?.name == null ? null : Text(" - "),
          // ),
          // Text("P${mode.page}M${mode.number}",
          //   style: TextStyle(fontWeight: FontWeight.bold),
          // )
        ].where((widget) => widget != null).toList()
      )
    );
  }


  Widget get _NowPlayingProgressBar {
    if (isPlayingAnimation == null) {
      isPlayingAnimation ??= AnimationController(
        duration: cycleDuration,
        upperBound: 1,
        lowerBound: 0,
        vsync: this,
      );
    }
    return AnimatedBuilder(
      animation: isPlayingAnimation,
      builder: (ctx, w) {
        Duration cycleProgress = cycleDuration * isPlayingAnimation.value;
        return Container(
          height: 8,
          child: Row(
            children: [
              Flexible(
                flex: cycleProgress.inMicroseconds,
                child: Container(
                  decoration: BoxDecoration(
                      color: Color(0xAAAAAAAA)
                  )
                )
              ),
              Flexible(
                flex: (cycleDuration - cycleProgress).inMicroseconds,
                child: Container(
                  decoration: BoxDecoration(
                      color: Color(0xAA333333)
                  )
                )
              ),
            ]
          )
        );
      }
    ); 
  }

}
