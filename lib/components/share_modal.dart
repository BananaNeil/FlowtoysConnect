import 'package:flutter_share/flutter_share.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:app/models/mode_list.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;


class ShareModal extends StatelessWidget {
  ShareModal({this.shareable});
  final dynamic shareable;

  String get shareUrl {
    var host = "http://app.flowtoys.com";
    String path = "";
    if (shareable is ModeList)
      path = "/lists/${shareable.id}";
    print("IS IT? $host$path");
    return "$host$path";
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
          decoration: BoxDecoration(
              color: Color(0xFF222222),
          ),
        child: Column(
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
                    width: 200,
                    child: TextFormField(
                      initialValue: shareUrl,
                    )
                  ),
                  GestureDetector(
                    child: Icon(Icons.copy, size: 18),
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
                    title: shareable.name,
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

