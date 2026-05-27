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
              onTap: () => _confirmLogout(context),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("logout".tr),
        content: Text("logout_confirm".tr),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("cancel".tr)),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              controller.logout();
            },
            child: Text("confirm".tr),
          ),
        ],
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () =>
                            controller.openSourceLogin(context, source),
                        icon: const Icon(Icons.verified_user_outlined),
                        tooltip: 'source_check_login_status'.tr,
                      ),
                      IconButton(
                        onPressed: () =>
                            controller.syncSourceBookshelf(context, source),
                        icon: const Icon(Icons.cloud_download_outlined),
                        tooltip: 'source_sync_online_favorites'.tr,
                      ),
                    ],
                  ),
                  onTap: () => controller.openSourceAccountWeb(context, source),
                  contentPadding: const EdgeInsetsDirectional.only(
                    start: 16,
                    end: 8,
                    top: 2,
                    bottom: 2,
                  ),
                  minVerticalPadding: 8,
                  minLeadingWidth: 40,
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
