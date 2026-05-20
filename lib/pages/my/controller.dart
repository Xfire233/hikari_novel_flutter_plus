import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/source_config.dart';
import 'package:hikari_novel_flutter/models/user_info.dart';
import 'package:hikari_novel_flutter/models/resource.dart';
import 'package:hikari_novel_flutter/network/esj_api.dart';
import 'package:hikari_novel_flutter/network/esj_parser.dart';
import 'package:hikari_novel_flutter/network/yamibo_api.dart';
import 'package:hikari_novel_flutter/network/yamibo_parser.dart';
import 'package:hikari_novel_flutter/pages/bookshelf/controller.dart';
import 'package:hikari_novel_flutter/pages/yamibo_forum/view.dart';
import 'package:hikari_novel_flutter/router/app_sub_router.dart';
import 'package:hikari_novel_flutter/router/route_path.dart';
import 'package:hikari_novel_flutter/service/source_config_service.dart';
import 'package:hikari_novel_flutter/widgets/state_page.dart';

import '../../service/local_storage_service.dart';

class MyController extends GetxController {
  Rxn<UserInfo> userInfo = Rxn(LocalStorageService.instance.getUserInfo());
  RxInt accountRevision = 0.obs;
  RxMap<NovelSource, String> accountNames = <NovelSource, String>{}.obs;

  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  int get loginRevision => LocalStorageService.instance.loginRevision.value;

  List<NovelSource> get enabledSources =>
      SourceConfigService.instance.enabledSources;

  @override
  void onReady() {
    super.onReady();
    refreshAccountNames();
  }

  bool isSourceLoggedIn(NovelSource source) => switch (source) {
    NovelSource.wenku8 =>
      LocalStorageService.instance.getCookie()?.isNotEmpty == true,
    NovelSource.esj => EsjApi.hasCookie,
    NovelSource.yamibo => YamiboApi.hasCookie,
  };

  String sourceStatusText(NovelSource source) {
    if (!isSourceLoggedIn(source)) return 'source_not_logged_in'.tr;
    if (source == NovelSource.wenku8 && userInfo.value != null) {
      return userInfo.value!.username;
    }
    final name = accountNames[source]?.trim() ?? '';
    if (name.isNotEmpty) return name;
    return 'source_logged_in'.tr;
  }

  Future<void> refreshAccountNames() async {
    final updates = <NovelSource, String>{};
    if (EsjApi.hasCookie) {
      final result = await EsjApi.getViewHistory();
      if (result case Success(:final data)) {
        final name = EsjParser.accountName(data);
        if (name.isNotEmpty) updates[NovelSource.esj] = name;
      }
    }
    if (YamiboApi.hasCookie) {
      final result = await YamiboApi.getForumPage();
      if (result case Success(:final data)) {
        final name = YamiboParser.accountNameFromMobileJson(data);
        if (name.isNotEmpty) updates[NovelSource.yamibo] = name;
      }
    }
    if (updates.isNotEmpty) accountNames.addAll(updates);
  }

  Future<void> openSourceLogin(BuildContext context, NovelSource source) async {
    switch (source) {
      case NovelSource.wenku8:
        await Get.toNamed(RoutePath.login);
        userInfo.value = LocalStorageService.instance.getUserInfo();
      case NovelSource.esj:
        AppSubRouter.toEsjzone();
      case NovelSource.yamibo:
        await _openYamiboLogin(context);
    }
    await refreshAccountNames();
    accountRevision.value++;
  }

  void logout() {
    LocalStorageService.instance.setCookie(null);
    LocalStorageService.instance.setEsjCookie(null);
    LocalStorageService.instance.setYamiboCookie(null);
    LocalStorageService.instance.clearUserInfo();
    userInfo.value = null;
    accountNames.clear();
    accountRevision.value++;
    showSnackBar(message: 'logout_successfully'.tr, context: Get.context!);
  }

  Future<void> _openYamiboLogin(BuildContext context) async {
    final loggedIn = await Navigator.of(
      context,
      rootNavigator: true,
    ).push<bool>(MaterialPageRoute(builder: (_) => const YamiboWebLoginPage()));
    if (!context.mounted) return;
    if (loggedIn != true && !YamiboApi.hasCookie) return;

    SourceConfigService.instance.setSourceEnabled(NovelSource.yamibo, true);
    if (SourceConfigService.instance.shouldPullOnlineToLocal(
      NovelSource.yamibo,
    )) {
      final synced = await BookshelfController.syncYamiboFavoritesToBookshelf();
      if (Get.isRegistered<BookshelfController>()) {
        await Get.find<BookshelfController>().loadFolders();
      }
      if (!context.mounted) return;
      showSnackBar(
        message: synced ? 'update_successfully'.tr : 'update_failed'.tr,
        context: context,
      );
    } else {
      showSnackBar(message: 'yamibo_login_synced'.tr, context: context);
    }
  }
}
