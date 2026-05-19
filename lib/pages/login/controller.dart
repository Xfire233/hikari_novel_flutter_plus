import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/main.dart';
import 'package:hikari_novel_flutter/models/common/wenku8_node.dart';
import 'package:hikari_novel_flutter/models/page_state.dart';
import 'package:hikari_novel_flutter/models/source_config.dart';
import 'package:hikari_novel_flutter/network/request.dart';
import 'package:hikari_novel_flutter/pages/bookshelf/controller.dart';
import 'package:hikari_novel_flutter/router/route_path.dart';
import 'package:hikari_novel_flutter/service/source_config_service.dart';

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

  String get url => "${Api.wenku8Node.node}/login.php";

  @override
  void onInit() {
    super.onInit();
    cookieManager.deleteAllCookies();
  }

  Future<void> saveCookie(WebUri uri) async {
    showLoading.value = false;

    if (!uri.toString().contains("wenku8") || _handlingLogin) {
      return;
    }

    final getCookie = await cookieManager.getCookies(url: uri);
    final cookie = _buildWenku8LoginCookie(getCookie);
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

  String? _buildWenku8LoginCookie(List<Cookie> cookies) {
    final userInfo = _findCookie(cookies, "jieqiUserInfo");
    final visitInfo = _findCookie(cookies, "jieqiVisitInfo");
    if (userInfo == null || visitInfo == null) {
      return null;
    }
    return "jieqiUserInfo=${userInfo.value};jieqiVisitInfo=${visitInfo.value}";
  }

  Cookie? _findCookie(List<Cookie> cookies, String name) {
    for (final cookie in cookies) {
      if (cookie.name == name || cookie.name.contains(name)) {
        return cookie;
      }
    }
    return null;
  }

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
    await BookshelfController.syncEsjFavoritesToBookshelf();
    await BookshelfController.syncYamiboFavoritesToBookshelf();
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
