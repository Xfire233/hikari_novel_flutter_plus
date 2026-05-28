import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/main.dart';
import 'package:hikari_novel_flutter/models/common/wenku8_node.dart';
import 'package:hikari_novel_flutter/models/page_state.dart';
import 'package:hikari_novel_flutter/models/source_config.dart';
import 'package:hikari_novel_flutter/models/source_login_result.dart';
import 'package:hikari_novel_flutter/network/request.dart';
import 'package:hikari_novel_flutter/service/source_config_service.dart';
import 'package:hikari_novel_flutter/service/wenku8_webview_cookie_sync_service.dart';
import 'package:hikari_novel_flutter/widgets/state_page.dart';

import '../../common/log.dart';
import '../../models/resource.dart';
import '../../network/api.dart';
import '../../network/parser.dart';
import '../../service/local_storage_service.dart';

class LoginController extends GetxController {
  RxBool showLoading = true.obs;
  RxInt loadingProgress = 0.obs;
  final CookieManager cookieManager = CookieManager.instance(
    webViewEnvironment: webViewEnvironment,
  );
  InAppWebViewController? inAppWebViewController;
  final GlobalKey webViewKey = GlobalKey();
  final InAppWebViewSettings settings = InAppWebViewSettings(
    isInspectable: kDebugMode,
    userAgent: Request.webViewUserAgentOverride,
    javaScriptEnabled: true,
    loadsImagesAutomatically: true,
    mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
  );
  RxString currentUrl = "".obs;

  Rx<PageState> pageState = PageState.success.obs;
  String errorMsg = "";
  bool _handlingLogin = false;
  bool _initialLoadStarted = false;
  late final bool accountMode;
  late final bool autoCloseOnLogin;
  late final String initialUrl;

