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
        return _looksWenku8LoggedOut(text, plain);
      case NovelSource.esj:
        return _looksEsjLoggedOut(text, plain);
      case NovelSource.yamibo:
        return _looksYamiboLoggedOut(text, plain);
    }
  }

  static bool _looksEsjLoggedOut(String html, String plain) {
    final lower = html.toLowerCase();
    final hasLoginForm =
        lower.contains('action="/login"') ||
        lower.contains("action='/login'") ||
        (lower.contains('/login') &&
            lower.contains('name="email"') &&
            lower.contains('name="password"'));
    if (hasLoginForm) return true;

    return plain.contains('請先登入') ||
        plain.contains('请先登录') ||
        plain.contains('請先登入會員') ||
        plain.contains('请先登录会员');
  }

  static bool _looksYamiboLoggedOut(String html, String plain) {
    final lower = html.toLowerCase();
    if (lower.contains('viewperm_login_nopermission')) return true;
    if (lower.contains('login_nopermission')) return true;

    return plain.contains('您需要先登录') ||
        plain.contains('您需要先登入') ||
        plain.contains('请先登录') ||
        plain.contains('請先登入') ||
        plain.contains('登录后才可以浏览') ||
        plain.contains('登入後才可以瀏覽');
  }

  static bool _looksWenku8LoggedOut(String html, String plain) {
    final lower = html.toLowerCase();
    final hasLoginForm =
        RegExp(
          r'''<form[^>]+action=["']?[^"'>]*login[.]php''',
          caseSensitive: false,
        ).hasMatch(html) ||
        (lower.contains('login.php') &&
            lower.contains('name="username"') &&
            lower.contains('name="password"'));
    if (hasLoginForm) return true;

    return plain.contains('请先登录') ||
        plain.contains('請先登入') ||
        plain.contains('您还没有登录') ||
        plain.contains('您還沒有登入') ||
        plain.contains('本功能要求会员登录') ||
        plain.contains('本功能要求會員登入') ||
        plain.contains('登录后才能使用') ||
        plain.contains('登入後才能使用');
  }
}
