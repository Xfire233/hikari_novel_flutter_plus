import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/source_config.dart';
import 'package:hikari_novel_flutter/models/source_login_result.dart';
import 'package:hikari_novel_flutter/models/user_info.dart';
import 'package:hikari_novel_flutter/models/resource.dart';
import 'package:hikari_novel_flutter/models/common/wenku8_node.dart';
import 'package:hikari_novel_flutter/network/api.dart';
import 'package:hikari_novel_flutter/network/esj_api.dart';
import 'package:hikari_novel_flutter/network/esj_parser.dart';
import 'package:hikari_novel_flutter/network/yamibo_api.dart';
import 'package:hikari_novel_flutter/network/yamibo_parser.dart';
import 'package:hikari_novel_flutter/pages/esjzone_web/view.dart';
import 'package:hikari_novel_flutter/pages/home/controller.dart';
import 'package:hikari_novel_flutter/pages/login/view.dart';
import 'package:hikari_novel_flutter/pages/yamibo_forum/view.dart';
import 'package:hikari_novel_flutter/service/source_auth_guard.dart';
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
        if (!SourceAuthGuard.checkHtml(NovelSource.esj, data)) {
          accountNames.remove(NovelSource.esj);
        } else {
          final name = EsjParser.accountName(data);
          if (name.isNotEmpty) updates[NovelSource.esj] = name;
        }
      }
    }
    if (YamiboApi.hasCookie) {
      final result = await YamiboApi.getForumPage();
      if (result case Success(:final data)) {
        if (!SourceAuthGuard.checkHtml(NovelSource.yamibo, data)) {
          accountNames.remove(NovelSource.yamibo);
        } else {
          final name = YamiboParser.accountNameFromMobileJson(data);
          if (name.isNotEmpty) updates[NovelSource.yamibo] = name;
        }
      }
    }
    if (updates.isNotEmpty) accountNames.addAll(updates);
  }

  Future<void> openSourceLogin(BuildContext context, NovelSource source) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final result = switch (source) {
      NovelSource.wenku8 => await _openWenku8LoginOrAccount(),
      NovelSource.esj =>
        EsjApi.hasCookie
            ? await navigator.push<SourceLoginResult>(
                MaterialPageRoute(
                  builder: (_) => const EsjzoneWebPage(
                    initialUrl: '${EsjApi.baseUrl}/my/view',
                    accountMode: true,
                    autoCloseOnLogin: true,
                  ),
                ),
              )
            : await navigator.push<SourceLoginResult>(
                MaterialPageRoute(
                  builder: (_) => const EsjzoneWebPage(autoCloseOnLogin: true),
                ),
              ),
      NovelSource.yamibo =>
        YamiboApi.hasCookie
            ? await navigator.push<YamiboWebLoginResult>(
                MaterialPageRoute(
                  builder: (_) => const YamiboWebLoginPage(
                    accountMode: true,
                    autoCloseOnLogin: true,
                  ),
                ),
              )
            : await navigator.push<YamiboWebLoginResult>(
                MaterialPageRoute(
                  builder: (_) =>
                      const YamiboWebLoginPage(autoCloseOnLogin: true),
                ),
              ),
    };
    if (!context.mounted) return;
    await _handleLoginResult(context, source, result);
    await refreshAccountNames();
    accountRevision.value++;
  }

  Future<SourceLoginResult?> _openWenku8LoginOrAccount() async {
    final hasCookie =
        LocalStorageService.instance.getCookie()?.trim().isNotEmpty == true;
    if (!hasCookie) {
      return await Get.to<SourceLoginResult>(
        () => LoginPage(),
        arguments: {'autoCloseOnLogin': true},
      );
    }
    return await Get.to<SourceLoginResult>(
      () => LoginPage(),
      arguments: {
        'accountMode': true,
        'autoCloseOnLogin': true,
        'initialUrl': '${Api.wenku8Node.node}/userdetail.php',
      },
    );
  }

  Future<void> openSourceAccountWeb(
    BuildContext context,
    NovelSource source,
  ) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final result = switch (source) {
      NovelSource.wenku8 => await Get.to<SourceLoginResult>(
        () => LoginPage(),
        arguments: {
          'accountMode': true,
          'autoCloseOnLogin': false,
          'initialUrl': '${Api.wenku8Node.node}/userdetail.php',
        },
      ),
      NovelSource.esj => await navigator.push<SourceLoginResult>(
        MaterialPageRoute(
          builder: (_) => const EsjzoneWebPage(accountMode: true),
        ),
      ),
      NovelSource.yamibo => await navigator.push<YamiboWebLoginResult>(
        MaterialPageRoute(
          builder: (_) => const YamiboWebLoginPage(accountMode: true),
        ),
      ),
    };
    if (!context.mounted) return;
    await _handleLoginResult(context, source, result);
    await refreshAccountNames();
    accountRevision.value++;
  }

  Future<void> syncSourceBookshelf(
    BuildContext context,
    NovelSource source,
  ) async {
    final message = await Get.find<HomeController>().syncSourceBookshelf(
      source,
    );
    if (!context.mounted) return;
    showSnackBar(message: message, context: context);
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

  @override
  void onClose() {
    usernameController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  Future<void> _handleLoginResult(
    BuildContext context,
    NovelSource source,
    SourceLoginResult? result,
  ) async {
    if (result?.loggedIn != true) return;
    if (source == NovelSource.wenku8) {
      userInfo.value = LocalStorageService.instance.getUserInfo();
    }
    final homeController = Get.find<HomeController>();
    final message = await homeController.handleConfirmedLogin(
      source,
      syncFavorites: result!.syncFavorites,
    );
    if (!context.mounted || message == null) return;
    showSnackBar(message: message, context: context);
  }
}
