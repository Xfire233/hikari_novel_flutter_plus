import 'dart:convert';
import 'dart:io' as io;

import 'package:cookie_jar/cookie_jar.dart' as ckjar;
import 'package:dio/dio.dart';
import 'package:enough_convert/enough_convert.dart';
import 'package:hikari_novel_flutter/models/custom_exception.dart';
import 'package:hikari_novel_flutter/models/resource.dart';
import 'package:hikari_novel_flutter/network/wenku8_cf_strategy.dart';

import '../common/log.dart';
import '../models/common/charsets_type.dart';
import '../service/browser_assisted_fetch_service.dart';
import '../service/local_storage_service.dart';

/// 网络请求
class Request {
  static const _wenku8NativeCompatibilityTimeout = Duration(seconds: 4);

  static const defaultUserAgent =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36 Edg/135.0.0.0";

  static String get userAgentValue =>
      LocalStorageService.instance.getWenku8UserAgent() ?? defaultUserAgent;

  static String? get webViewUserAgentOverride {
    final value = LocalStorageService.instance.getWenku8UserAgent();
    if (value == null || value.trim().isEmpty) return null;
    final trimmed = value.trim();
    if (io.Platform.isAndroid && _looksLikeDesktopUserAgent(trimmed)) {
      return null;
    }
    return trimmed;
  }

  static Map<String, String> get userAgent => {
    io.HttpHeaders.userAgentHeader: userAgentValue,
  };

  static final _dioCookieJar = ckjar.CookieJar();
  static final Dio dio = Dio(
    BaseOptions(
      headers: userAgent,
      responseType: ResponseType.bytes, //使用bytes获取原始数据，方便解码
      followRedirects: false, //使302重定向手动处理
      validateStatus: (status) => status != null, //只要不是 null，就交给拦截器处理,
    ),
  )..interceptors.add(CloudflareInterceptor());

  static final Dio manualCookieDio = Dio(
    BaseOptions(
      headers: userAgent,
      responseType: ResponseType.bytes,
      followRedirects: false,
      validateStatus: (status) => status != null,
    ),
  )..interceptors.add(CloudflareInterceptor());

  static void initCookie() {
    final localCookie = LocalStorageService.instance.getCookie();

    _dioCookieJar.deleteAll();
    if (localCookie == null) return;

    final cookies = <ckjar.Cookie>[];
    for (final item in localCookie.split(';').map((e) => e.trim())) {
      final index = item.indexOf('=');
      if (index <= 0) continue;
      final name = item.substring(0, index).trim();
      final value = item.substring(index + 1).trim();
      if (name.isEmpty || value.isEmpty) continue;
      try {
        cookies.add(ckjar.Cookie(name, value));
      } catch (e) {
        Log.e('Skip invalid stored Wenku8 cookie $name: $e');
      }
    }

    if (cookies.isEmpty) return;

    for (final host in _wenku8CookieHosts()) {
      _dioCookieJar.saveFromResponse(Uri.parse(host), cookies);
    }
  }

  static void deleteCookie() => _dioCookieJar.deleteAll();

  static Options _optionsForUrl(String url, {String? contentType}) {
    return Options(headers: _headersForUrl(url), contentType: contentType);
  }

  static Map<String, String> _headersForUrl(
    String url, [
    Map<String, String>? headers,
  ]) {
    final result = <String, String>{
      ...userAgent,
      if (headers != null) ...headers,
    };
    if (_isWenku8Url(url)) {
      final cookie = LocalStorageService.instance.getCookie();
      if (cookie != null && cookie.trim().isNotEmpty) {
        result[io.HttpHeaders.cookieHeader] = cookie;
      }
    }
    return result;
  }

  static Iterable<String> _wenku8CookieHosts() sync* {
    for (final host in const ['www.wenku8.cc', 'www.wenku8.net']) {
      yield 'https://$host';
      yield 'http://$host';
    }
  }

