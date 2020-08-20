import 'dart:convert';

class Account {
  String email;

  Account({
    this.email,
  });

  String toJson() {
    return jsonEncode(toMap());
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'email': email,
    } as Map;
  }

  factory Account.fromMap(Map<String, dynamic> body) {
    var json = body['account'] ?? body;
    return Account(
      email: json['email'],
    );
  }

  factory Account.fromJson(String body) {
    return Account.fromMap(jsonDecode(body));
  }
}
