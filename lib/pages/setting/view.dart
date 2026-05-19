import 'dart:io';

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/bookshelf.dart';
import 'package:hikari_novel_flutter/models/common/language.dart';
import 'package:hikari_novel_flutter/models/common/wenku8_node.dart';
import 'package:hikari_novel_flutter/models/source_config.dart';
import 'package:hikari_novel_flutter/pages/setting/controller.dart';
import 'package:hikari_novel_flutter/service/backup_service.dart';
import 'package:hikari_novel_flutter/service/source_favorite_adapter.dart';
import 'package:hikari_novel_flutter/widgets/custom_tile.dart';
import 'package:hikari_novel_flutter/widgets/inline_color_picker.dart';
import 'package:hikari_novel_flutter/widgets/source_backdrop.dart';
import 'package:jiffy/jiffy.dart';

import '../../service/local_storage_service.dart';
import '../../widgets/state_page.dart';

class SettingPage extends StatelessWidget {
  SettingPage({super.key});

  final controller = Get.put(SettingController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("setting".tr), titleSpacing: 16),
      body: ListView(
        children: [
          Obx(() {
            final sub = switch (controller.language.value) {
              Language.followSystem => "follow_system".tr,
              Language.simplifiedChinese => "\u7b80\u4f53\u4e2d\u6587",
              Language.traditionalChinese => "\u7e41\u4f53\u4e2d\u6587",
            };
            return NormalTile(
              title: "language".tr,
              subtitle: sub,
              leading: const Icon(Icons.language),
              onTap: () =>
                  Get.dialog(
                    RadioListDialog(
                      value: controller.language.value,
                      values: [
                        (Language.followSystem, "follow_system".tr),
                        (
                          Language.simplifiedChinese,
                          "\u7b80\u4f53\u4e2d\u6587",
                        ),
                        (
                          Language.traditionalChinese,
                          "\u7e41\u4f53\u4e2d\u6587",
                        ),
                      ],
                      title: "language".tr,
                    ),
                  ).then((value) async {
                    if (value != null) controller.changeLanguage(value);
                  }),
            );
          }),
          Obx(() {
            final sub = switch (controller.themeMode.value) {
              ThemeMode.system => "follow_system".tr,
              ThemeMode.light => "light_mode".tr,
              ThemeMode.dark => "dark_mode".tr,
            };
            return NormalTile(
              title: "theme_mode".tr,
              subtitle: sub,
              leading: const Icon(Icons.palette_outlined),
              onTap: () =>
                  Get.dialog(
                    RadioListDialog(
                      value: controller.themeMode.value,
                      values: [
                        (ThemeMode.system, "follow_system".tr),
                        (ThemeMode.light, "light_mode".tr),
                        (ThemeMode.dark, "dark_mode".tr),
                      ],
                      title: "theme_mode".tr,
                    ),
                  ).then((value) {
                    if (value != null) controller.changeThemeMode(value);
                  }),
            );
          }),
          Offstage(
            offstage: !Platform.isAndroid,
            child: Obx(
              () => SwitchTile(
                title: "dynamic_color_mode".tr,
                subtitle: "dynamic_color_mode_tip".tr,
                leading: const Icon(Icons.colorize),
                onChanged: (value) => controller.changeIsDynamicColor(value),
                value: controller.isDynamicColor.value,
              ),
            ),
          ),
          Obx(
            () => Offstage(
              offstage: controller.isDynamicColor.value && Platform.isAndroid,
              child: _buildAppThemeColor(context),
            ),
          ),
          Obx(() {
            return NormalTile(
              title: "node".tr,
              subtitle: controller.wenku8Node.value.node,
              leading: const Icon(Icons.lan_outlined),
              onTap: () =>
                  Get.dialog(
                    RadioListDialog(
                      value: controller.wenku8Node.value,
                      values: [
                        (Wenku8Node.wwwWenku8Net, Wenku8Node.wwwWenku8Net.node),
                        (Wenku8Node.wwwWenku8Cc, Wenku8Node.wwwWenku8Cc.node),
                      ],
                      title: "node".tr,
                    ),
                  ).then((value) async {
                    if (value != null) controller.changeWenku8Node(value);
                  }),
            );
          }),
          _buildSourceSettings(context),
          _buildBackupSettings(context),
          Obx(
            () => SwitchTile(
              title: "relative_time".tr,
              subtitle: "relative_time_tip".trParams({
                "relativeTime": Jiffy.parse(
                  DateTime.parse("2026-01-25 16:27:00").toString(),
                ).fromNow().toString(),
                "normalTime": "2026-01-25 16:27:00",
              }),
              leading: const Icon(Icons.access_time_outlined),
              onChanged: (v) => controller.changeIsRelativeTime(v),
              value: controller.isRelativeTime.value,
            ),
          ),
          Obx(
            () => SwitchTile(
              title: "browsing_eink_mode".tr,
              subtitle: "browsing_eink_mode_desc".tr,
              leading: const Icon(Icons.chrome_reader_mode_outlined),
              onChanged: (v) => controller.changeBrowsingEInkMode(v),
              value: controller.browsingEInkMode.value,
            ),
          ),
          Obx(
            () => SliderTile(
              title: "recent_bookshelf_count_setting".tr,
              leading: const Icon(Icons.history_outlined),
              min: 3,
              max: 50,
              divisions: 47,
              decimalPlaces: 0,
              value: controller.bookshelfRecentCount.value,
              onChanged: (value) =>
                  controller.bookshelfRecentCount.value = value.round(),
              onChangeEnd: (value) =>
                  controller.changeBookshelfRecentCount(value.round()),
            ),
          ),
          Obx(() {
            final sub = switch (controller.bookshelfSortType.value) {
              BookshelfSortType.update => "bookshelf_sort_update".tr,
              BookshelfSortType.title => "bookshelf_sort_title".tr,
              BookshelfSortType.added => "bookshelf_sort_added".tr,
              BookshelfSortType.recentRead => "bookshelf_sort_recent".tr,
            };
            return NormalTile(
              title: "bookshelf_sort_type".tr,
              subtitle: sub,
              leading: const Icon(Icons.sort_outlined),
              onTap: () =>
                  Get.dialog(
                    RadioListDialog<BookshelfSortType>(
                      value: controller.bookshelfSortType.value,
                      values: [
                        (BookshelfSortType.update, "bookshelf_sort_update".tr),
                        (BookshelfSortType.title, "bookshelf_sort_title".tr),
                        (BookshelfSortType.added, "bookshelf_sort_added".tr),
                        (
                          BookshelfSortType.recentRead,
                          "bookshelf_sort_recent".tr,
                        ),
                      ],
                      title: "bookshelf_sort_type".tr,
                    ),
                  ).then((value) {
                    if (value != null) {
                      controller.changeBookshelfSortType(value);
                    }
                  }),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBackupSettings(BuildContext context) {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
            child: Text(
              "backup_and_restore".tr,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          NormalTile(
            title: "export_backup".tr,
            subtitle: "backup_file_desc".tr,
            leading: const Icon(Icons.ios_share_outlined),
            onTap: controller.backupBusy.value
                ? null
                : () => _handleExportBackup(context),
          ),
          NormalTile(
            title: "import_backup".tr,
            subtitle: "import_backup_desc".tr,
            leading: const Icon(Icons.restore_page_outlined),
            onTap: controller.backupBusy.value
                ? null
                : () => _handleImportBackup(context),
          ),
          if (controller.backupBusy.value) const LinearProgressIndicator(),
        ],
      ),
    );
  }

  Future<void> _handleExportBackup(BuildContext context) async {
    final options = await _showBackupOptionsDialog(
      title: "export_backup".tr,
      actionText: "export_backup".tr,
    );
    if (options == null) return;
    try {
      final path = await controller.exportBackup(options);
      if (!context.mounted || path == null) return;
      showSnackBar(message: "backup_exported".tr, context: context);
    } catch (e) {
      if (!context.mounted) return;
      showErrorDialog(e.toString(), [
        TextButton(onPressed: Get.back, child: Text("confirm".tr)),
      ]);
    }
  }

  Future<void> _handleImportBackup(BuildContext context) async {
    final options = await _showBackupOptionsDialog(
      title: "import_backup".tr,
      actionText: "import_backup".tr,
    );
    if (options == null) return;
    try {
      final imported = await controller.importBackup(options);
      if (!context.mounted || !imported) return;
      showSnackBar(message: "backup_imported".tr, context: context);
    } catch (e) {
      if (!context.mounted) return;
      showErrorDialog(e.toString(), [
        TextButton(onPressed: Get.back, child: Text("confirm".tr)),
      ]);
    }
  }

  Future<BackupSectionOptions?> _showBackupOptionsDialog({
    required String title,
    required String actionText,
  }) {
    var auth = true;
    var appSettings = true;
    var readerSettings = true;
    var bookshelf = true;
    var readingData = true;
    return Get.dialog<BackupSectionOptions>(
      StatefulBuilder(
        builder: (context, setState) {
          final options = BackupSectionOptions(
            auth: auth,
            appSettings: appSettings,
            readerSettings: readerSettings,
            bookshelf: bookshelf,
            readingData: readingData,
          );
          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    value: auth,
                    onChanged: (value) => setState(() => auth = value ?? auth),
                    title: Text("backup_auth".tr),
                    subtitle: Text("backup_auth_desc".tr),
                  ),
                  CheckboxListTile(
                    value: appSettings,
                    onChanged: (value) =>
                        setState(() => appSettings = value ?? appSettings),
                    title: Text("backup_app_settings".tr),
                  ),
                  CheckboxListTile(
                    value: readerSettings,
                    onChanged: (value) => setState(
                      () => readerSettings = value ?? readerSettings,
                    ),
                    title: Text("backup_reader_settings".tr),
                  ),
                  CheckboxListTile(
                    value: bookshelf,
                    onChanged: (value) =>
                        setState(() => bookshelf = value ?? bookshelf),
                    title: Text("backup_bookshelf".tr),
                  ),
                  CheckboxListTile(
                    value: readingData,
                    onChanged: (value) =>
                        setState(() => readingData = value ?? readingData),
                    title: Text("backup_reading_data".tr),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: Get.back, child: Text("cancel".tr)),
              TextButton(
                onPressed: options.hasAny
                    ? () => Get.back(result: options)
                    : null,
                child: Text(actionText),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppThemeColor(BuildContext context) {
    return Obx(
      () => ExpansionTile(
        leading: const Icon(Icons.format_color_fill_outlined),
        title: Row(
          children: [
            Expanded(child: Text("theme_color".tr)),
            ColorIndicator(
              width: 24,
              height: 24,
              borderRadius: 100,
              color: controller.customColor.value,
            ),
          ],
        ),
        children: [
          InlineColorPicker(
            color: controller.customColor.value,
            recentColors: LocalStorageService.instance.getRecentThemeColors(),
            resetLabel: "reset_theme_color".tr,
            onChanged: (color) =>
                controller.changeCustomColor(color, remember: false),
            onCommitted: LocalStorageService.instance.addRecentThemeColor,
            onReset: () {
              controller.resetCustomColor();
              showSnackBar(
                message: "reset_theme_color_successfully".tr,
                context: context,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSourceSettings(BuildContext context) {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
            child: Text(
              "source_settings".tr,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          ...NovelSource.values.map((source) {
            final config = controller.sourceConfig(source);
            return ExpansionTile(
              leading: SourceMark(source: source),
              title: Text(source.titleKey.tr),
              subtitle: Text(_sourceSubtitle(config)),
              children: [
                SwitchTile(
                  title: "source_enabled".tr,
                  leading: const Icon(Icons.power_settings_new_outlined),
                  value: config.enabled,
                  onChanged: (value) =>
                      controller.changeSourceEnabled(source, value),
                ),
                SwitchTile(
                  title: "source_pull_online_to_local".tr,
                  subtitle: "source_pull_online_to_local_tip".tr,
                  leading: const Icon(Icons.cloud_download_outlined),
                  value: config.pullOnlineToLocal,
                  onChanged: config.enabled
                      ? (value) => controller.changeSourcePull(source, value)
                      : null,
                ),
                SwitchTile(
                  title: "source_push_local_to_remote".tr,
                  subtitle: SourceFavoriteAdapter.canPushLocalToRemote(source)
                      ? "source_push_local_to_remote_tip".tr
                      : "source_push_not_supported_tip".tr,
                  leading: const Icon(Icons.cloud_upload_outlined),
                  value: config.pushLocalToRemote,
                  onChanged:
                      config.enabled &&
                          SourceFavoriteAdapter.canPushLocalToRemote(source)
                      ? (value) => controller.changeSourcePush(source, value)
                      : null,
                ),
                if (SourceFavoriteAdapter.canChooseRemoteTarget(source))
                  NormalTile(
                    title: "source_remote_target".tr,
                    subtitle: config.targetRemoteFolderId,
                    leading: const Icon(Icons.drive_file_move_outline),
                    onTap: config.enabled
                        ? () => _showRemoteTargetDialog(source, config)
                        : null,
                  ),
                if (SourceFavoriteAdapter.canRemoveRemote(source))
                  SwitchTile(
                    title: "source_delete_remote".tr,
                    subtitle: "source_delete_remote_tip".tr,
                    leading: const Icon(Icons.delete_forever_outlined),
                    value: config.removeRemoteWhenLocalDeleted,
                    onChanged: config.enabled && config.pushLocalToRemote
                        ? (value) =>
                              controller.changeSourceRemoteDelete(source, value)
                        : null,
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  String _sourceSubtitle(SourceSyncConfig config) {
    final parts = <String>[];
    parts.add(config.enabled ? "enable".tr : "disable".tr);
    if (config.pullOnlineToLocal) parts.add("source_pull_short".tr);
    if (config.pushLocalToRemote) parts.add("source_push_short".tr);
    return parts.join(" 路 ");
  }

  Future<void> _showRemoteTargetDialog(
    NovelSource source,
    SourceSyncConfig config,
  ) async {
    final textController = TextEditingController(
      text: config.targetRemoteFolderId,
    );
    final value = await Get.dialog<String>(
      AlertDialog(
        title: Text("source_remote_target".tr),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: "source_remote_target".tr,
            helperText: "source_remote_target_tip".tr,
          ),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: Text("cancel".tr)),
          TextButton(
            onPressed: () => Get.back(result: textController.text),
            child: Text("save".tr),
          ),
        ],
      ),
    );
    textController.dispose();
    if (value == null || value.trim().isEmpty) return;
    controller.changeSourceRemoteTarget(source, value);
  }
}
