import 'package:hikari_novel_flutter/common/log.dart';
import 'package:hikari_novel_flutter/network/wenku8_webview_transport.dart';
import 'package:hikari_novel_flutter/service/browser_assisted_fetch_service.dart';

class Wenku8CfStrategy {
  const Wenku8CfStrategy._();

  static String get lastStatus => Wenku8WebViewTransport.lastStatus;

  static Future<String?> resolveHtml(
    String url, {
    bool allowCache = true,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    _log('resolve start url=$url allowCache=$allowCache');
    if (allowCache) {
      final cached = BrowserAssistedFetchService.getCachedHtml(url);
      if (cached != null) {
        _log('cache hit url=$url length=${cached.length}');
        return cached;
      }
    }

    final persistentHtml =
        await Wenku8WebViewTransport.get(url, timeout: timeout).timeout(
          timeout + const Duration(seconds: 4),
          onTimeout: () {
            final msg =
                'Wenku8 persistent WebView transport timed out for $url';
            Log.e(msg);
            return null;
          },
        );
    if (persistentHtml != null) {
      _log('persistent success url=$url length=${persistentHtml.length}');
      BrowserAssistedFetchService.saveHtml(
        requestedUrl: url,
        currentUrl: url,
        html: persistentHtml,
      );
      return persistentHtml;
    }

    _log('resolve failed url=$url');
    return null;
  }

  static void _log(String message) {
    Log.d('HIKARI_WENKU8 strategy $message');
  }
}
