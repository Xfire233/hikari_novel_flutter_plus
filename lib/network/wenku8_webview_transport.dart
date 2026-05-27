import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hikari_novel_flutter/common/log.dart';
import 'package:hikari_novel_flutter/service/browser_assisted_fetch_service.dart';
import 'package:hikari_novel_flutter/service/wenku8_webview_cookie_sync_service.dart';

class Wenku8WebViewTransport {
  const Wenku8WebViewTransport._();

  static final hostRequired = ValueNotifier<bool>(false);
  static final hostActive = ValueNotifier<bool>(false);
  static InAppWebViewController? _controller;
  static Completer<InAppWebViewController>? _readyCompleter;
  static Future<void> _queue = Future<void>.value();
  static _WebViewTransportTask? _activeTask;
  static Timer? _idleTimer;
  static String _lastStatus = 'idle';

  static bool get hasController => _controller != null;
  static String get lastStatus => _lastStatus;

  static void setHostEnabled(bool enabled) {
    if (enabled) {
      ensureHost();
    } else {
      releaseHost();
    }
  }

  static void ensureHost() {
    if (!hostRequired.value) {
      hostRequired.value = true;
    }
  }

  static void releaseHost() {
    _idleTimer?.cancel();
    _idleTimer = null;
    _setHostActive(false);
    final task = _activeTask;
    if (task != null && !task.isCompleted) {
      task.isCompleted = true;
      task.timer.cancel();
      if (!task.completer.isCompleted) {
        task.completer.complete(null);
      }
    }
    _activeTask = null;
    final controller = _controller;
    _controller = null;
    _readyCompleter = null;
    _setStatus('released');
    if (hostRequired.value) {
      hostRequired.value = false;
    }
    if (controller != null) {
      unawaited(_stopAndBlank(controller));
    }
  }

  static void attach(InAppWebViewController controller) {
    if (!hostRequired.value) {
      unawaited(_stopAndBlank(controller));
      return;
    }
    _idleTimer?.cancel();
    _controller = controller;
    final ready = _readyCompleter;
    if (ready != null && !ready.isCompleted) {
      ready.complete(controller);
    }
    _log('attached');
  }

  static void detach(InAppWebViewController controller) {
    if (identical(_controller, controller)) {
      _controller = null;
      _readyCompleter = null;
    }
  }

  static Future<void> _stopAndBlank(InAppWebViewController controller) async {
    try {
      await controller.stopLoading().timeout(const Duration(milliseconds: 500));
    } catch (_) {}
    try {
      await controller
          .loadUrl(urlRequest: URLRequest(url: WebUri('about:blank')))
          .timeout(const Duration(milliseconds: 800));
    } catch (_) {}
  }

  static void notifyLoadProgress(
    InAppWebViewController controller,
    int progress,
  ) {
    if (!identical(_controller, controller) || progress < 100) return;
    _readActiveHtml(controller);
  }

  static void notifyLoadStart(InAppWebViewController controller, WebUri? uri) {
    if (!identical(_controller, controller)) return;
    _log('load start event uri=${uri ?? ''}');
  }

  static void notifyLoadStop(InAppWebViewController controller, WebUri? uri) {
    if (!identical(_controller, controller)) return;
    final task = _activeTask;
    if (task == null || task.isCompleted) return;
    _log('load stop uri=${uri ?? ''}');
    _readActiveHtml(controller);
  }

  static void notifyLoadError(InAppWebViewController controller, Object error) {
    if (!identical(_controller, controller)) return;
    _log('load error error=$error');
  }

  static Future<String?> get(
    String url, {
    Duration timeout = const Duration(seconds: 9),
  }) {
    _idleTimer?.cancel();
    ensureHost();
    late Future<String?> next;
    final queueTimeout = timeout + const Duration(seconds: 4);
    next = _queue
        .timeout(queueTimeout, onTimeout: () {})
        .then((_) => _loadAndRead(url, timeout: timeout))
        .whenComplete(_scheduleIdleRelease);
    _queue = next
        .timeout(queueTimeout, onTimeout: () => null)
        .catchError((_) => null)
        .then((_) {});
    return next;
  }

