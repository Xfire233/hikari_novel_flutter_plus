import 'package:get/get.dart';
import 'package:hikari_novel_flutter/router/route_path.dart';

Future<void> openWenku8BrowserAssist({
  required String url,
  Future<void> Function()? onCaptured,
}) async {
  final netUrl = url.replaceFirst('wenku8.cc', 'wenku8.net');
  final captured = await Get.toNamed(
    RoutePath.login,
    arguments: {
      'captureHtmlOnly': true,
      'verificationOnly': true,
      'initialUrl': netUrl,
      'captureAliases': [url, netUrl],
    },
  );
  if (captured == true) {
    await onCaptured?.call();
  }
}
