import 'package:flutter_hsvcolor_picker/flutter_hsvcolor_picker.dart';
import 'package:app/helpers/animated_clip_rect.dart';
import 'package:app/helpers/duration_helper.dart';
import 'package:app/components/mode_widget.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/models/prop.dart';
import 'dart:async';
import 'dart:math';

class NowPlayingBar extends StatefulWidget {
  NowPlayingBar({
    Key key,
    this.onNext,
    this.shuffle,
    this.onMenuTap,
    this.onPrevious,
    this.toggleShuffle,
  }) : super(key: key);


  Function onNext;
  Function onPrevious;
  Function toggleShuffle;
  Function onMenuTap;

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
    currentModeSubscription.cancel();
    super.dispose(); 
  }

  StreamSubscription currentModeSubscription;

  @override
  Widget build(BuildContext context) {
    currentModeSubscription ??= Prop.currentModeStream.listen((mode) {
      // This is not yet fully working!!!!!!!!!!
      // This is not yet fully working!!!!!!!!!!
      // This is not yet fully working!!!!!!!!!!
      // This is not yet fully working!!!!!!!!!!
      // This is not yet fully working!!!!!!!!!!
      isPlayingAnimation.value = 0.0;
      if (isPlaying) isPlayingAnimation.forward();
      setState(() {});
    });
    return Align(
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
              margin: EdgeInsets.only(bottom: 10, top: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: Prop.propsByMode.entries.map<Widget>((entry) {
                        var mode = entry.key;
                        var props = entry.value;
                        if (AppController.isSmallScreen && Prop.propsByMode.entries.length > 1)
                          return ModeImage(mode: mode, size: 15);
                        else
                          return Container(
                            margin: EdgeInsets.only(left: 10),
                            child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  margin: EdgeInsets.symmetric(horizontal: 3),
                                  child: ModeImage(mode: mode, size: 15),
                                ),
                                Text("X${props.length}")
                              ]
                            )
                          );
                      }).toList()
                    ),
                  ),
                  _PlayControlers,
                  Expanded(
                    // width: double.infinity,
                    child: Align(
                      alignment: Alignment.centerRight,
                      // visible: !isShowingMultipleLists,
                      child: GestureDetector(
                        onTap: () {
                          widget.onMenuTap();
                        },
                        child: Container(
                          padding: EdgeInsets.only(right: AppController.isSmallScreen ? 10 : 25, top: 10),
                          child: Icon(
                            Icons.more_horiz,
                            color: Colors.white,
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
    );
  }

  Widget get _PlayControlers {
    return Container(
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
            onTap: () => widget.onPrevious(),
            child: Icon(Icons.skip_previous, size: 38),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                isPlaying = !isPlaying;
                if (isPlaying)
                  isPlayingAnimation.forward();
                else
                  isPlayingAnimation.stop();
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
                print("SET THE ISPLAYING ANIMATION!");
                isPlayingAnimation.duration = cycleDuration;
                if (isPlaying) {
                  isPlayingAnimation.stop();
                  isPlayingAnimation.forward();
                }
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

  void onNext() {
    print("ON NEXT: ${isPlaying}");
    widget.onNext();
    if (isPlaying) {
      Timer(Duration(milliseconds: 20), () => setState((){})); 
      isPlayingAnimation.value = 0.0;
      isPlayingAnimation.forward();
    }
  }


  Widget get _NowPlayingProgressBar {
    if (isPlayingAnimation == null) {
      isPlayingAnimation ??= AnimationController(
        duration: cycleDuration,
        upperBound: 1,
        lowerBound: 0,
        vsync: this,
      );
      isPlayingAnimation.addStatusListener((status) {
        if(status == AnimationStatus.completed)
          onNext();
      }); 
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
