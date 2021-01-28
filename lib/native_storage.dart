import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io' show Platform;

class Storage {
  static Future<String> read(String key) async {
    if (!Platform.isAndroid && !Platform.isIOS) return Future.value(null); 

    final storage = FlutterSecureStorage();
    return await storage.read(key: key);
  }

  static Future<void> write(String key, String value) async {
    if (!Platform.isAndroid && !Platform.isIOS) return Future.value(); 

    final storage = FlutterSecureStorage();
    print("Attempting to write: ${key} => ${value}");
    return await storage.write(key: key, value: value);
  }

  static Future<void> delete(String key) async {
    if (!Platform.isAndroid && !Platform.isIOS) return Future.value(); 
    final storage = FlutterSecureStorage();
    return await storage.delete(key: key);
  }
}
