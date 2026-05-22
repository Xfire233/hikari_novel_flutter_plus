import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/common/constants.dart';
import 'package:hikari_novel_flutter/pages/about/controller.dart';
import 'package:hikari_novel_flutter/router/app_sub_router.dart';
import 'package:hikari_novel_flutter/service/dev_mode_service.dart';
import 'package:hikari_novel_flutter/widgets/custom_tile.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  AboutPage({super.key});

  final controller = Get.put(AboutController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("about".tr), titleSpacing: 16),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Image.asset(
                "assets/images/logo_transparent.png",
                width: 200,
                height: 200,
              ),
            ),
          ),
          const Divider(height: 1),
          Obx(
            () => NormalTile(
              title: "version".tr,
              subtitle:
                  "${controller.version.value}(${controller.buildNumber.value})",
              leading: const Icon(Icons.commit),
              onTap: controller.onVersionTap,
            ),
          ),
          NormalTile(
            title: "plus_edition".tr,
            subtitle: "plus_edition_desc".tr,
            leading: const Icon(Icons.info_outline),
          ),
          NormalTile(
            title: "usage_guide".tr,
            subtitle: "usage_guide_tip".tr,
            leading: const Icon(Icons.help_outline),
            onTap: () => _showTextDialog(
              context,
              "usage_guide".tr,
              "usage_guide_body".tr,
            ),
          ),
          NormalTile(
            title: "major_changes".tr,
            subtitle: "major_changes_tip".tr,
            leading: const Icon(Icons.article_outlined),
            onTap: () => _showTextDialog(
              context,
              "major_changes".tr,
              "major_changes_body".tr,
            ),
          ),
          NormalTile(
            title: "open_source_license".tr,
            leading: const Icon(Icons.assignment_outlined),
            onTap: () => showLicensePage(
              context: context,
              applicationName: kAppName,
              applicationIcon: Center(
                child: Image.asset(
                  "assets/images/logo_transparent.png",
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
          NormalTile(
            title: "Github",
            leading: const Icon(Icons.code),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => launchUrl(
              Uri.parse(
                "https://github.com/Xfire233/hikari_novel_flutter_plus",
              ),
            ),
          ),
          Obx(
            () => Get.find<DevModeService>().enabled.value
                ? Column(
                    children: [
                      const Divider(height: 1),
                      NormalTile(
                        title: "dev_setting".tr,
                        leading: const Icon(Icons.developer_mode),
                        onTap: AppSubRouter.toDevTools,
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  void _showTextDialog(BuildContext context, String title, String body) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: Text("confirm".tr),
          ),
        ],
      ),
    );
  }
}
