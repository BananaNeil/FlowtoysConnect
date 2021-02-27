import 'package:app/authentication.dart';
import 'package:json_api/document.dart';
import 'package:app/models/mode.dart';
import 'dart:convert';

class ModeList {
  String creationType;
  String accessLevel;
  List<Mode> modes;
  String name;
  String id;

  ModeList({
    this.id,
    this.name,
    this.modes,
    this.accessLevel,
    this.creationType,
  });

  static String toJson(List<ModeList> lists) {
    return jsonEncode({
      'data': lists.map((list) => list.toResource()).toList(),
      'included': lists.map((list) => list.modes).expand((modes) => modes).map((mode) => mode.toResource()).toList(),
    });
  }

  static List<ModeList> fromList(Map<String, dynamic> json) {
    var data = ResourceCollectionData.fromJson(json);
    return data.collection.map((object) {
      return ModeList.fromResource(object.unwrap(), included: data.included);
    }).toList();
  }

  ResourceObject toResource() {
    return ResourceObject('mode_list', id.toString(), attributes: toMap(), relationships: {
      'modes': ToMany(
        modes.map((mode) => IdentifierObject('mode', mode.id.toString())),
      )
    });
  }

  factory ModeList.fromResource(Resource resource, {included}) {
    if (resource == null) return null; 
    var modes = resource.toMany['modes'].map((mode) {
      var modeData = (included ?? []).firstWhere((item) => item.id == mode.id);
      return Mode.fromMap(modeData.attributes);
    }).toList();

    return ModeList(
      modes: modes,
      id: resource.attributes['id'],
      name: resource.attributes['name'],
      accessLevel: resource.attributes['access_level'],
      creationType: resource.attributes['creation_type'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'access_level': accessLevel,
      'creation_type': creationType,
    };
  }

  factory ModeList.fromMap(Map<String, dynamic> json) {
    var data = Document.fromJson(json, ResourceData.fromJson).data;
    return ModeList.fromResource(data.unwrap(), included: data.included);
  }

  factory ModeList.fromJson(String body) {
    var json = jsonDecode(body);
    if (json['data'] == null)
      json = {'data': json};
    return ModeList.fromMap(json);
  }
}



