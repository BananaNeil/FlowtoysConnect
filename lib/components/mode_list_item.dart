import 'package:flutter_reorderable_list/flutter_reorderable_list.dart';
import 'package:app/components/horizontal_line_shadow.dart';
import 'package:app/helpers/color_filter_generator.dart';
import 'package:app/components/inline_mode_params.dart';
import 'package:app/helpers/animated_clip_rect.dart';
import 'package:app/components/mode_widget.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/models/group.dart';
import 'package:app/models/mode.dart';
import 'package:app/models/prop.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math';


class ModeListItem extends StatefulWidget {
  ModeListItem({
    Key key,
    this.mode,
    this.onTap,
    this.isEditing,
    this.isExpanded,
    this.removeMode,
    this.fetchModes,
    this.isSelecting,
    this.toggleExpand,
    this.containerWidth,
    this.selectedModeIndex,
    this.isAdjustingInlineParam,
  }) : super(key: key);

  Mode mode;
  Function onTap;
  bool isEditing;
  bool isExpanded;
  bool isSelecting;
  Function fetchModes;
  Function removeMode;
  double containerWidth;
  int selectedModeIndex;
  Function toggleExpand;
  Function isAdjustingInlineParam;

  @override
  _ModeListItem createState() => _ModeListItem(
    mode: mode,
  );

}


class _ModeListItem extends State<ModeListItem> {
  _ModeListItem({
    this.mode,
  });

  Mode mode; 

  bool get isSmall => widget.containerWidth <= 450;
  bool get isXSmall => widget.containerWidth <= 380;
  StreamSubscription currentModeSubscription;

  @override
  dispose() {
    currentModeSubscription.cancel();
    super.dispose(); 
  }

