import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/common/constants.dart';
import 'package:hikari_novel_flutter/models/source_config.dart';
import 'package:hikari_novel_flutter/pages/my/controller.dart';
import 'package:hikari_novel_flutter/router/app_sub_router.dart';
import 'package:hikari_novel_flutter/widgets/source_backdrop.dart';

class MyPage extends StatelessWidget {
  MyPage({super.key});

  final controller = Get.put(MyController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: ListView(
          children: [
            const SizedBox(height: 10),
            _buildUserInfoCard(context),
            const SizedBox(height: 20),
            ListTile(
              title: Text("browsing_history".tr),
              leading: const Icon(Icons.history),
              onTap: AppSubRouter.toBrowsingHistory,
            ),
            ListTile(
              title: Text("setting".tr),
              leading: const Icon(Icons.settings_outlined),
              onTap: AppSubRouter.toSetting,
            ),
            ListTile(
              title: Text("about".tr),
              leading: const Icon(Icons.info_outline),
              onTap: AppSubRouter.toAbout,
            ),
            ListTile(
              title: Text("logout".tr),
              leading: const Icon(Icons.logout),
              onTap: controller.logout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard(BuildContext context) {
    return Obx(() {
      controller.accountRevision.value;
      controller.loginRevision;
      final sources = controller.enabledSources;
      return Card.outlined(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kCardBorderRadius),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: [
            ListTile(
              title: Text('source_account_status'.tr),
              subtitle: Text('source_account_status_tip'.tr),
            ),
            const Divider(height: 1),
            if (sources.isEmpty)
              ListTile(
                leading: const Icon(Icons.travel_explore_outlined),
                title: Text('search_no_source_enabled'.tr),
                subtitle: Text('source_setup_tip'.tr),
                onTap: AppSubRouter.toSetting,
              )
            else
              for (final source in sources)
                ListTile(
                  leading: _sourceAvatar(source),
                  title: Text(source.titleKey.tr),
                  subtitle: Text(controller.sourceStatusText(source)),
                  trailing: TextButton(
                    onPressed: () =>
                        controller.openSourceLogin(context, source),
                    child: Text(
                      controller.isSourceLoggedIn(source)
                          ? 'source_relogin'.tr
                          : 'source_go_login'.tr,
                    ),
                  ),
                  onTap:
                      source == NovelSource.wenku8 &&
                          controller.isSourceLoggedIn(source)
                      ? AppSubRouter.toUserInfo
                      : () => controller.openSourceLogin(context, source),
                ),
          ],
        ),
      );
    });
  }

  Widget _sourceAvatar(NovelSource source) {
    return CircleAvatar(child: SourceMark(source: source, size: 20));
  }
}
