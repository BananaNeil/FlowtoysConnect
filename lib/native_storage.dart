import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:localstorage/localstorage.dart';
import 'dart:io' show Platform;

class Storage {
  static bool get platformSupported => Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isLinux;
  static FlutterSecureStorage _storage;
  static FlutterSecureStorage get storage => _storage ??= FlutterSecureStorage();

  static LocalStorage _macStorage;
  static LocalStorage get macStorage => _macStorage ??= new LocalStorage('flowtoys');

  static Future<bool> ready() async {
    if (Platform.isMacOS) return macStorage.ready;
    final prefs = await SharedPreferences.getInstance();

    if (prefs.getBool('first_run') ?? true) {
      FlutterSecureStorage storage = FlutterSecureStorage();
      await storage.deleteAll();
      prefs.setBool('first_run', false);
    }
    return Future.value(true);
  }

  static Future<String> read(String key) async {
    print("READ KEY: ${key}");
    if (!platformSupported) return Future.value(null); 
    if (Platform.isMacOS) return await macStorage.getItem(key);


    return await storage.read(key: key);
  }

  static Future<void> write(String key, String value) async {
    print("WRITE KEY: ${key}");
    if (Platform.isMacOS) return await macStorage.setItem(key, value).then((_) {
      print("KEY WRITTEN: ${key}");
    });
    if (!platformSupported) return Future.value(); 

    // print("Attempting to write: ${key} => ${value}");
    return await storage.write(key: key, value: value);
  }

  static Future<void> delete(String key) async {
    print("DELETE KEY: ${key}");
    if (!platformSupported) return Future.value(); 
    if (Platform.isMacOS) return await macStorage.setItem('key', null);

    return await storage.delete(key: key);
  }
}
