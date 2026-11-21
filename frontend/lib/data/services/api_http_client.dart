import 'package:chucker_flutter/chucker_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

bool get androidHttpInspectionEnabled =>
    kDebugMode && !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

http.Client createApiHttpClient() {
  final client = http.Client();
  return androidHttpInspectionEnabled ? _InspectedHttpClient(client) : client;
}

class _InspectedHttpClient extends http.BaseClient {
  _InspectedHttpClient(this._transport);

  final http.Client _transport;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // Chucker tracks timing on the interceptor instance. Isolate it per request
    // while reusing the same socket pool for concurrent requests.
    return ChuckerHttpClient(_transport).send(request);
  }

  @override
  void close() => _transport.close();
}
