import 'package:app/models/timeline_element.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:app/models/base_mode.dart';
import 'package:app/models/mode_list.dart';
import 'package:app/app_controller.dart';
import 'package:app/authentication.dart';
import 'package:app/models/account.dart';
import 'package:http/http.dart' as http;
import 'package:app/models/bridge.dart';
import 'package:app/models/mode.dart';
import 'package:app/models/show.dart';
import 'package:app/models/song.dart';
import 'package:app/preloader.dart';
import 'dart:convert';
import 'dart:io';

class Client {

  static String humanize(str) {
    if (str != null && str.length > 0)
      return StringUtils.capitalize(str);
    else return '';
  }

  static Future<Map<dynamic, dynamic>> updateProps({propIds, propType, groupName, groupCount}) async {
    Future<Map<dynamic, dynamic>> response = makeRequest('post',
      path: '/props',
      body: {
        'ids': propIds,
        'prop_type': propType,
        'group_name': groupName,
        'group_count': groupCount,
      }
    );
  }

  static Future<Map<dynamic, dynamic>> fetchProps(props) async {
    Future<Map<dynamic, dynamic>> response = makeRequest('get',
      path: '/props',
      body: {
        'prop_ids': props.map((prop) => prop.uid).toList(),
      }
    );


    return response;
  }

  static Future<Map<dynamic, dynamic>> getAccount() async {
    return makeRequest('get',
      unauthorized: (() => Authentication.logout()),
      requireAuth: true,
      path: '/users',
    );
  }

  static Future<Map<dynamic, dynamic>> createAccount({firstName, lastName, email, password}) async {
    return makeRequest('post',
      path: '/auth',
      body: {
        'email': email.trim().toLowerCase(),
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'password': password,
      },
    );
  }

  static Future<Map<dynamic, dynamic>> updateAccount(data) async {
    return makeRequest('put',
      requireAuth: true,
      path: "/users/${data['id']}",
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
      Preloader.cacheBaseModes(response['baseModes']);
    }

    return response;
  }

  static Future<Map<dynamic, dynamic>> getModes() async {
    var response = await makeRequest('get', path: '/modes');

    if (response['success']) {
      response['modeList'] = ModeList.fromMap(response['body']);
      Preloader.cacheLists([response['modeList']]);
    }

    return response;
  }

  static Future<Map<dynamic, dynamic>> getShows() async {
    var response = await makeRequest('get', path: '/shows');

    if (response['success']) {
      response['shows'] = Show.fromList(response['body']);
    }

    return response;
  }

  static Future<Map<dynamic, dynamic>> removeTimelineElement(element) async {
    var response = await makeRequest('delete',
      path: '/timeline_elements/${element.id}',
    );

    return response;
  }

  static Future<Map<dynamic, dynamic>> updateTimelineElements(elements, {object}) async {
    var response = await makeRequest('put',
      path: '/timeline_elements',
      body: {
        'timeline_element_ids': elements.map((element) => element.id),
      },
    );

    return response;
  }

  static Future<Map<dynamic, dynamic>> updateTimelineElement(attributes) async {
    var id = attributes.remove('id');
    var response = await makeRequest('put',
      path: '/timeline_elements/$id',
      body: attributes,
    );

    if (response['success']) {
      response['timelineElement'] = TimelineElement.fromMap(response['body']);
    }

    return response;
  }

  static Future<Map<dynamic, dynamic>> createTimelineElement(attributes) async {
    var response = await makeRequest('post',
      path: '/timeline_elements',
      body: attributes,
    );

    if (response['success']) {
      response['timelineElement'] = TimelineElement.fromMap(response['body']);
    }

    return response;
  }

  static Future<Map<dynamic, dynamic>> updateShow(attributes) async {
    var id = attributes.remove('id');
    var response = await makeRequest('put',
      path: '/shows/$id',
      body: attributes,
    );

    if (response['success']) {
      response['show'] = Show.fromMap(response['body']);
    }

    return response;
  }

  static Future<Map<dynamic, dynamic>> createShow(attributes) async {
    var response = await makeRequest('post',
      path: '/shows',
      body: attributes,
    );

    if (response['success']) {
      response['show'] = Show.fromMap(response['body']);
    }

    return response;
  }

  static Future<Map<dynamic, dynamic>> getShow(id) async {
    var response = await makeRequest('get', path: '/shows/$id');

    if (response['success']) {
      response['show'] = Show.fromMap(response['body']);
    }

    return response;
  }

  static Future<Map<dynamic, dynamic>> fetchShowHistory(id, options) async {
    var response = await makeRequest('get', path: '/shows/$id/versions', body: options);

    if (response['success']) {
      response['versions'] = Show.fromList(response['body']);
    }

    return response;
  }


  static Future<Map<dynamic, dynamic>> updateSong(attributes) async {
    var id = attributes.remove('id');
    var response = await makeRequest('post',
      path: '/songs/$id',
      body: attributes,
    );

    if (response['success']) {
      response['song'] = Song.fromMap(response['body']['data']['attributes']);
      response['id'] = response['song'].id;
    }

    return response;
  }


  static Future<Map<dynamic, dynamic>> createSong(attributes) async {
    var response = await makeRequest('post',
      path: '/songs',
      body: attributes,
    );

    if (response['success']) {
      response['song'] = Song.fromMap(response['body']['data']['attributes']);
      response['id'] = response['song'].id;
    }

    return response;
  }

