import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/main.dart';
import 'package:hikari_novel_flutter/models/book_tags.dart';
import 'package:hikari_novel_flutter/models/common/wenku8_node.dart';
import 'package:hikari_novel_flutter/models/page_state.dart';
import 'package:hikari_novel_flutter/models/source_config.dart';
import 'package:hikari_novel_flutter/network/request.dart';
import 'package:hikari_novel_flutter/router/route_path.dart';
import 'package:hikari_novel_flutter/service/browser_assisted_fetch_service.dart';
import 'package:hikari_novel_flutter/service/source_config_service.dart';
import 'package:hikari_novel_flutter/widgets/state_page.dart';

import '../../common/database/database.dart';
import '../../common/log.dart';
import '../../models/resource.dart';
import '../../network/api.dart';
import '../../network/parser.dart';
import '../../service/db_service.dart';
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
    userAgent: Request.userAgent[HttpHeaders.userAgentHeader],
    javaScriptEnabled: true,
  );
  RxString currentUrl = "".obs;

  Rx<PageState> pageState = PageState.success.obs;
  String errorMsg = "";
  bool _handlingLogin = false;
  late final bool verificationOnly;
  late final bool captureHtmlOnly;
  late final String initialUrl;
  late final List<String> captureAliases;

  String get url => initialUrl;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    verificationOnly = args is Map && args['verificationOnly'] == true;
    captureHtmlOnly = args is Map && args['captureHtmlOnly'] == true;
    final argUrl = args is Map ? '${args['initialUrl'] ?? ''}' : '';
    initialUrl = argUrl.isNotEmpty
        ? argUrl
        : "${Api.wenku8Node.node}/login.php";
    captureAliases = args is Map && args['captureAliases'] is Iterable
        ? (args['captureAliases'] as Iterable)
              .map((item) => '$item')
              .where((item) => item.trim().isNotEmpty)
              .toList()
        : const [];
    if (!verificationOnly && !captureHtmlOnly) {
      cookieManager.deleteAllCookies();
    }
  }

  Future<void> saveCookie(WebUri uri) async {
    showLoading.value = false;

    if (!uri.toString().contains("wenku8") || _handlingLogin) {
      return;
    }
    if (verificationOnly || captureHtmlOnly) return;

    final cookie = await _buildWenku8BrowserCookie(uri);
    if (cookie == null) {
      return;
    }

    _handlingLogin = true;
    LocalStorageService.instance.setCookie(cookie);
    SourceConfigService.instance.setSourceEnabled(NovelSource.wenku8, true);
    Request.initCookie();

    await _runPostLoginStep("refresh Wenku8 user info", _getUserInfo);
    await _runPostLoginStep("refresh online bookshelf", _refreshBookshelf);

    Get.offAllNamed(RoutePath.main);
  }

  Future<void> syncBrowserVerification() async {
    final current = await inAppWebViewController?.getUrl();
    final uri = current ?? WebUri(Api.wenku8Node.node);
    if (!uri.toString().contains('wenku8')) {
      _showVerificationSnackBar('wenku8_verification_sync_failed');
      return;
    }
    final cookie = await _buildWenku8BrowserCookie(
      uri,
      allowExistingLogin: true,
    );
    if (cookie == null || cookie.isEmpty) {
      _showVerificationSnackBar('wenku8_verification_sync_failed');
      return;
    }
    LocalStorageService.instance.setCookie(cookie);
    if (_hasWenku8LoginCookie(cookie)) {
      SourceConfigService.instance.setSourceEnabled(NovelSource.wenku8, true);
    }
    Request.initCookie();
    _showVerificationSnackBar('wenku8_verification_synced');
  }

  Future<void> captureCurrentHtmlAndReturn() async {
    final controller = inAppWebViewController;
    if (controller == null) {
      _showVerificationSnackBar('browser_assisted_capture_failed');
      return;
    }
    final current = await controller.getUrl();
    final currentUrl = current?.toString() ?? initialUrl;
    final html = await controller.evaluateJavascript(
      source: 'document.documentElement.outerHTML',
    );
    if (html is! String || !BrowserAssistedFetchService.isUsableHtml(html)) {
      _showVerificationSnackBar('browser_assisted_capture_failed');
      return;
    }
    BrowserAssistedFetchService.saveHtml(
      requestedUrl: initialUrl,
      currentUrl: currentUrl,
      html: html,
    );
    for (final alias in captureAliases) {
      BrowserAssistedFetchService.saveHtml(
        requestedUrl: alias,
        currentUrl: alias,
        html: html,
      );
    }
    _showVerificationSnackBar('browser_assisted_capture_saved');
    Get.back(result: true);
  }

  void _showVerificationSnackBar(String key) {
    final context = Get.context;
    if (context == null) return;
    showSnackBar(message: key.tr, context: context);
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
    if (allowExistingLogin &&
        !browserCookieNames.contains('cf_clearance') &&
        !browserCookieNames.any(
          (key) => key == 'jieqiUserInfo' || key.contains('jieqiUserInfo'),
        )) {
      return null;
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

  Future<void> _refreshBookshelf() async {
    if (!SourceConfigService.instance.shouldPullOnlineToLocal(
      NovelSource.wenku8,
    )) {
      return;
    }
    await Future.wait(
      Iterable.generate(
        6,
        (index) =>
            DBService.instance.deleteWenku8BookshelfByClassId(index.toString()),
      ),
    );

    final futures = Iterable.generate(6, (index) async {
      await _insertAll(index);
    });
    await Future.wait(futures);
  }

  Future<void> _insertAll(int index) async {
    final result = await Api.getBookshelf(classId: index);
    switch (result) {
      case Success():
        {
          final bookshelf = Parser.getBookshelf(result.data, index);
          if (bookshelf.list.isNotEmpty) {
            final insertData = bookshelf.list.map((e) {
              return BookshelfEntityData(
                aid: e.aid,
                bid: e.bid,
                url: e.url,
                title: e.title,
                img: e.img,
                classId: bookshelf.classId.toString(),
                updateKey: e.updateKey,
                updateTime: e.updateTime,
                hasUpdate: false,
                rating: 0,
                remoteTagsJson: BookTags.encode(e.tags),
                localTagsJson: BookTags.emptyJson,
              );
            });
            await DBService.instance.insertAllBookshelf(insertData);
          }
        }
      case Error():
        {
          throw result.error;
        }
    }
  }
}