  @override
  Widget build(BuildContext context) {
    currentModeSubscription ??= Prop.propUpdateStream.listen((prop) {
      if (activePropCountChanged && this.mounted)
        setState(() {});
    });
    var isSelected = widget.selectedModeIndex > 0;
    return Card(
      key: Key(mode.id.toString()),
      elevation: 8.0,
      margin: EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      child: Column(
        children: [
          Container(
            child: ListTile(
              onTap: widget.onTap,
              minLeadingWidth: 0,
              contentPadding: EdgeInsets.symmetric(horizontal: isSmall ? 8.0 : 20.0, vertical: 5.0),
              leading: widget.isEditing ? ReorderableListener(child: Icon(Icons.drag_indicator, color: Color(0xFF888888))) : (!widget.isSelecting ? null : Container(
                width: 22,
                padding: EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected ? Color(0xFF4f8adb) : null,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                child: Text(
                  isSelected ? widget.selectedModeIndex.toString() : "",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                  )
                ),
              )),
              trailing: _TrailingIcon(),
              title: _ModeItemContent(),
            ),
          ),
          AnimatedClipRect(
            curve: Curves.easeInOut,
            verticalAnimation: true,
            horizontalAnimation: false,
            alignment: Alignment.topCenter,
            open: widget.isExpanded && !widget.isSelecting,
            duration: Duration(milliseconds: 200),
            child: _ExpandedModeContent(),
          ),
          Container(
            height: 15,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Color(0xAA000000),
                  spreadRadius: 2.0,
                  blurRadius: 2.0,
                ),
              ]
            ),
            child: ModeRow(
              mode: mode,
              showImages: true,
              fit: BoxFit.fill,
            ),
          ),
        ]
      ),
    );
  }

  Widget _ModeItemContent() {
    return Column(
      children: [
        Row(
          children: [
            Container(
              margin: EdgeInsets.only(right: isSmall ? 8 : 15),
              child: ModeImage(
                mode: mode,
                size: isSmall ? 20.0 : 30.0,
              )
            ),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: widget.isSelecting ? null : () {
                    widget.toggleExpand();
                    widget.isExpanded = !widget.isExpanded;
                    setState(() {});
                  },
                  child: Row(
                    children: [
                      // This was not enough.. why is it still overflowng names?
                      Container(child: Text(mode.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isSmall ? 15 : 18,
                        ),
                      )),
                      Container(
                        child: widget.isSelecting ? null :
                          widget.isExpanded ? Icon(Icons.expand_more) : Icon(Icons.chevron_right),
                      )
                    ]
                  ),
                ),
                _ActiveModesIndicator(),
                Container(
                    width: widget.containerWidth - (isSmall ? 130 : 200),
                  margin: EdgeInsets.only(top: 2),
                  child: Text(mode.description,
                    style: TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ),
              ]
            ))
          ]
        ),
      ]
    );
  }

  
  Widget _ActiveModesIndicator() {
    // This should show this:
    _activePropCount = activePropCount;
    //
    // But until props can be addressed individually, we must show "groups"
    // var groupCount = Group.connectedGroups.where((group) => group.currentMode.id == mode.id).length;
    return Container(
      child: _activePropCount == 0 ? null : Text(
        "${_activePropCount} ${Intl.plural(_activePropCount, one: 'group', other: 'groups')} activated",
        style: TextStyle(
            fontSize: 14,
            color: AppController.purple,
        )
      ),
    );
  }

  int _activePropCount;
  bool get activePropCountChanged => _activePropCount == activePropCount;
  int get activePropCount {
    return Prop.connectedModeIds.where((id) => mode.id == id).length;
  }

  Widget _ExpandedModeContent() {
    return Container(
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF262626),
                    Color(0xFF1A1A1A),
                    Colors.black,
                  ]
                ),
                // image: DecorationImage(
                //   image: AssetImage("assets/images/dark-texture.jpg"),
                //   repeat: ImageRepeat.repeat,
                //   fit: BoxFit.none,
                //   scale: 2,
                // ),
              )
            )
          ),
          Container(
            child: Column(
              children: [
                HorizontalLineShadow(),
                Container(
                  margin: EdgeInsets.only(
                    right: 10,
                    bottom: 20,
                    left: 10,
                    top: 5,
                  ),
                  child: _ModeTileParams(),
                ),
              ]
            // )
          ),
        ),
            // decoration: BoxDecoration(
            //   boxShadow: [
            //     const BoxShadow(
            //       color: Color(0xAA000000),
            //     ),
            //     const BoxShadow(
            //       color: Color(0xFF888888),
            //       offset: Offset(0.0, 2),
            //       spreadRadius: -2.0,
            //       blurRadius: 8.0,
            //     ),
            //   ],
            // ),
        ]
      )
    );
  }

  Timer _adjustingInlineParamTimer;
  Widget _ModeTileParams() {
    return InlineModeParams(
      onTouchDown: () {
        _adjustingInlineParamTimer?.cancel();
        widget.isAdjustingInlineParam(true);
      },
      onTouchUp: () {
        _adjustingInlineParamTimer = Timer(Duration(seconds: 1), () => widget.isAdjustingInlineParam(false));
        // (Prop.propsByModeId[mode.id] ?? []).forEach((prop) => prop.currentMode = mode );
        setState(() {});
      },
      updateMode: () {
        Prop.refreshByMode(mode);
      },
      onSaveAs: () {
        Navigator.pushNamed(context, '/lists/new', arguments: {
          'selectedModes': [mode],
        });
      },
      mode: mode,
    );
  }

  Widget _TrailingIcon() {
    if (widget.isEditing)
      return GestureDetector(
        onTap: () {
					AppController.openDialog("Are you sure?", "This will remove \"${mode.name}\" from this list along with any customizations made to it.",
            buttonText: 'Cancel',
						buttons: [{
							'text': 'Delete',
              'color': Colors.red,
							'onPressed': () {
                widget.removeMode(mode);
							},
						}]
					);
        },
        child: Icon(Icons.delete_forever, color: AppController.red),
      );
    else if (widget.isSelecting)
      return null;
    else return GestureDetector(
      onTap: () {
        var replacement = mode.dup();
        Navigator.pushNamed(context, '/modes/${replacement.id}', arguments: {
          'mode': replacement,
        }).then((saved) {
          if (saved == true)
            mode.updateFromCopy(replacement).then((_) {
              widget.fetchModes();
            });
        });
      },
      child: Column(
        children: [
          // Icon(Icons.edit),
          Text("EDIT", style: TextStyle(fontSize: 13)),
        ]
      )
    );
  }

}
