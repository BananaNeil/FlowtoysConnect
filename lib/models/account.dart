import 'dart:convert';

class Account {
  String firstName;
  String lastName;
  String email;

  Account({
    this.firstName,
    this.lastName,
    this.email,
  });

  String toJson() {
    return jsonEncode(toMap());
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'first_name': firstName,
      'last_name': firstName,
      'email': email,
    } as Map;
  }

  factory Account.fromMap(Map<String, dynamic> body) {
    var json = body['account'] ?? body;
    return Account(
      firstName: json['first_name'],
      lastName: json['last_name'],
      email: json['email'],
    );
  }

  factory Account.fromJson(String body) {
    return Account.fromMap(jsonDecode(body));
  }
}