  static Future<String?> _loadAndRead(
    String url, {
    required Duration timeout,
  }) async {
    final controller = await _waitForController(
      timeout: const Duration(seconds: 10),
    );
    if (controller == null) {
      _log('not ready url=$url hostRequired=${hostRequired.value}');
      return null;
    }
    _setHostActive(true);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await Wenku8WebViewCookieSyncService.syncStoredCookiesToWebView();

    final task = _WebViewTransportTask(
      url: url,
      timer: Timer(timeout, () {
        _completeActiveTask(url, null, reason: 'timeout');
      }),
    );
    _activeTask = task;

    final beforeUrl = await _currentUrl(controller);
    _log('load requested url=$url before=${beforeUrl ?? ''}');
    await _clearCurrentDomBeforeNavigation(controller);
    unawaited(_pollActiveHtml(controller, task));
    await _loadUrlWithVerification(controller, task, url);

    return task.completer.future.timeout(
      timeout + const Duration(seconds: 2),
      onTimeout: () {
        _completeActiveTask(url, null, reason: 'outer timeout');
        return null;
      },
    );
  }

  static Future<void> _loadUrlWithVerification(
    InAppWebViewController controller,
    _WebViewTransportTask task,
    String url,
  ) async {
    for (var attempt = 1; attempt <= 2; attempt++) {
      if (task.isCompleted || !identical(_activeTask, task)) return;
      try {
        _log('loadUrl attempt=$attempt url=$url');
        await controller
            .loadUrl(urlRequest: URLRequest(url: WebUri(url)))
            .timeout(const Duration(seconds: 6));
      } catch (e) {
        _log('loadUrl failed attempt=$attempt url=$url error=$e');
      }

      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (task.isCompleted || !identical(_activeTask, task)) return;

      final current = await _currentUrl(controller);
      _log(
        'loadUrl check attempt=$attempt target=$url current=${current ?? ''}',
      );
      if (_sameUrlWithoutFragment(current, url)) return;
    }
  }

  static Future<String?> _currentUrl(InAppWebViewController controller) {
    return controller
        .getUrl()
        .then((value) => value?.toString())
        .timeout(const Duration(seconds: 1), onTimeout: () => null);
  }

  static Future<void> _clearCurrentDomBeforeNavigation(
    InAppWebViewController controller,
  ) async {
    try {
      await controller
          .evaluateJavascript(
            source: '''
          if (document && document.documentElement) {
            document.documentElement.innerHTML =
              '<head></head><body data-hikari-loading="1"></body>';
          }
        ''',
          )
          .timeout(const Duration(milliseconds: 700));
    } catch (e) {
      _log('clear dom before load ignored error=$e');
    }
  }

  static bool _sameUrlWithoutFragment(String? left, String right) {
    if (left == null || left.isEmpty) return false;
    final l = Uri.tryParse(left);
    final r = Uri.tryParse(right);
    if (l == null || r == null) return left == right;
    return l.replace(fragment: '').toString() ==
        r.replace(fragment: '').toString();
  }

  static bool _isExpectedCurrentUrl(String requested, String current) {
    if (_sameUrlWithoutFragment(current, requested)) return true;
    final requestedUri = Uri.tryParse(requested);
    final currentUri = Uri.tryParse(current);
    if (requestedUri == null || currentUri == null) return false;
    if (!_isWenku8Host(requestedUri.host) || !_isWenku8Host(currentUri.host)) {
      return false;
    }
    if (_samePathAndQueryIgnoringCharset(requestedUri, currentUri)) return true;

    final requestedArticle = _articleInfoAid(requestedUri);
    final currentBook = _bookAid(currentUri);
    if (requestedArticle != null && requestedArticle == currentBook) {
      return true;
    }

    final requestedReader = _readerRequest(requestedUri);
    final currentStaticReader = _staticReader(currentUri);
    if (requestedReader == null || currentStaticReader == null) return false;
    if (requestedReader.aid != currentStaticReader.aid) return false;
    final requestedCid = requestedReader.cid;
    final currentCid = currentStaticReader.cid;
    if (requestedCid == null || requestedCid.isEmpty) {
      return currentCid == null || currentCid.isEmpty;
    }
    return requestedCid == currentCid;
  }

  static bool _needsCurrentUrlBinding(String requested) {
    final uri = Uri.tryParse(requested);
    return uri?.path.toLowerCase().endsWith('/modules/article/reader.php') ==
        true;
  }

