import 'dart:convert';

import 'package:http/http.dart' as http;

String url = "http://b915-142-127-213-8.ngrok.io/image";
Future<http.Response> sendFile(String encodedstring, String u){
  return http.post(
      Uri.parse(u + "/image"),
    headers: <String, String> {
        'Content-Type' : 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, String>{
      'encodedstring' : encodedstring,
    })
  );
}