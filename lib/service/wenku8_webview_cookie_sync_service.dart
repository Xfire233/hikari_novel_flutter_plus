import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hikari_novel_flutter/common/log.dart';
import 'package:hikari_novel_flutter/main.dart';
import 'package:hikari_novel_flutter/service/local_storage_service.dart';

class Wenku8WebViewCookieSyncService {
  const Wenku8WebViewCookieSyncService._();

  static final CookieManager _cookieManager = CookieManager.instance(
    webViewEnvironment: webViewEnvironment,
  );

  static Future<void> syncStoredCookiesToWebView() async {
    final cookieHeader = LocalStorageService.instance.getCookie();
    if (cookieHeader == null || cookieHeader.trim().isEmpty) return;

    final cookies = _parseCookieHeader(cookieHeader);
    if (cookies.isEmpty) return;

    for (final entry in cookies.entries) {
      for (final origin in _wenku8Origins) {
        try {
          await _cookieManager.setCookie(
            url: WebUri(origin),
            name: entry.key,
            value: entry.value,
            path: '/',
            isSecure: origin.startsWith('https://'),
          );
        } catch (e) {
          Log.e('Sync Wenku8 cookie ${entry.key} to WebView failed: $e');
        }
      }
    }
    Log.d('HIKARI_WENKU8 synced ${cookies.length} stored cookies to WebView');
  }

  static Map<String, String> _parseCookieHeader(String value) {
    final result = <String, String>{};
    for (final part in value.split(';')) {
      final index = part.indexOf('=');
      if (index <= 0) continue;
      final name = part.substring(0, index).trim();
      final cookieValue = part.substring(index + 1).trim();
      if (name.isNotEmpty && cookieValue.isNotEmpty) {
        result[name] = cookieValue;
      }
    }
    return result;
  }

  static const _wenku8Origins = [
    'https://www.wenku8.cc',
    'https://www.wenku8.net',
    'http://www.wenku8.cc',
    'http://www.wenku8.net',
  ];
}