  static bool _isWenku8Host(String host) {
    final normalized = host.toLowerCase();
    return normalized.endsWith('wenku8.cc') ||
        normalized.endsWith('wenku8.net');
  }

  static bool _samePathAndQueryIgnoringCharset(Uri left, Uri right) {
    if (left.path != right.path) return false;
    final leftQuery = _rawQueryParameters(left)..remove('charset');
    final rightQuery = _rawQueryParameters(right)..remove('charset');
    return leftQuery.length == rightQuery.length &&
        leftQuery.entries.every(
          (entry) => rightQuery[entry.key] == entry.value,
        );
  }

  static Map<String, String> _rawQueryParameters(Uri uri) {
    final result = <String, String>{};
    for (final part in uri.query.split('&')) {
      if (part.isEmpty) continue;
      final separator = part.indexOf('=');
      final key = separator == -1 ? part : part.substring(0, separator);
      if (key.isEmpty) continue;
      result[key] = separator == -1 ? '' : part.substring(separator + 1);
    }
    return result;
  }

  static String? _articleInfoAid(Uri uri) {
    if (!uri.path.toLowerCase().endsWith('/modules/article/articleinfo.php')) {
      return null;
    }
    return uri.queryParameters['id']?.trim();
  }

  static String? _bookAid(Uri uri) {
    return RegExp(
      r'^/book/(\d+)\.htm$',
    ).firstMatch(uri.path.toLowerCase())?.group(1);
  }

  static _Wenku8ReaderRequest? _readerRequest(Uri uri) {
    if (!uri.path.toLowerCase().endsWith('/modules/article/reader.php')) {
      return null;
    }
    final aid = uri.queryParameters['aid']?.trim();
    if (aid == null || aid.isEmpty) return null;
    return _Wenku8ReaderRequest(aid: aid, cid: uri.queryParameters['cid']);
  }

  static _Wenku8ReaderRequest? _staticReader(Uri uri) {
    final match = RegExp(
      r'^/novel/\d+/(\d+)/(?:$|index\.htm$|(\d+)\.htm$)',
    ).firstMatch(uri.path.toLowerCase());
    if (match == null) return null;
    return _Wenku8ReaderRequest(aid: match.group(1)!, cid: match.group(2));
  }

  static Future<InAppWebViewController?> _waitForController({
    required Duration timeout,
  }) async {
    final existing = _controller;
    if (existing != null) return existing;
    final completer = _readyCompleter ??= Completer<InAppWebViewController>();
    try {
      return await completer.future.timeout(timeout);
    } catch (_) {
      return null;
    }
  }

  static void _readActiveHtml(InAppWebViewController controller) {
    final task = _activeTask;
    if (task == null || task.isCompleted || task.isReading) return;
    task.isReading = true;
    unawaited(_readActiveHtmlAsync(controller, task));
  }

  static Future<void> _pollActiveHtml(
    InAppWebViewController controller,
    _WebViewTransportTask task,
  ) async {
    while (!task.isCompleted && identical(_activeTask, task)) {
      _readActiveHtml(controller);
      await Future<void>.delayed(const Duration(milliseconds: 900));
    }
  }

