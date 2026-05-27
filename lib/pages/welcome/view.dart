import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/source_config.dart';
import 'package:hikari_novel_flutter/pages/welcome/controller.dart';
import 'package:hikari_novel_flutter/widgets/source_backdrop.dart';
import 'package:hikari_novel_flutter/widgets/state_page.dart';

class WelcomePage extends StatelessWidget {
  WelcomePage({super.key});

  final controller = Get.put(WelcomeController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              children: [
                const LogoPage(),
                const SizedBox(height: 20),
                Text(
                  "welcome_to_use_app".tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "source_setup_tip".tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 20),
                ...NovelSource.values.map(_buildSourceTile),
                const SizedBox(height: 20),
                Obx(
                  () => FilledButton.icon(
                    onPressed: controller.hasSelectedSource
                        ? controller.startApp
                        : null,
                    label: Text("start_using".tr),
                    icon: const Icon(Icons.check),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSourceTile(NovelSource source) {
    final subtitle = switch (source) {
      NovelSource.wenku8 => 'source_wenku8_desc'.tr,
      NovelSource.esj => 'source_esj_desc'.tr,
      NovelSource.yamibo => 'source_yamibo_desc'.tr,
    };
    return Obx(
      () => CheckboxListTile(
        value: controller.isSourceSelected(source),
        onChanged: (value) => controller.toggleSource(source, value ?? false),
        secondary: SourceMark(source: source),
        title: Text(source.titleKey.tr),
        subtitle: Text(subtitle),
        controlAffinity: ListTileControlAffinity.trailing,
      ),
    );
  }
}
