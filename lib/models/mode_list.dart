import 'package:app/authentication.dart';
import 'package:json_api/document.dart';
import 'package:app/models/mode.dart';
import 'dart:convert';

class ModeList {
  List<Mode> modes;
  String name;
  num id;

  ModeList({
    this.id,
    this.name,
    this.modes,
  });

  static List<ModeList> fromList(Map<String, dynamic> json) {
    var data = ResourceCollectionData.fromJson(json);
    return data.collection.map((object) {
      return ModeList.fromResource(object.unwrap(), included: data.included);
    }).toList();
  }

  factory ModeList.fromResource(Resource resource, {included}) {
    var modes = resource.toMany['modes'].map((mode) {
      var modeData = included.firstWhere((item) => item.id == mode.id);
      return Mode.fromMap(modeData.attributes);
    }).toList();

    return ModeList(
      modes: modes,
      id: resource.attributes['id'],
      name: resource.attributes['name'],
    );
  }

  factory ModeList.fromMap(Map<String, dynamic> json) {
    var data = Document.fromJson(json, ResourceData.fromJson).data;
    return ModeList.fromResource(data.unwrap(), included: data.included);
  }

  factory ModeList.fromJson(String body) {
    return ModeList.fromMap(jsonDecode(body));
  }
}



