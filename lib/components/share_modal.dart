import 'package:flutter_share/flutter_share.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:app/models/mode_list.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'dart:async';


class ShareModal extends StatefulWidget {
  ShareModal({this.shareable});
  final dynamic shareable;

  _ShareModal createState() => _ShareModal();

}

class _ShareModal extends State<ShareModal> {

  String get shareUrl {
    var host = "http://app.flowtoys.com";
    String path = "";
    if (widget.shareable is ModeList)
      path = "/lists/${widget.shareable.id}";
    print("IS IT? $host$path");
    return "$host$path";
  }

  bool coppied = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Container(
          padding: EdgeInsets.only(top: 5, bottom: 30),
          decoration: BoxDecoration(
              color: Color(0xFF1F1f1f),
          ),
        child: Column(
            mainAxisSize: MainAxisSize.min,
          // crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              margin: EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.black,
              ),
              child: Container(
                padding: EdgeInsets.all(5),
                child: QrImage(
                  foregroundColor: AppController.blue,
                  version: QrVersions.auto,
                  data: shareUrl,
                  size: 200.0,
                )
              ),
            ),
            Container(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 240,
                    child: TextFormField(
                      initialValue: shareUrl,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    )
                  ),
                  GestureDetector(
                    child: Icon(coppied ? Icons.done_all : Icons.copy, size: 18),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: shareUrl)).then((_) {
                        setState(() => coppied = true);
                        Timer(Duration(seconds: 2), () {
                          setState(() => coppied = false);
                        });
                      });
                    },
                  ),
                ]
              ),
            ),
            Visibility(
              visible: Platform.isIOS || Platform.isAndroid,
              child: GestureDetector(
                child: Text("Open native share sheet"),
                onTap: () async {
                  await FlutterShare.share(
                    // chooserTitle: 'Example Chooser Title'
                    // text: 'Example share text',
                    title: widget.shareable.name,
                    linkUrl: shareUrl,
                  );
                }
              )
            ),
          ]
        )
      )
    );
  }
}

