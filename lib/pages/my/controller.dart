import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/source_config.dart';
import 'package:hikari_novel_flutter/models/user_info.dart';
import 'package:hikari_novel_flutter/network/esj_api.dart';
import 'package:hikari_novel_flutter/network/yamibo_api.dart';
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

  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  int get loginRevision => LocalStorageService.instance.loginRevision.value;

  List<NovelSource> get enabledSources =>
      SourceConfigService.instance.enabledSources;

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
    return 'source_logged_in'.tr;
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
    accountRevision.value++;
  }

  void openSourceEntry(NovelSource source) {
    switch (source) {
      case NovelSource.wenku8:
        Get.toNamed(RoutePath.login);
      case NovelSource.esj:
        AppSubRouter.toEsjzone();
      case NovelSource.yamibo:
        AppSubRouter.toYamiboForum();
    }
  }

  void logout() {
    LocalStorageService.instance.setCookie(null);
    LocalStorageService.instance.setEsjCookie(null);
    LocalStorageService.instance.setYamiboCookie(null);
    LocalStorageService.instance.clearUserInfo();
    userInfo.value = null;
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
