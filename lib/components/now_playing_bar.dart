import 'package:flutter_hsvcolor_picker/flutter_hsvcolor_picker.dart';
import 'package:app/helpers/animated_clip_rect.dart';
import 'package:app/helpers/duration_helper.dart';
import 'package:app/components/mode_widget.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/models/group.dart';
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
              _ModeTitleAndList(),
              Container(
                margin: EdgeInsets.only(bottom: 10),
                padding: EdgeInsets.only(bottom: AppController.bottomPadding * 0.75),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Prop.current.length == 0 ?  Container() :
                        Container(
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
                            child: PropImage(prop: Prop.current.first, size: 25)
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
      )
    );
  }

  Timer animationTimer;
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

  Widget _ModeTitleAndList() {
    if (Prop.currentModes.length == 0)
      return Container();

    var mode = Prop.currentModes.first;
    return Container(
      margin: EdgeInsets.only(top: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          mode.name == null ? Text(mode.name ?? "") : null,
          Text("Page: ${mode.page} Mode:${mode.number}",
            style: TextStyle(fontWeight: FontWeight.bold),
          )
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
