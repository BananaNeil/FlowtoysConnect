import 'package:json_api/document.dart';
import 'dart:convert';

class Account {
  List<String> propIds;
  String firstName;
  String lastName;
  String email;
  String id;

  Account({
    this.firstName,
    this.lastName,
    this.propIds,
    this.email,
    this.id,
  });

  String toJson() {
    return jsonEncode(toMap());
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'prop_ids': propIds,
      'email': email,
      'id': id,
    } as Map;
  }

  factory Account.fromMap(Map<String, dynamic> body) {
    var data = Document.fromJson(body, ResourceData.fromJson).data;
    return Account.fromResource(data.unwrap());
  }

  factory Account.fromResource(Resource resource, {included}) {
    if (resource == null) return null; 
    return Account(
      propIds: resource.attributes['prop_ids'] ?? [],
      firstName: resource.attributes['first_name'],
      lastName: resource.attributes['last_name'],
      id: resource.attributes['id'],
    );
  }

  factory Account.fromJson(String body) {
    return Account.fromMap(jsonDecode(body));
  }
}
