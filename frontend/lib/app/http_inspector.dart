import 'dart:async';

import 'package:chucker_flutter/chucker_flutter.dart';
// Chucker detail routes still use Flutter Material's localization type.
// ignore: deprecated_member_use
import 'package:flutter/material.dart'
    as flutter_material
    show DefaultMaterialLocalizations;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../data/services/api_http_client.dart';

abstract final class HttpInspector {
  static const _channel = MethodChannel('promptlearn/http_inspector');
  static final _navigation = _InspectorNavigation();

  static GlobalKey<NavigatorState>? get navigatorKey =>
      androidHttpInspectionEnabled ? ChuckerFlutter.navigatorKey : null;

  static List<NavigatorObserver> get navigatorObservers =>
      androidHttpInspectionEnabled ? [_navigation] : const [];

  // Chucker opens detail routes on the root Navigator using Flutter Material.
  static List<LocalizationsDelegate<dynamic>> get localizationsDelegates =>
      androidHttpInspectionEnabled
      ? const [flutter_material.DefaultMaterialLocalizations.delegate]
      : const [];

  static Future<void> initialize() async {
    if (!androidHttpInspectionEnabled) return;

    ChuckerFlutter.configure(showNotification: false);
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'open') _navigation.open();
    });

    try {
      final openOnLaunch = await _channel.invokeMethod<bool>('initialize');
      if (openOnLaunch == true) _navigation.open();
    } on PlatformException catch (error) {
      debugPrint('Chucker notification setup failed: ${error.code}');
    } on MissingPluginException {
      debugPrint('Rebuild the Android app to enable the Chucker notification.');
    }

    unawaited(_probeBackend());
  }

  static Future<void> _probeBackend() async {
    const configuredUrl = String.fromEnvironment('PROMPTLEARN_API_BASE_URL');
    if (configuredUrl.isEmpty) return;

    final base = Uri.tryParse(configuredUrl);
    if (base == null ||
        !base.hasAuthority ||
        (base.scheme != 'http' && base.scheme != 'https')) {
      debugPrint('PROMPTLEARN_API_BASE_URL must be an HTTP(S) URL.');
      return;
    }

    final client = createApiHttpClient();
    try {
      await client
          .get(base.resolve('/healthz'))
          .timeout(const Duration(seconds: 5));
    } on Exception {
      debugPrint('PromptLearn debug health check could not reach the backend.');
    } finally {
      client.close();
    }
  }
}

class _InspectorNavigation extends NavigatorObserver {
  Route<dynamic>? _inspectorRoute;
  bool _opening = false;

  void open() {
    if (_inspectorRoute?.isActive == true) return;
    _opening = true;
    try {
      ChuckerFlutter.showChuckerScreen();
    } finally {
      _opening = false;
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_opening) _inspectorRoute = route;
  }
}
