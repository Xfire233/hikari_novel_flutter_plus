import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:cookie_jar/cookie_jar.dart' as ckjar;
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:enough_convert/enough_convert.dart';
import 'package:hikari_novel_flutter/models/common/wenku8_node.dart';
import 'package:hikari_novel_flutter/models/custom_exception.dart';
import 'package:hikari_novel_flutter/models/resource.dart';
import 'package:hikari_novel_flutter/network/wenku8_webview_fetcher.dart';

import '../common/log.dart';
import '../models/common/charsets_type.dart';
import '../service/browser_assisted_fetch_service.dart';
import '../service/local_storage_service.dart';

/// 网络请求
class Request {
  static const userAgent = {
    io.HttpHeaders.userAgentHeader:
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36 Edg/135.0.0.0",
  };

  static final _dioCookieJar = ckjar.CookieJar();
  static final Dio dio =
      Dio(
          BaseOptions(
            headers: userAgent,
            responseType: ResponseType.bytes, //使用bytes获取原始数据，方便解码
            followRedirects: false, //使302重定向手动处理
            validateStatus: (status) => status != null, //只要不是 null，就交给拦截器处理,
          ),
        )
        ..interceptors.add(CloudflareInterceptor())
        ..interceptors.add(CookieManager(_dioCookieJar));

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

    if (localCookie == null) return;

    final cookies = localCookie
        .split(';')
        .map((e) => e.trim())
        .where((e) => e.contains('='))
        .map((e) {
          final kv = e.split('=');
          return ckjar.Cookie(kv[0], kv.sublist(1).join('='));
        })
        .toList();

    _dioCookieJar.saveFromResponse(
      Uri.parse(Wenku8Node.wwwWenku8Cc.node),
      cookies,
    );
    _dioCookieJar.saveFromResponse(
      Uri.parse(Wenku8Node.wwwWenku8Net.node),
      cookies,
    );
  }

  static void deleteCookie() => _dioCookieJar.deleteAll();

  ///获取通用数据（如其他网站的数据，即不用wenku8的cookie）
  /// - [url] 对应网站的url
  static Future<Resource> getCommonData(String url) async {
    try {
      final dio = Dio(BaseOptions(headers: userAgent));
      final response = await dio.get(url);
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
      final response = await (useCookieJar ? dio : manualCookieDio).get(
        url,
        options: Options(
          headers: headers,
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );
      final html = utf8.decode(response.data as List<int>);
      BrowserAssistedFetchService.saveHtml(
        requestedUrl: url,
        currentUrl: response.realUri.toString(),
        html: html,
      );
      return Success(html);
    } catch (e) {
      final fallbackHtml = await _tryWenku8WebViewFallback(url, e);
      if (fallbackHtml != null) {
        return Success(fallbackHtml);
      }
      final cachedHtml = _tryCachedHtmlFallback(url, e);
      if (cachedHtml != null) return Success(cachedHtml);
      Log.e(e.toString());
      return Error(e.toString());
    }
  }

  static Future<String?> _tryWenku8WebViewFallback(
    String url,
    Object error,
  ) async {
    if (!_isWenku8Url(url) || !_isCloudflareError(error)) {
      return null;
    }
    Log.d('Wenku8 request blocked by Cloudflare, trying WebView fallback');
    for (final fallbackUrl in _wenku8WebViewFallbackUrls(url)) {
      final cachedHtml = BrowserAssistedFetchService.getCachedHtml(fallbackUrl);
      if (cachedHtml != null) {
        Log.d('Using browser assisted HTML cache for $fallbackUrl');
        return cachedHtml;
      }
      if (!_shouldUseHeadlessWenku8Fallback(fallbackUrl)) {
        continue;
      }
      final html = await Wenku8WebViewFetcher.get(fallbackUrl);
      if (html != null) return html;
    }
    return null;
  }

  static String? _tryCachedHtmlFallback(String url, Object error) {
    final cachedHtml = BrowserAssistedFetchService.getCachedHtml(url);
    if (cachedHtml == null) return null;
    Log.d('Using cached HTML fallback for $url after $error');
    return cachedHtml;
  }

  static bool _isWenku8Url(String url) =>
      url.contains('wenku8.cc') || url.contains('wenku8.net');

  static bool _shouldUseHeadlessWenku8Fallback(String url) {
    final uri = Uri.tryParse(url);
    final path = uri?.path;
    if (path == null) return true;
    return !path.endsWith('/modules/article/tags.php') &&
        !path.endsWith('/modules/article/toplist.php') &&
        !path.endsWith('/modules/article/articlelist.php');
  }

  static List<String> _wenku8WebViewFallbackUrls(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return [url];

    final result = <String>[];
    final aid = RegExp(r'(?:[?&])id=([^&]+)').firstMatch(url)?.group(1);
    if (uri.path.endsWith('/modules/article/articleinfo.php') &&
        aid != null &&
        aid.isNotEmpty) {
      final staticUri = Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
        path: '/book/$aid.htm',
      );
      result.add(staticUri.toString().replaceFirst('wenku8.cc', 'wenku8.net'));
      result.add(staticUri.toString());
    }

    if (url.contains('wenku8.cc')) {
      result.add(url.replaceFirst('wenku8.cc', 'wenku8.net'));
    }
    result.add(url);
    return result.toSet().toList(growable: false);
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

      final response = await dio.get(url);

      //检查是否有重定向
      final result = await _checkRedirects(response);

      final raw = result as List<int>;
      late String decodedHtml;
      switch (charsetsType) {
        case CharsetsType.gbk:
          decodedHtml = GbkDecoder().convert(raw);
        case CharsetsType.big5Hkscs:
          decodedHtml = Big5Decoder().convert(raw);
      }

      BrowserAssistedFetchService.saveHtml(
        requestedUrl: url,
        currentUrl: response.realUri.toString(),
        html: decodedHtml,
      );
      return Success(decodedHtml);
    } catch (e) {
      final fallbackHtml = await _tryWenku8WebViewFallback(url, e);
      if (fallbackHtml != null) {
        return Success(fallbackHtml);
      }
      final cachedHtml = _tryCachedHtmlFallback(url, e);
      if (cachedHtml != null) return Success(cachedHtml);
      Log.e(e.toString());
      return Error(e.toString());
    }
  }

  /// 检查Response包中是否要求重定向
  /// - [response] 要检查的Response包
  static Future<dynamic> _checkRedirects(
    Response response, {
    int depth = 0,
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
        final redirectedResponse = await dio.get(redirectUrl);
        return _checkRedirects(redirectedResponse, depth: depth + 1);
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