  ///获取通用数据（如其他网站的数据，即不用wenku8的cookie）
  /// - [url] 对应网站的url
  static Future<Resource> getCommonData(String url) async {
    try {
      final dio = Dio(BaseOptions(headers: userAgent));
      final response = await dio.get(url, options: _optionsForUrl(url));
      return Success(response.data);
    } catch (e) {
      return Error(e.toString());
    }
  }

  static Future<Resource> getUtf8(
    String url, {
    Map<String, String>? headers,
    bool useCookieJar = true,
  }) async {
    try {
      if (_isWenku8Url(url)) {
        _logWenku8(
          'request UTF-8 url=$url '
          'compat=${LocalStorageService.instance.getWenku8CompatibilityMode()} '
          'webViewUa=${webViewUserAgentOverride == null ? 'native' : 'stored'}',
        );
      }
      if (_shouldUseWenku8WebViewTransport(url)) {
        _logWenku8('compat UTF-8 request start url=$url');
        if (_isWenku8ReaderChapterUrl(url)) {
          final cachedHtml = BrowserAssistedFetchService.getCachedHtml(url);
          if (cachedHtml != null) {
            _logWenku8('compat UTF-8 chapter cache hit url=$url');
            return Success(cachedHtml);
          }
        }
        final html = await _fetchWenku8WithWebView(url);
        if (html != null) return Success(html);
        final cachedHtml = BrowserAssistedFetchService.getCachedHtml(url);
        if (cachedHtml != null) {
          _logWenku8('compat UTF-8 WebView failed, cache hit url=$url');
          return Success(cachedHtml);
        }
        final nativeHtml = await _tryWenku8NativeUtf8(url, headers: headers);
        if (nativeHtml != null) return Success(nativeHtml);
        Log.w('HIKARI_WENKU8 compat UTF-8 failed url=$url');
        return Error(_wenku8WebViewTransportFailureUserMessage(url));
      }
      final response = await (useCookieJar ? dio : manualCookieDio).get(
        url,
        options: Options(
          headers: _headersForUrl(url, headers),
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );
      final html = utf8.decode(response.data as List<int>);
      final invalidResult = _invalidWenku8HtmlResult(url, html);
      if (invalidResult != null) return invalidResult;
      BrowserAssistedFetchService.saveHtml(
        requestedUrl: url,
        currentUrl: response.realUri.toString(),
        html: html,
      );
      return Success(html);
    } catch (e) {
      final fallbackHtml = await _tryBrowserAssistedCacheFallback(url, e);
      if (fallbackHtml != null) {
        return Success(fallbackHtml);
      }
      final cachedHtml = _tryCachedHtmlFallback(url, e);
      if (cachedHtml != null) return Success(cachedHtml);
      Log.e(e.toString());
      return Error(_networkErrorUserMessage(url, e));
    }
  }

  static Future<String?> _tryBrowserAssistedCacheFallback(
    String url,
    Object error,
  ) async {
    if (!_isWenku8Url(url) || !_isCloudflareError(error)) {
      return null;
    }
    Log.d('Wenku8 request blocked by Cloudflare, checking assisted cache');
    for (final fallbackUrl in _wenku8WebViewFallbackUrls(url)) {
      final cachedHtml = BrowserAssistedFetchService.getCachedHtml(fallbackUrl);
      if (cachedHtml != null) {
        Log.d('Using browser assisted HTML cache for $fallbackUrl');
        return cachedHtml;
      }
    }
    return null;
  }

  static Future<String?> _fetchWenku8WithWebView(String url) async {
    _logWenku8('start WebView transport url=$url');
    return Wenku8CfStrategy.resolveHtml(url, allowCache: false);
  }

  static void _logWenku8(String message) {
    Log.d('HIKARI_WENKU8 $message');
  }

  static String? _tryCachedHtmlFallback(String url, Object error) {
    final cachedHtml = BrowserAssistedFetchService.getCachedHtml(url);
    if (cachedHtml == null) return null;
    Log.d('Using cached HTML fallback for $url after $error');
    return cachedHtml;
  }

  static Resource? _invalidWenku8HtmlResult(String url, String html) {
    if (!_isWenku8Url(url) ||
        BrowserAssistedFetchService.isUsableHtmlForUrl(url, html)) {
      return null;
    }
    final cachedHtml = BrowserAssistedFetchService.getCachedHtml(url);
    if (cachedHtml != null) {
      Log.d('Using cached HTML fallback for invalid Wenku8 response $url');
      return Success(cachedHtml);
    }
    Log.e('Invalid Wenku8 HTML for $url: ${_htmlPreview(html)}');
    return Error(_invalidWenku8HtmlUserMessage(html));
  }

  static String _invalidWenku8HtmlUserMessage(String html) {
    if (_isCloudflareChallengeHtml(html)) {
      return 'Wenku8 Cloudflare 验证未通过。请开启兼容性模式后重试。';
    }
    return 'Wenku8 返回了无法解析的页面。请重试；如果仍失败，请开启兼容性模式。';
  }

  static bool _isCloudflareChallengeHtml(String html) {
    final normalized = html.toLowerCase();
    return normalized.contains('cf-browser-verification') ||
        normalized.contains('cf_chl') ||
        normalized.contains('_cf_chl_opt') ||
        normalized.contains('__cf_chl_tk') ||
        normalized.contains('cf-mitigated') ||
        normalized.contains('cloudflare') ||
        normalized.contains('just a moment') ||
        normalized.contains('attention required') ||
        normalized.contains('access denied');
  }

  static String _htmlPreview(String html) {
    final compact = html.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 160) return compact;
    return compact.substring(0, 160);
  }

