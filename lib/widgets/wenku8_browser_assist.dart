import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/network/wenku8_webview_transport.dart';
import 'package:hikari_novel_flutter/service/local_storage_service.dart';
import 'package:hikari_novel_flutter/widgets/state_page.dart';

Widget buildWenku8CompatibilityLoadingPage({bool enabled = true}) {
  final compatibilityEnabled =
      enabled && LocalStorageService.instance.getWenku8CompatibilityMode();
  return LoadingPage(
    message: compatibilityEnabled
        ? 'wenku8_compatibility_loading_tip'.tr
        : null,
  );
}

Widget buildWenku8BrowserAssistErrorMessage({
  required String message,
  required String url,
  required Future<void> Function() onRetry,
  bool enabled = true,
}) {
  Future<void> enableCompatibilityAndRetry() async {
    LocalStorageService.instance.setWenku8CompatibilityMode(true);
    Wenku8WebViewTransport.setHostEnabled(true);
    await onRetry();
  }

  final canEnableCompatibility =
      enabled && !LocalStorageService.instance.getWenku8CompatibilityMode();

  return ErrorMessage(
    msg: message,
    action: onRetry,
    buttonText: 'retry',
    iconData: Icons.refresh,
    extraAction: canEnableCompatibility ? enableCompatibilityAndRetry : null,
    extraButtonText: 'wenku8_enable_compatibility_mode',
    extraIconData: Icons.web_asset_outlined,
  );
}
