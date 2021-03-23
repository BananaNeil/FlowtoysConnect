import 'package:app/push_notifications.dart';
import 'package:app/models/account.dart';
import 'package:app/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/preloader.dart';
import 'package:app/client.dart';
import 'dart:convert';
import 'dart:async';

import 'package:app/native_storage.dart'
  if (dart.library.html) 'package:app/web_storage.dart';

class Authentication {
  static Account currentAccount = Account();
  static Map<dynamic, dynamic> token;

  static void setEmail(email) {
    if (currentAccount.email != email)
      setCurrentAccount(Account(email: email));
  }

  static Future<Account> getAccount() async {
      print("CA1: ${Authentication.currentAccount}");
    return await Client.getAccount().then((response) {
      print("${response['success']} BACK FROM GETTIN GACCOUNT WITH :${response['body']}");
      if (response['success'])
        setCurrentAccount(Account.fromResourceMap(response['body']));
      print("CA: ${Authentication.currentAccount.toMap()}");

      return currentAccount;
    });
  }

  static Future<Map<dynamic, dynamic>> updateAccount({data, submit}) async {
    var accountData = currentAccount.toMap();
    var newAccount = Account.fromMap({
      ...accountData,
      ...(data ?? {}),
    });
    if (submit ?? true)
      return await Client.updateAccount(newAccount.toMap()).then((response) {
        print("BACK FORM UPDATE WITH RESPONSE: ${response['success']}");
        if (response['success'])
          setCurrentAccount(newAccount);
        return response;
      });
    else setCurrentAccount(newAccount);
  }

  static Future<void> setToken(data) {
    token = data;
    return saveTokenToDisk();
  }

  static void setCurrentAccount(newAccount) {
    currentAccount = newAccount;
    ensureNotifications();
    saveAccountToDisk();
  }

  static void ensureNotifications() {
    if (isAuthenticated) {
      // Timer(Duration(milliseconds: 1000), () => PushNotificationsManager().init());
    }
  }

  static void invalidateAuth() {
    token = null;
  }

  static bool get isAuthenticated {
    return token != null && token['access-token'] != null;
  }

  static Future<bool> checkForAuth() async {
    return await readFromDisk('token').then((accessToken) {
      if (accessToken == 'null' || accessToken == null) accessToken = null;
      else token = json.decode(accessToken) as Map;

      if (isAuthenticated) {
        getAccount();
        return readFromDisk('currentAccount').then((json) {
          print("READ account FROM DISK: ${json}");
          if (json != null)
            setCurrentAccount(Account.fromJson(json));
          // else setCurrentAccount(Account());

          return true;
        });
      } else return false;
    });
  }

  static Future<String> readFromDisk(key) async {
    return Storage.read(key);
  }

  static Future<void> saveTokenToDisk() async {
    if (token == null)
      return await Storage.delete('token');
    else
      return await Storage.write('token', jsonEncode(token));
  }

  static void saveAccountToDisk() async {
    print("SAVE ACCOUNT TO DISK: ${currentAccount.toJson()}");
    await Storage.write('currentAccount', currentAccount.toJson());
  }

  static void logout() async {
    await setToken(null);
    await setCurrentAccount(Account());
    AppController.closeUntilPath('/login');
  }
}

