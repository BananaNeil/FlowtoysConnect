import 'package:app/authentication.dart';
import 'package:json_api/document.dart';
import 'package:app/client.dart';
import 'dart:convert';

class Account {
  Set<String> bridgeBleIds;
  Set<String> propIds;
  String firstName;
  String lastName;
  String email;
  String id;

  Account({
    this.bridgeBleIds,
    this.firstName,
    this.lastName,
    this.propIds,
    this.email,
    this.id,
  });


  Set<String> _connectedPropIds = Set<String>();
  Set<String> get connectedPropIds => propIds.union(_connectedPropIds);
  void removePropId(id) {
    _connectedPropIds.remove(id);
    propIds.remove(id);
    save();
  }
  void addConnectedPropId(id) {
    _connectedPropIds.add(id);
  }
  void set connectedPropIds(value) {
    _connectedPropIds = value;
  }


  String toJson() {
    return jsonEncode(toMap());
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'bridge_ble_ids': List<String>.from(bridgeBleIds ?? []),
      'prop_ids': List<String>.from(propIds ?? []),
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'id': id,
    } as Map;
  }

  Future<Map<dynamic,dynamic>> save() {
    return Authentication.updateAccount();
  }

  factory Account.fromMap(Map<String, dynamic> body) {
    return Account(
      bridgeBleIds: Set<String>.from(body['bridge_ble_ids'] ?? []),
      propIds: Set<String>.from(body['prop_ids'] ?? []),
      firstName: body['first_name'],
      lastName: body['last_name'],
      id: body['id'],
    );
  }

  factory Account.fromResourceMap(Map<String, dynamic> body) {
    var data = Document.fromJson(body, ResourceData.fromJson).data;
    var resource = data.unwrap();

    if (resource == null) return null; 
    return Account.fromMap(resource.attributes);
  }

  factory Account.fromJson(String body) {
    return Account.fromMap(jsonDecode(body));
  }
}
