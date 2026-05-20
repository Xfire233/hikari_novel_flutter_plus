import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/source_config.dart';
import 'package:hikari_novel_flutter/service/local_storage_service.dart';
import 'package:hikari_novel_flutter/widgets/state_page.dart';

class SourceAuthGuard {
  const SourceAuthGuard._();

  static bool checkHtml(NovelSource source, String text) {
    if (!_looksLoggedOut(source, text)) return true;
    clearLogin(source);
    showLoginRequired(source);
    return false;
  }

  static void clearLogin(NovelSource source) {
    final storage = LocalStorageService.instance;
    switch (source) {
      case NovelSource.wenku8:
        storage.setCookie(null);
        storage.clearUserInfo();
      case NovelSource.esj:
        storage.setEsjCookie(null);
      case NovelSource.yamibo:
        storage.setYamiboCookie(null);
    }
  }

  static void showLoginRequired(NovelSource source) {
    if (Get.context == null || Get.isDialogOpen == true) return;
    showErrorDialog(
      'source_login_expired'.trParams({'source': source.titleKey.tr}),
      [TextButton(onPressed: Get.back, child: Text('confirm'.tr))],
    );
  }

  static bool _looksLoggedOut(NovelSource source, String text) {
    final plain = text.replaceAll(RegExp(r'\s+'), ' ');
    switch (source) {
      case NovelSource.wenku8:
        return plain.contains('login.php') ||
            plain.contains('用户登录') ||
            plain.contains('會員登錄') ||
            plain.contains('请先登录');
      case NovelSource.esj:
        return plain.contains('登入') && plain.contains('會員');
      case NovelSource.yamibo:
        return plain.contains('viewperm_login_nopermission') ||
            plain.contains('您需要先登录') ||
            plain.contains('您需要先登入');
    }
  }
}