  String get url => initialUrl;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    accountMode = args is Map && args['accountMode'] == true;
    autoCloseOnLogin = args is Map && args['autoCloseOnLogin'] == true;
    final argUrl = args is Map ? '${args['initialUrl'] ?? ''}' : '';
    initialUrl = argUrl.isNotEmpty
        ? argUrl
        : "${Api.wenku8Node.node}/login.php";
  }

  Future<void> attachWebView(InAppWebViewController webController) async {
    inAppWebViewController = webController;
    if (_initialLoadStarted) return;
    _initialLoadStarted = true;
    if (accountMode) {
      await Wenku8WebViewCookieSyncService.syncStoredCookiesToWebView();
    } else {
      await cookieManager.deleteAllCookies();
    }
    await webController.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  Future<void> relogin() async {
    await cookieManager.deleteAllCookies();
    LocalStorageService.instance.setCookie(null);
    Request.deleteCookie();
    final loginUrl = '${Api.wenku8Node.node}/login.php';
    currentUrl.value = loginUrl;
    showLoading.value = true;
    loadingProgress.value = 0;
    await inAppWebViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(loginUrl)),
    );
  }

  Future<void> handlePageLoaded(WebUri uri) async {
    showLoading.value = false;

    if (!uri.toString().contains("wenku8") || _handlingLogin) {
      return;
    }
    if (autoCloseOnLogin) {
      await _autoReturnIfLoggedIn(uri);
    }
  }

  bool shouldPatchLoginPage(WebUri? uri) =>
      uri?.path.toLowerCase().endsWith('/login.php') == true;

  Future<void> confirmLoginAndReturn() async {
    final current = await inAppWebViewController?.getUrl();
    final uri = current ?? WebUri(Api.wenku8Node.node);
    await _syncBrowserUserAgent();
    final cookie = await _buildWenku8BrowserCookie(
      uri,
      allowExistingLogin: accountMode,
    );
    if (cookie == null) {
      _showVerificationSnackBar('source_login_required');
      return;
    }

    _handlingLogin = true;
    LocalStorageService.instance.setCookie(cookie);
    SourceConfigService.instance.setSourceEnabled(NovelSource.wenku8, true);
    Request.initCookie();

    await _runPostLoginStep("refresh Wenku8 user info", _getUserInfo);

    Get.back(
      result: const SourceLoginResult(loggedIn: true, syncFavorites: true),
    );
  }

  Future<void> _autoReturnIfLoggedIn(WebUri uri) async {
    await _syncBrowserUserAgent();
    final cookie = await _buildWenku8BrowserCookie(
      uri,
      allowExistingLogin: true,
    );
    if (cookie == null || !_hasWenku8LoginCookie(cookie)) return;

    _handlingLogin = true;
    LocalStorageService.instance.setCookie(cookie);
    SourceConfigService.instance.setSourceEnabled(NovelSource.wenku8, true);
    Request.initCookie();

    await _runPostLoginStep("refresh Wenku8 user info", _getUserInfo);
    Get.back(
      result: const SourceLoginResult(loggedIn: true, syncFavorites: true),
    );
  }

  Future<void> syncOnlineFavorites() async {
    final current = await inAppWebViewController?.getUrl();
    final uri = current ?? WebUri(Api.wenku8Node.node);
    await _syncBrowserUserAgent();
    final cookie = await _buildWenku8BrowserCookie(
      uri,
      allowExistingLogin: true,
    );
    if (cookie == null || !_hasWenku8LoginCookie(cookie)) {
      _showVerificationSnackBar('source_login_required');
      return;
    }
    LocalStorageService.instance.setCookie(cookie);
    SourceConfigService.instance.setSourceEnabled(NovelSource.wenku8, true);
    Request.initCookie();
    await _runPostLoginStep("refresh Wenku8 user info", _getUserInfo);
    Get.back(
      result: const SourceLoginResult(loggedIn: true, syncFavorites: true),
    );
  }

  void _showVerificationSnackBar(String key) {
    _showMessageSnackBar(key.tr);
  }

  void _showMessageSnackBar(String message) {
    final context = Get.context;
    if (context == null) return;
    showSnackBar(message: message, context: context);
  }

  Future<void> _syncBrowserUserAgent() async {
    final controller = inAppWebViewController;
    if (controller == null) return;
    try {
      final value = await controller.evaluateJavascript(
        source: 'navigator.userAgent',
      );
      if (value is String && value.trim().isNotEmpty) {
        LocalStorageService.instance.setWenku8UserAgent(value);
      }
    } catch (e) {
      Log.e('Sync Wenku8 WebView user agent failed: $e');
    }
  }

  Future<String?> _buildWenku8BrowserCookie(
    WebUri uri, {
    bool allowExistingLogin = false,
  }) async {
    final cookies = <Cookie>[
      ...await cookieManager.getCookies(url: uri),
      ...await cookieManager.getCookies(
        url: WebUri(Wenku8Node.wwwWenku8Cc.node),
      ),
      ...await cookieManager.getCookies(
        url: WebUri(Wenku8Node.wwwWenku8Net.node),
      ),
      ...await cookieManager.getCookies(url: WebUri('http://www.wenku8.cc')),
      ...await cookieManager.getCookies(url: WebUri('http://www.wenku8.net')),
    ];
    final merged = <String, String>{};
    final browserCookieNames = <String>{};
    final existing = LocalStorageService.instance.getCookie();
    if (allowExistingLogin && existing != null && existing.isNotEmpty) {
      merged.addAll(_parseCookieHeader(existing));
    }
    for (final cookie in cookies) {
      if (cookie.name.isEmpty || cookie.value.isEmpty) continue;
      browserCookieNames.add(cookie.name);
      merged[cookie.name] = cookie.value;
    }
    if (!_hasWenku8LoginCookieMap(merged) && !allowExistingLogin) {
      return null;
    }
    if (!_hasWenku8LoginCookieMap(merged) &&
        !merged.containsKey('cf_clearance')) {
      return null;
    }
    return merged.entries.map((e) => '${e.key}=${e.value}').join(';');
  }

  Map<String, String> _parseCookieHeader(String value) {
    final result = <String, String>{};
    for (final part in value.split(';')) {
      final index = part.indexOf('=');
      if (index <= 0) continue;
      final key = part.substring(0, index).trim();
      final cookieValue = part.substring(index + 1).trim();
      if (key.isNotEmpty && cookieValue.isNotEmpty) result[key] = cookieValue;
    }
    return result;
  }

  bool _hasWenku8LoginCookie(String cookie) =>
      _hasWenku8LoginCookieMap(_parseCookieHeader(cookie));

  bool _hasWenku8LoginCookieMap(Map<String, String> cookies) =>
      cookies.keys.any(
        (key) => key == 'jieqiUserInfo' || key.contains('jieqiUserInfo'),
      ) &&
      cookies.keys.any(
        (key) => key == 'jieqiVisitInfo' || key.contains('jieqiVisitInfo'),
      );

  Future<void> _runPostLoginStep(
    String label,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e, stackTrace) {
      Log.e("$label failed: $e\n$stackTrace");
    }
  }

  Future<void> _getUserInfo() async {
    final data = await Api.getUserInfo();
    switch (data) {
      case Success():
        LocalStorageService.instance.setUserInfo(Parser.getUserInfo(data.data));
      case Error():
        {
          throw data.error;
        }
    }
  }
}