  static Future<void> _readActiveHtmlAsync(
    InAppWebViewController controller,
    _WebViewTransportTask task,
  ) async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (task.isCompleted || !identical(_activeTask, task)) return;
      final currentUrl = await controller.getUrl().timeout(
        const Duration(seconds: 1),
        onTimeout: () => null,
      );
      final html = await controller
          .evaluateJavascript(source: 'document.documentElement.outerHTML')
          .timeout(const Duration(seconds: 2));
      final current = currentUrl?.toString();
      if (html is String) {
        task.lastCurrent = current;
        task.lastLength = html.length;
        task.lastPreview = _htmlPreview(html);
      }
      if (html is String) {
        final redirectUrl =
            BrowserAssistedFetchService.wenku8ReaderCatalogueRedirectUrl(
              requestedUrl: task.url,
              currentUrl: current,
              html: html,
            );
        if (redirectUrl != null && task.registerRedirect(redirectUrl)) {
          _log(
            'follow catalogue redirect requested=${task.url} '
            'current=${current ?? ''} target=$redirectUrl',
          );
          unawaited(
            controller.loadUrl(
              urlRequest: URLRequest(url: WebUri(redirectUrl)),
            ),
          );
          return;
        }
      }
      final needsCurrentUrlBinding = _needsCurrentUrlBinding(task.url);
      final expectedCurrent =
          current != null && _isExpectedCurrentUrl(task.url, current);
      final usableForRequested =
          html is String &&
          (!needsCurrentUrlBinding || expectedCurrent) &&
          BrowserAssistedFetchService.isUsableHtmlForUrl(task.url, html);
      final usableForCurrent =
          html is String &&
          current != null &&
          (!needsCurrentUrlBinding || expectedCurrent) &&
          BrowserAssistedFetchService.isUsableHtmlForUrl(current, html);
      if (usableForRequested || usableForCurrent) {
        _log(
          'usable html requested=${task.url} current=${current ?? ''} '
          'usableForRequested=$usableForRequested '
          'usableForCurrent=$usableForCurrent length=${html.length}',
        );
        _completeActiveTask(task.url, html, reason: 'usable html');
      } else if (html is String &&
          current != null &&
          needsCurrentUrlBinding &&
          !expectedCurrent &&
          BrowserAssistedFetchService.isUsableHtmlForUrl(current, html)) {
        if (!task.loggedUnexpectedCurrent) {
          task.loggedUnexpectedCurrent = true;
          Log.w(
            'HIKARI_WENKU8 persistent rejected unexpected current page '
            'requested=${task.url} current=$current length=${html.length} '
            'preview=${_htmlPreview(html)}',
          );
        }
      } else if (kDebugMode && html is String) {
        _log(
          'html not usable requested=${task.url} current=${current ?? ''} '
          'length=${html.length} preview=${_htmlPreview(html)}',
        );
      } else if (kDebugMode) {
        _log('non-string html requested=${task.url} type=${html.runtimeType}');
      }
    } catch (e) {
      _log('read failed requested=${task.url} error=$e');
    } finally {
      task.isReading = false;
    }
  }

  static void _completeActiveTask(
    String url,
    String? html, {
    required String reason,
  }) {
    final task = _activeTask;
    if (task == null || task.url != url || task.isCompleted) return;
    task.isCompleted = true;
    task.timer.cancel();
    _activeTask = null;
    _setHostActive(false);
    if (html == null) {
      _setStatus(
        'complete null url=$url reason=$reason '
        'current=${task.lastCurrent ?? ''} '
        'length=${task.lastLength ?? -1} '
        'preview=${task.lastPreview ?? ''}',
      );
      Log.d('HIKARI_WENKU8 persistent $_lastStatus');
    } else {
      _log('complete success url=$url reason=$reason length=${html.length}');
    }
    if (!task.completer.isCompleted) {
      task.completer.complete(html);
    }
  }

  static String _htmlPreview(String html) {
    final compact = html.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 140) return compact;
    return compact.substring(0, 140);
  }

  static void _log(String message) {
    _setStatus(message);
    Log.d('HIKARI_WENKU8 persistent $message');
  }

  static void _setStatus(String message) {
    _lastStatus = message;
  }

  static void _setHostActive(bool active) {
    if (hostActive.value != active) {
      hostActive.value = active;
    }
  }

  static void _scheduleIdleRelease() {
    _idleTimer?.cancel();
    if (_activeTask != null) return;
    _idleTimer = Timer(const Duration(seconds: 20), () {
      if (_activeTask == null) releaseHost();
    });
  }
}

class _WebViewTransportTask {
  _WebViewTransportTask({required this.url, required this.timer});

  final String url;
  final Timer timer;
  final completer = Completer<String?>();
  bool isCompleted = false;
  bool isReading = false;
  bool loggedUnexpectedCurrent = false;
  final followedRedirects = <String>{};
  String? lastCurrent;
  int? lastLength;
  String? lastPreview;

  bool registerRedirect(String url) {
    if (followedRedirects.length >= 3) return false;
    return followedRedirects.add(url);
  }
}

class _Wenku8ReaderRequest {
  const _Wenku8ReaderRequest({required this.aid, required this.cid});

  final String aid;
  final String? cid;
}