  static Future<Map<dynamic, dynamic>> getModeLists({creationType,user}) async {
    var queryParams = "";
    var params = [];

    if (creationType != null)
      params.add("creation_type=${creationType}");

    if (user != null)
      params.add("user=${user}");

    if (params.length >0)
      queryParams="?${params.join('&')}";

    var response = await makeRequest('get', path: '/mode_lists${queryParams}');

    if (response['success']) {
      response['modeLists'] = ModeList.fromList(response['body']);
      Preloader.cacheLists(response['modeLists']);
    }

    return response;
  }

  static Future<Map<dynamic, dynamic>> getModeList(id) async {
    var response = await makeRequest('get', path: "/mode_lists/${id}");

    if (response['success']) {
      response['modeList'] = ModeList.fromMap(response['body']);
      Preloader.cacheLists([response['modeList']]);
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
      Preloader.cacheLists([response['modeList']]);
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
    if (mode == null) return null; 
    var response = await makeRequest('delete',
      path: "/modes/${mode.id}"
    );

    return response;
  }


  static Future<Map<dynamic, dynamic>> createMode(mode) async {
    var response = await makeRequest('post',
      path: "/modes",
      body: {
        'mode': mode.toMap(),
      },
    );

    if (response['success']) {
      // This should bust the cached mode list
      response['mode'] = Mode.fromMap(response['body']['data']['attributes']);
      if (mode.parentType == 'ModeList')
        getModeList(mode.parentId);
    }

    return response;
  }

  static Future<Map<dynamic, dynamic>> updateBridge() async {
    var response = await makeRequest('post',
      path: "/bridges",
      body: {
        'bridge': Bridge.toMap(),
      },
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

    if (response['success']) {
      // This should bust the cached mode list
      response['mode'] = Mode.fromMap(response['body']);
      if (mode.parentType == 'ModeList')
        getModeList(mode.parentId);
    }

    return response;
  }

  static Future<Map<dynamic, dynamic>> updateList(id, options) async {
    var response = await makeRequest('put',
      path: "/mode_lists/${id}",
      body: options,
    );

    if (response['success']) {
      response['modeList'] = ModeList.fromMap(response['body']);
      Preloader.cacheLists([response['modeList']]);
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

  static setUserAttributes() {
  }

  static String get protocol => AppController.config['protocol'];
  static String get domain => AppController.config['domain'];
  static String get host => "${protocol}://${domain}";

  static String url(String path) {
    if (path == null) return null;
    if (path.contains("://")) return path;
    else return "$host$path";
  }

  static Future<Map<dynamic, dynamic>> makeRequest(method, {path, uri, headers, body, requireAuth, basicAuth, unauthorized, genericErrorCodes}) async {
    try {
      // print("\nRequest: $host$path");
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
      // print("encodeed: ${request.body}");
      (headers ?? {}).forEach((key, value) {
        request.headers[key] = value;
      });

      // print("Is authed: ${Authentication.isAuthenticated}");
      if (Authentication.isAuthenticated)
        Authentication.token.forEach((key, value) {
          request.headers[key] = value;
        });
      print("SENDING REQUEST");

      print("\n>>>>>>>>>>:\nTYPE: ${method}\nURL: $host$path\nHEADERS: ${request.headers}\nBODY: ${request.body}\n=======\n");
      http.StreamedResponse streamedResponse = await http.Client().send(request);
      http.Response response = await http.Response.fromStream(streamedResponse);

      var responseBody = (json.decode(response.body) as Map);
      var responseHeaders = response.headers;
      var code = response.statusCode;

      // print("\n<<<<<<<<<<\nURL: $host$path\nCODE: $code\nHEADERS: ${response.headers}\nRESPONSE BODY: ${jsonEncode(responseBody ?? {})}\n=======\n");

      var errors = responseBody['errors'] ?? {};
      var message;

      if (errors is List)
        message = errors.join("\n");
      else
        message = responseBody['error_message'] ?? (errors['full_messages'] ?? []).join("\n");

      if (responseHeaders['access-token'] != null)
        await Authentication.setToken({
          'access-token': responseHeaders['access-token'],
          'client': responseHeaders['client'],
          'uid': responseHeaders['uid'],
        });

      // For debugging: 
      if (response.statusCode == 401) {
        Authentication.invalidateAuth();
        if (unauthorized != null)
          unauthorized();
        return {
          'message': 'Unauthorized',
          'success': false,
          'code':  401,
          'body': { },
        };
      // } else if (genericErrorCodes.contains(response.statusCode)) {
      //   return {
      //     'success': false,
      //     'message': "Something went wrong, please try again later",
      //     'code': response.statusCode,
      //     'body': { },
      //   };
      } else return {
        'success': response.statusCode == 200,
        'message': humanize(message ?? ""),
        'body': responseBody,
        'code':  200,
      };
    } on SocketException catch (a) {
      print("SOCKET EXCEPTION: ${a}");
      return {
        'message': 'Not connected to the internet',
        'success': false,
        'code':  503,
        'body': { },
      };
     }// catch (e) {
     //   print("CAUGHT ERROR: ${e}");
     //   return {
     //     // Intentioinally putting no message here,
     //     // so we can fallback to a default
     //     'success': false,
     //     'body': { },
     //   };
     // }
  }
}
