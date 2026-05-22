import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hikari_novel_flutter/common/log.dart';
import 'package:hikari_novel_flutter/service/browser_assisted_fetch_service.dart';

class Wenku8WebViewFetcher {
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36 Edg/135.0.0.0';

  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isWindows);

  static Future<String?> get(
    String url, {
    Duration timeout = const Duration(seconds: 35),
  }) async {
    if (!isSupported) return null;

    final completer = Completer<String?>();
    HeadlessInAppWebView? webView;
    var isCompleted = false;

    Future<void> complete(String? html) async {
      if (isCompleted) return;
      isCompleted = true;
      if (!completer.isCompleted) {
        completer.complete(html);
      }
      try {
        await webView?.dispose();
      } catch (e) {
        Log.e('Wenku8 WebView fallback dispose failed: $e');
      }
    }

    Future<void> readHtml(InAppWebViewController controller) async {
      if (isCompleted) return;
      try {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (isCompleted) return;
        final html = await controller.evaluateJavascript(
          source: 'document.documentElement.outerHTML',
        );
        if (html is String && BrowserAssistedFetchService.isUsableHtml(html)) {
          await complete(html);
        }
      } catch (e) {
        Log.e('Wenku8 WebView fallback read failed: $e');
      }
    }

    webView = HeadlessInAppWebView(
      initialSize: const Size(390, 844),
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        userAgent: _userAgent,
        isInspectable: kDebugMode,
        cacheEnabled: true,
        clearCache: false,
        transparentBackground: true,
      ),
      onLoadStop: (controller, uri) async {
        if (uri == null || !_isWenku8Url(uri.toString())) return;
        await readHtml(controller);
      },
      onProgressChanged: (controller, progress) async {
        if (progress >= 100) {
          await readHtml(controller);
        }
      },
      onReceivedError: (controller, request, error) {
        if (request.isForMainFrame == true) {
          Log.d('Wenku8 WebView fallback error: ${error.description}');
        }
      },
      onReceivedHttpError: (controller, request, errorResponse) {
        if (request.isForMainFrame == true) {
          Log.d(
            'Wenku8 WebView fallback HTTP error: '
            '${errorResponse.statusCode}',
          );
        }
      },
    );

    try {
      await webView.run();
      return await completer.future.timeout(
        timeout,
        onTimeout: () async {
          await complete(null);
          return null;
        },
      );
    } catch (e) {
      Log.e('Wenku8 WebView fallback failed: $e');
      await complete(null);
      return null;
    }
  }

  static bool _isWenku8Url(String url) =>
      url.contains('wenku8.cc') || url.contains('wenku8.net');
}
