import 'package:basic_utils/basic_utils.dart';
import 'package:app/models/base_mode.dart';
import 'package:app/models/mode_list.dart';
import 'package:app/app_controller.dart';
import 'package:app/authentication.dart';
import 'package:app/models/account.dart';
import 'package:http/http.dart' as http;
import 'package:app/models/mode.dart';
import 'dart:convert';
import 'dart:io';

class Client {

  static String humanize(str) {
    if (str != null && str.length > 0)
      return StringUtils.capitalize(str);
    else return '';
  }

  static Future<Map<dynamic, dynamic>> getAccount() async {
    return makeRequest('get',
      unauthorized: (() => Authentication.logout()),
      requireAuth: true,
      path: '/users',
    );
  }

  static Future<Map<dynamic, dynamic>> createAccount(email, password) async {
    return makeRequest('post',
      path: '/auth',
      body: {
        'email': email.trim().toLowerCase(),
        'password': password,
      },
    );
  }

  static Future<Map<dynamic, dynamic>> updateAccount(data) async {
    return makeRequest('put',
      requireAuth: true,
      path: '/users',
      body: data,
    );
  }

  static Future<Map<dynamic, dynamic>> setFireBaseToken(data) async {
    return makeRequest('put',
      path: '/firebase_tokens',
      requireAuth: true,
      body: {
        'firebase_token': data
      },
    );
  }

  static Future<Map<dynamic, dynamic>> resetPassword(email) async {
    return makeRequest('post',
      path: '/reset_password',
      body: {
        'email': email.trim(),
      },
    );
  }

  static Future<Map<dynamic, dynamic>> getBaseModes() async {
    var response = await makeRequest('get', path: '/base_modes');

    if (response['success']) {
      response['baseModes'] = BaseMode.fromList(response['body']);
    }

    return response;
  }

  static Future<Map<dynamic, dynamic>> getModes() async {
    var response = await makeRequest('get', path: '/modes');

    if (response['success']) {
      response['modeList'] = ModeList.fromMap(response['body']);
    }

    return response;
  }

  static Future<Map<dynamic, dynamic>> getModeLists({type}) async {
    var params = type == null ? "" : "?type=${type}";
    var response = await makeRequest('get', path: '/mode_lists${params}');

    if (response['success']) {
      response['modeLists'] = ModeList.fromList(response['body']);
    }

    return response;
  }

  static Future<Map<dynamic, dynamic>> getModeList(id) async {
    if (id == 'default') return getModeLists(type: 'default');

    var response = await makeRequest('get', path: "/mode_lists/${id}");

    if (response['success']) {
      response['modeList'] = ModeList.fromMap(response['body']);
    }

    return response;
  }

  static Future<Map<dynamic, dynamic>> createNewList(name, modes) async {
    var modeIds = modes.map((mode) => mode.id).toList();
    var response = await makeRequest('post',
      path: '/mode_lists',
      body: {
        'name': name,
        'mode_ids': modeIds,
      },
    );

    if (response['success']) {
      response['modeList'] = ModeList.fromMap(response['body']);
    }

    return response;
  }

  static Future<Map<dynamic, dynamic>> getMode(modeId) async {
    var response = await makeRequest('get',
      path: "/modes/${modeId}"
    );

    if (response['success']) {
      response['mode'] = Mode.fromMap(response['body']['data']['attributes']);
    }

    return response;
  }

  static Future<Map<dynamic, dynamic>> removeMode(mode) async {
    var response = await makeRequest('delete',
      path: "/modes/${mode.id}"
    );

    return response;
  }

  static Future<Map<dynamic, dynamic>> updateMode(mode) async {
    var response = await makeRequest('put',
      path: "/modes/${mode.id}",
      body: {
        'mode': mode.toMap(),
      },
    );

    return response;
  }

  static Future<Map<dynamic, dynamic>> updateList(id, options) async {
    var response = await makeRequest('put',
      path: "/mode_lists/${id}",
      body: options,
    );

    if (response['success']) {
      response['modeList'] = ModeList.fromMap(response['body']);
    }

    return response;
  }

  static Future<Map<dynamic, dynamic>> authenticate(email, password) async {
    email = email.trim().toLowerCase();

    var response = await makeRequest('post',
      path: '/auth/sign_in',
      body: {
        'email': email.trim().toLowerCase(),
        'password': password,
      }
    );

    if (response['success']) {
      Authentication.setEmail(email);
    }

    return response;
  }

  static Future<Map<dynamic, dynamic>> makeRequest(method, {path, uri, headers, body, requireAuth, basicAuth, unauthorized, genericErrorCodes}) async {
    try {
      final protocol = AppController.config['protocol'];
      final domain = AppController.config['domain'];
      final host = "$protocol://$domain";

      print("Request: $host$path");
      http.Request request = http.Request(method, uri ?? Uri.parse('$host$path'));
      if (genericErrorCodes == null) genericErrorCodes = [500];

      request.headers['Content-Type'] = 'application/json; charset=UTF-8';


      request.body = jsonEncode(body ?? {}, toEncodable: (object) {
        var json = {};
        Map<int, Object>.from(object).forEach((key, value) {
          json[key.toString()] = value;
        });
        return json;
      });
      print("encodeed: ${request.body}");
      (headers ?? {}).forEach((key, value) {
        request.headers[key] = value;
      });

      print("Is authed: ${Authentication.isAuthenticated()}");
      if (Authentication.isAuthenticated())
        Authentication.token.forEach((key, value) {
          request.headers[key] = value;
        });
      print("SENDING REQUEST");

      print(">>>>>>>>>>:\nTYPE: ${method}\nURL: $host$path\nHEADERS: ${request.headers}\nBODY: ${request.body}\n=======");
      http.StreamedResponse streamedResponse = await http.Client().send(request);
      http.Response response = await http.Response.fromStream(streamedResponse);

      var responseBody = (json.decode(response.body) as Map);
      var responseHeaders = response.headers;
      var code = response.statusCode;

      print("<<<<<<<<<<\nURL: $host$path\nCODE: $code\nHEADERS: ${response.headers}\nRESPONSE BODY: ${jsonEncode(responseBody ?? {})}\n=======");

      var errors = responseBody['errors'] ?? {};
      var message;

      if (errors is List)
        message = errors.join("\n");
      else
        message = responseBody['error_message'] ?? (errors['full_messages'] ?? []).join("\n");

      if (responseHeaders['access-token'] != null)
        Authentication.setToken({
          'access-token': responseHeaders['access-token'],
          'client': responseHeaders['client'],
          'uid': responseHeaders['uid'],
        });

      // For debugging: 
      if (response.statusCode == 401 && unauthorized != null) {
        unauthorized();
        return {
          'message': 'Unauthorized',
          'success': false,
          'body': { },
        };
      } else if (genericErrorCodes.contains(response.statusCode)) {
        return {
          'success': false,
          'message': "Something went wrong, please try again later",
          'body': { },
        };
      } else return {
        'success': response.statusCode == 200,
        'message': humanize(message ?? ""),
        'body': responseBody,
      };
    } on SocketException catch (_) {
      return {
        'message': 'Not connected to the internet',
        'success': false,
        'body': { },
      };
    }// } catch (e) {
    //   return {
    //     'message': "${e}",
    //     'success': false,
    //     'body': { },
    //   };
    // }
  }
}
