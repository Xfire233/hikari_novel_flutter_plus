import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/bookshelf.dart';
import 'package:hikari_novel_flutter/models/common/language.dart';
import 'package:hikari_novel_flutter/models/common/wenku8_node.dart';
import 'package:hikari_novel_flutter/models/source_config.dart';
import 'package:hikari_novel_flutter/pages/bookshelf/controller.dart';
import 'package:hikari_novel_flutter/pages/home/controller.dart';
import 'package:hikari_novel_flutter/service/backup_service.dart';
import 'package:hikari_novel_flutter/service/source_config_service.dart';

import '../../service/local_storage_service.dart';

class SettingController extends GetxController {
  final SourceConfigService sourceConfigService = SourceConfigService.instance;
  Rx<Language> language = Rx(LocalStorageService.instance.getLanguage());
  RxBool isRelativeTime = LocalStorageService.instance.getIsRelativeTime().obs;
  RxBool browsingEInkMode = LocalStorageService.instance
      .getBrowsingEInkMode()
      .obs;
  RxBool homeAppBarAutoCollapse = LocalStorageService.instance
      .getHomeAppBarAutoCollapse()
      .obs;
  RxBool smartSubscriptionAddsToSourceShelf = LocalStorageService.instance
      .getSmartSubscriptionAddsToSourceShelf()
      .obs;
  RxInt smartSubscriptionMinSyncIntervalSeconds = LocalStorageService.instance
      .getSmartSubscriptionMinSyncIntervalSeconds()
      .obs;
  RxBool yamiboOwnerCatalogue = LocalStorageService.instance
      .getYamiboOwnerCatalogue()
      .obs;
  Rx<Wenku8Node> wenku8Node = Rx(LocalStorageService.instance.getWenku8Node());
  Rx<ThemeMode> themeMode = Rx(LocalStorageService.instance.getThemeMode());
  RxBool isDynamicColor = LocalStorageService.instance.getIsDynamicColor().obs;
  Rx<Color> customColor = Rx(LocalStorageService.instance.getCustomColor());
  RxBool backupBusy = false.obs;
  RxInt bookshelfRecentCount = LocalStorageService.instance
      .getBookshelfRecentCount()
      .obs;
  Rx<BookshelfSortType> bookshelfSortType = Rx(
    BookshelfSortType.values[LocalStorageService.instance
        .getBookshelfSortType()],
  );

  void changeIsRelativeTime(bool enabled) {
    isRelativeTime.value = enabled;
    LocalStorageService.instance.setIsRelativeTime(enabled);
  }

  void changeBrowsingEInkMode(bool enabled) {
    browsingEInkMode.value = enabled;
    LocalStorageService.instance.setBrowsingEInkMode(enabled);
    _refreshHomeChromeIfVisible();
    Get.forceAppUpdate();
  }

  void changeHomeAppBarAutoCollapse(bool enabled) {
    homeAppBarAutoCollapse.value = enabled;
    LocalStorageService.instance.setHomeAppBarAutoCollapse(enabled);
    _refreshHomeChromeIfVisible();
  }

  void changeSmartSubscriptionAddsToSourceShelf(bool enabled) {
    smartSubscriptionAddsToSourceShelf.value = enabled;
    LocalStorageService.instance.setSmartSubscriptionAddsToSourceShelf(enabled);
  }

  void changeSmartSubscriptionMinSyncIntervalSeconds(int seconds) {
    smartSubscriptionMinSyncIntervalSeconds.value = seconds;
    LocalStorageService.instance.setSmartSubscriptionMinSyncIntervalSeconds(
      seconds,
    );
  }

  void changeYamiboOwnerCatalogue(bool enabled) {
    yamiboOwnerCatalogue.value = enabled;
    LocalStorageService.instance.setYamiboOwnerCatalogue(enabled);
  }

  void changeLanguage(Language l) async {
    switch (l) {
      case Language.simplifiedChinese:
        Get.updateLocale(Locale("zh", "CN"));
      case Language.traditionalChinese:
        Get.updateLocale(Locale("zh", "TW"));
      case Language.followSystem:
        {
          if (Get.deviceLocale! != Locale("zh", "CN") &&
              Get.deviceLocale! != Locale("zh", "CN")) {
            Get.updateLocale(Locale("zh", "CN"));
          } else {
            Get.updateLocale(Get.deviceLocale!);
          }
        }
    }
    language.value = l;
    LocalStorageService.instance.setLanguage(l);
  }