  static bool _isWenku8Url(String url) =>
      url.contains('wenku8.cc') || url.contains('wenku8.net');

  static bool _looksLikeDesktopUserAgent(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('windows nt') ||
        normalized.contains('macintosh') ||
        normalized.contains('x11');
  }

  static bool _shouldUseWenku8WebViewTransport(String url) =>
      _isWenku8Url(url) &&
      LocalStorageService.instance.getWenku8CompatibilityMode();

  static bool _isWenku8ReaderChapterUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return _isWenku8Url(url) &&
        uri.path.toLowerCase().endsWith('/modules/article/reader.php') &&
        (uri.queryParameters['cid']?.trim().isNotEmpty ?? false);
  }

  static List<String> _wenku8WebViewFallbackUrls(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return [url];

    return [uri.toString()];
  }

  static bool _isCloudflareError(Object error) {
    final message = error.toString();
    return message.contains(cloudflareChallengeExceptionMessage) ||
        message.contains(cloudflare403ExceptionMessage);
  }

  ///获取wenku8数据
  /// - [url] 对应的url
  /// - [charsetsType] response解码的方式
  static Future<Resource> get(
    String url, {
    required CharsetsType charsetsType,
    CancelToken? cancelToken,
  }) async {
    try {
      if (!url.contains("?")) url += "?";
      switch (charsetsType) {
        case CharsetsType.gbk:
          url += "&charset=gbk";
        case CharsetsType.big5Hkscs:
          url += "&charset=big5";
      }

      Log.d("$url ${charsetsType.name}");

      if (_isWenku8Url(url)) {
        _logWenku8(
          'request url=$url charset=${charsetsType.name} '
          'compat=${LocalStorageService.instance.getWenku8CompatibilityMode()} '
          'webViewUa=${webViewUserAgentOverride == null ? 'native' : 'stored'}',
        );
      }

      if (_shouldUseWenku8WebViewTransport(url)) {
        _logWenku8(
          'compat request start url=$url charset=${charsetsType.name}',
        );
        if (_isWenku8ReaderChapterUrl(url)) {
          final cachedHtml = BrowserAssistedFetchService.getCachedHtml(url);
          if (cachedHtml != null) {
            _logWenku8('compat chapter cache hit url=$url');
            return Success(cachedHtml);
          }
        }
        final html = await _fetchWenku8WithWebView(url);
        if (html != null) return Success(html);
        final cachedHtml = BrowserAssistedFetchService.getCachedHtml(url);
        if (cachedHtml != null) {
          _logWenku8('compat WebView failed, cache hit url=$url');
          return Success(cachedHtml);
        }
        final nativeHtml = await _tryWenku8NativeHtml(
          url,
          charsetsType: charsetsType,
          cancelToken: cancelToken,
        );
        if (nativeHtml != null) return Success(nativeHtml);
        Log.w('HIKARI_WENKU8 compat failed url=$url');
        return Error(_wenku8WebViewTransportFailureUserMessage(url));
      }

      final response = await dio.get(
        url,
        options: _optionsForUrl(url),
        cancelToken: cancelToken,
      );

      //检查是否有重定向
      final result = await _checkRedirects(response, cancelToken: cancelToken);

      final raw = result as List<int>;
      late String decodedHtml;
      switch (charsetsType) {
        case CharsetsType.gbk:
          decodedHtml = GbkDecoder().convert(raw);
        case CharsetsType.big5Hkscs:
          decodedHtml = Big5Decoder().convert(raw);
      }

      final invalidResult = _invalidWenku8HtmlResult(url, decodedHtml);
      if (invalidResult != null) return invalidResult;
      BrowserAssistedFetchService.saveHtml(
        requestedUrl: url,
        currentUrl: response.realUri.toString(),
        html: decodedHtml,
      );
      return Success(decodedHtml);
    } catch (e) {
      final fallbackHtml = await _tryBrowserAssistedCacheFallback(url, e);
      if (fallbackHtml != null) {
        return Success(fallbackHtml);
      }
      final cachedHtml = _tryCachedHtmlFallback(url, e);
      if (cachedHtml != null) return Success(cachedHtml);
      Log.e(e.toString());
      return Error(_networkErrorUserMessage(url, e));
    }
  }

  static Future<String?> _tryWenku8NativeUtf8(
    String url, {
    Map<String, String>? headers,
  }) async {
    if (!_isWenku8Url(url)) return null;
    try {
      final response = await dio
          .get(
            url,
            options: Options(
              headers: _headersForUrl(url, headers),
              responseType: ResponseType.bytes,
              followRedirects: true,
            ),
          )
          .timeout(_wenku8NativeCompatibilityTimeout);
      final html = utf8.decode(response.data as List<int>);
      if (!BrowserAssistedFetchService.isUsableHtmlForUrl(url, html)) {
        Log.d('Wenku8 native Dio UTF-8 response is not usable for $url');
        return null;
      }
      BrowserAssistedFetchService.saveHtml(
        requestedUrl: url,
        currentUrl: response.realUri.toString(),
        html: html,
      );
      Log.d('Using Wenku8 native Dio UTF-8 response for $url');
      _logWenku8('native UTF-8 success url=$url length=${html.length}');
      return html;
    } catch (e) {
      _logWenku8('native UTF-8 failed url=$url error=$e');
      return null;
    }
  }

  static Future<String?> _tryWenku8NativeHtml(
    String url, {
    required CharsetsType charsetsType,
    CancelToken? cancelToken,
  }) async {
    if (!_isWenku8Url(url)) return null;
    try {
      final response = await dio
          .get(url, options: _optionsForUrl(url), cancelToken: cancelToken)
          .timeout(_wenku8NativeCompatibilityTimeout);
      final result = await _checkRedirects(response, cancelToken: cancelToken);
      final raw = result as List<int>;
      final decodedHtml = switch (charsetsType) {
        CharsetsType.gbk => GbkDecoder().convert(raw),
        CharsetsType.big5Hkscs => Big5Decoder().convert(raw),
      };
      if (!BrowserAssistedFetchService.isUsableHtmlForUrl(url, decodedHtml)) {
        _logWenku8(
          'native unusable url=$url status=${response.statusCode} '
          'length=${decodedHtml.length} preview=${_htmlPreview(decodedHtml)}',
        );
        return null;
      }
      BrowserAssistedFetchService.saveHtml(
        requestedUrl: url,
        currentUrl: response.realUri.toString(),
        html: decodedHtml,
      );
      Log.d('Using Wenku8 native Dio response for $url');
      _logWenku8(
        'native success url=$url status=${response.statusCode} '
        'length=${decodedHtml.length}',
      );
      return decodedHtml;
    } catch (e) {
      _logWenku8('native failed url=$url error=$e');
      return null;
    }
  }

  static String _networkErrorMessage(String url, Object error) {
    if (_isWenku8Url(url) && _isCloudflareError(error)) {
      return 'Wenku8 Cloudflare 验证未通过。请通过网页登录或浏览器辅助捕获页面后重试。';
    }
    return error.toString();
  }

  static String _networkErrorUserMessage(String url, Object error) {
    if (_isWenku8Url(url) && _isCloudflareError(error)) {
      return 'Wenku8 Cloudflare 验证未通过。请开启兼容性模式后重试。';
    }
    return _networkErrorMessage(url, error);
  }

  static String _wenku8WebViewTransportFailureUserMessage(String url) =>
      'Wenku8 兼容模式加载失败。请重试；如果反复失败，请截图反馈下面的错误信息。\n'
      'URL: $url\n'
      'WebView: ${Wenku8CfStrategy.lastStatus}';

  /// 检查Response包中是否要求重定向
  /// - [response] 要检查的Response包
  static Future<dynamic> _checkRedirects(
    Response response, {
    int depth = 0,
    CancelToken? cancelToken,
  }) async {
    if (response.statusCode != null &&
        response.statusCode! >= 300 &&
        response.statusCode! < 400) {
      if (depth >= 5) return response.data;
      final location = response.headers.value('location');
      if (location != null) {
        final redirectUrl = response.requestOptions.uri
            .resolve(location)
            .toString();
        final redirectedResponse = await dio
            .get(
              redirectUrl,
              options: _optionsForUrl(redirectUrl),
              cancelToken: cancelToken,
            )
            .timeout(_wenku8NativeCompatibilityTimeout);
        return _checkRedirects(
          redirectedResponse,
          depth: depth + 1,
          cancelToken: cancelToken,
        );
      }
    }
    return response.data;
  }

  /// 以post方法进行http请求
  /// body以Content-Type: application/x-www-form-urlencoded的形式进行发送
  /// - [url] 要请求的url
  /// - [data] 此post请求的body，当body中含有url编码的内容时，需要使用String类型而非Map类型！目前不知道是什么原因，可能是因为dio的二次编码？
  /// - [charsetsType] response解码的方式
  static Future<Resource> postForm(
    String url, {
    required Object? data,
    required CharsetsType charsetsType,
  }) async {
    try {
      final response = await dio.post(
        url,
        data: data,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ), //设置为application/x-www-form-urlencoded
      );
      String decodedHtml;
      switch (charsetsType) {
        case CharsetsType.gbk:
          {
            decodedHtml = GbkCodec().decode(response.data as List<int>);
          }
        case CharsetsType.big5Hkscs:
          {
            decodedHtml = Big5Codec().decode(response.data as List<int>);
          }
      }
      return Success(decodedHtml);
    } catch (e) {
      Log.e(e.toString());
      return Error(e.toString());
    }
  }
}

class CloudflareInterceptor extends Interceptor {
  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    final statusCode = response.statusCode;
    if (statusCode == 403) {
      handler.reject(
        Cloudflare403Exception(requestOptions: response.requestOptions),
      );
      return;
    }

    final cfMitigated = response.headers['cf-mitigated'];
    if (cfMitigated == null || !cfMitigated.contains('challenge')) {
      handler.next(response);
      return;
    }
    handler.reject(
      CloudflareChallengeException(requestOptions: response.requestOptions),
    );
  }
}