  void changeWenku8Node(Wenku8Node n) {
    wenku8Node.value = n;
    LocalStorageService.instance.setWenku8Node(n);
  }

  void changeCustomColor(Color color, {bool remember = true}) {
    customColor.value = color;
    LocalStorageService.instance.setCustomColor(color);
    if (remember) LocalStorageService.instance.addRecentThemeColor(color);
    Get.forceAppUpdate();
  }

  void resetCustomColor() {
    changeCustomColor(Colors.blue, remember: false);
  }

  void changeIsDynamicColor(bool enabled) {
    isDynamicColor.value = enabled;
    LocalStorageService.instance.setIsDynamicColor(enabled);
    Get.forceAppUpdate();
  }

  void changeThemeMode(ThemeMode mode) {
    themeMode.value = mode;
    LocalStorageService.instance.setThemeMode(mode);
    Get.forceAppUpdate();
  }

  void changeBookshelfRecentCount(int value) {
    bookshelfRecentCount.value = value;
    LocalStorageService.instance.setBookshelfRecentCount(value);
    _refreshBookshelfIfVisible();
  }

  void changeBookshelfSortType(BookshelfSortType value) {
    bookshelfSortType.value = value;
    LocalStorageService.instance.setBookshelfSortType(value.index);
    _refreshBookshelfIfVisible();
  }

  SourceSyncConfig sourceConfig(NovelSource source) =>
      sourceConfigService.configOf(source);

  void changeSourceEnabled(NovelSource source, bool enabled) {
    sourceConfigService.setSourceEnabled(source, enabled);
    _refreshBookshelfIfVisible();
  }

  void changeSourcePull(NovelSource source, bool enabled) {
    sourceConfigService.setPullOnlineToLocal(source, enabled);
  }

  void changeSourcePush(NovelSource source, bool enabled) {
    sourceConfigService.setPushLocalToRemote(source, enabled);
  }

  void changeSourceRemoteTarget(NovelSource source, String folderId) {
    sourceConfigService.setRemoteTarget(source, folderId.trim());
  }

  void changeSourceRemoteDelete(NovelSource source, bool enabled) {
    sourceConfigService.setRemoveRemoteWhenLocalDeleted(source, enabled);
  }

  Future<String?> exportBackup(BackupSectionOptions options) async {
    backupBusy.value = true;
    try {
      return await BackupService.instance.exportBackup(options);
    } finally {
      backupBusy.value = false;
    }
  }

  Future<bool> importBackup(BackupSectionOptions options) async {
    backupBusy.value = true;
    try {
      final imported = await BackupService.instance.importBackup(options);
      if (imported) {
        language.value = LocalStorageService.instance.getLanguage();
        themeMode.value = LocalStorageService.instance.getThemeMode();
        isDynamicColor.value = LocalStorageService.instance.getIsDynamicColor();
        customColor.value = LocalStorageService.instance.getCustomColor();
        isRelativeTime.value = LocalStorageService.instance.getIsRelativeTime();
        browsingEInkMode.value = LocalStorageService.instance
            .getBrowsingEInkMode();
        homeAppBarAutoCollapse.value = LocalStorageService.instance
            .getHomeAppBarAutoCollapse();
        smartSubscriptionAddsToSourceShelf.value = LocalStorageService.instance
            .getSmartSubscriptionAddsToSourceShelf();
        smartSubscriptionMinSyncIntervalSeconds.value = LocalStorageService
            .instance
            .getSmartSubscriptionMinSyncIntervalSeconds();
        yamiboOwnerCatalogue.value = LocalStorageService.instance
            .getYamiboOwnerCatalogue();
        wenku8Node.value = LocalStorageService.instance.getWenku8Node();
        bookshelfRecentCount.value = LocalStorageService.instance
            .getBookshelfRecentCount();
        bookshelfSortType.value = BookshelfSortType
            .values[LocalStorageService.instance.getBookshelfSortType()];
        _refreshBookshelfIfVisible();
        _refreshHomeChromeIfVisible();
      }
      return imported;
    } finally {
      backupBusy.value = false;
    }
  }

  void _refreshBookshelfIfVisible() {
    if (!Get.isRegistered<BookshelfController>()) return;
    final controller = Get.find<BookshelfController>();
    controller.loadFolders();
  }

  void _refreshHomeChromeIfVisible() {
    if (!Get.isRegistered<HomeController>()) return;
    Get.find<HomeController>().refreshHomeChromeSettings();
  }
}
