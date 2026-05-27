import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/common/wenku8_node.dart';
import 'package:hikari_novel_flutter/models/source_config.dart';
import 'package:hikari_novel_flutter/network/api.dart';
import 'package:hikari_novel_flutter/network/esj_api.dart';
import 'package:hikari_novel_flutter/network/wenku8_webview_transport.dart';
import 'package:hikari_novel_flutter/network/yamibo_api.dart';
import 'package:hikari_novel_flutter/pages/bookshelf/controller.dart';
import 'package:hikari_novel_flutter/pages/category/controller.dart';
import 'package:hikari_novel_flutter/pages/completion/controller.dart';
import 'package:hikari_novel_flutter/pages/esj/controller.dart';
import 'package:hikari_novel_flutter/pages/ranking/controller.dart';
import 'package:hikari_novel_flutter/pages/recommend/controller.dart';
import 'package:hikari_novel_flutter/service/local_storage_service.dart';
import 'package:hikari_novel_flutter/service/source_config_service.dart';

class HomeController extends GetxController {
  final tabIndex = 0.obs;
  final esjTabIndex = 0.obs;
  final yamiboTabIndex = 0.obs;
  final visibleSectionIndex = 0.obs;
  final appBarSectionsExpanded = true.obs;
  final sourcePickerExpanded = false.obs;
  late final Rx<NovelSource> source = Rx(_initialSource());
  late final Rx<NovelSource> previousSource = Rx(source.value);
  final yamiboPageRevision = 0.obs;
  final loadedSectionKeys = <String>{}.obs;
  final homeRefreshUnlocked = true.obs;
  final homeRefreshGestureLocked = false.obs;
  final homeAppBarAutoCollapse = LocalStorageService.instance
      .getHomeAppBarAutoCollapse()
      .obs;
  final browsingEInkMode = LocalStorageService.instance
      .getBrowsingEInkMode()
      .obs;
  final wenku8CompatibilityMode = LocalStorageService.instance
      .getWenku8CompatibilityMode()
      .obs;

  final Map<NovelSource, PageController> _pageControllers = {};
  final List<PageController> _retiredPageControllers = [];
  NovelSource? _pendingPageSyncSource;
  int? _pendingPageSyncIndex;
  DateTime? _homeSectionsExpandedAt;
  Timer? _homeRefreshUnlockTimer;
  int _homeChromeGestureBlockCount = 0;
  bool _closed = false;
  static const _refreshArmDelay = Duration(milliseconds: 720);

  final List tabs = [
    "recommend".tr,
    "category".tr,
    "ranking".tr,
    "completion".tr,
  ];

  List<(int, String)> get esjTypeOptions => [
    (0, 'esj_type_all'.tr),
    (1, 'esj_type_japan'.tr),
    (2, 'esj_type_original'.tr),
    (3, 'esj_type_korea'.tr),
  ];

  @override
  void onInit() {
    for (final value in NovelSource.values) {
      final controller = PageController(initialPage: _sectionIndexFor(value));
      _pageControllers[value] = controller;
    }
    _activateSource(activeSource);
    super.onInit();
  }

  @override
  void onClose() {
    _closed = true;
    _homeRefreshUnlockTimer?.cancel();
    for (final controller in _pageControllers.values) {
      controller.dispose();
    }
    for (final controller in _retiredPageControllers) {
      controller.dispose();
    }
    _retiredPageControllers.clear();
    super.onClose();
  }

  List<NovelSource> get enabledSources =>
      SourceConfigService.instance.enabledSources;

  bool get hasEnabledSources => enabledSources.isNotEmpty;

  NovelSource get activeSource {
    final enabled = enabledSources;
    if (enabled.contains(source.value)) return source.value;
    return enabled.isEmpty ? NovelSource.wenku8 : enabled.first;
  }

  bool get isWenku8LoggedIn =>
      LocalStorageService.instance.getCookie()?.isNotEmpty == true;

  bool isSourceLoggedIn(NovelSource value) => switch (value) {
    NovelSource.wenku8 => isWenku8LoggedIn,
    NovelSource.esj => EsjApi.hasCookie,
    NovelSource.yamibo => YamiboApi.hasCookie,
  };

  String sourceStatusText(NovelSource value) {
    if (!isSourceLoggedIn(value)) return 'source_not_logged_in'.tr;
    if (value == NovelSource.wenku8) {
      final user = LocalStorageService.instance.getUserInfo();
      final name = user?.username.trim() ?? '';
      if (name.isNotEmpty) return name;
    }
    return 'source_logged_in'.tr;
  }

  int get currentSectionIndex => _sectionIndexFor(activeSource);

  String get currentSectionLabel =>
      _sectionLabelFor(activeSource, currentSectionIndex);

  bool get activeSectionHasFilterBar => switch (activeSource) {
    NovelSource.wenku8 => tabIndex.value == 1 || tabIndex.value == 2,
    NovelSource.esj => true,
    NovelSource.yamibo => true,
  };

  bool get homeChromeCanCollapse =>
      homeAppBarAutoCollapse.value && !browsingEInkMode.value;

  bool get homeAnimationsEnabled => !browsingEInkMode.value;

  bool get homePullRefreshEnabled =>
      !homeChromeCanCollapse ||
      (appBarSectionsExpanded.value &&
          homeRefreshUnlocked.value &&
          !homeRefreshGestureLocked.value);

  bool get homeChromeGestureBlocked => _homeChromeGestureBlockCount > 0;

  PageController get activePageController => pageControllerFor(activeSource);

  PageController pageControllerFor(NovelSource value) =>
      _pageControllers[value]!;

  void _replaceDetachedPageController(NovelSource value, int initialPage) {
    final oldController = _pageControllers[value];
    if (oldController == null || oldController.hasClients) return;
    _retirePageController(oldController);
    _pageControllers[value] = PageController(initialPage: initialPage);
  }

  void _retirePageController(PageController controller) {
    _retiredPageControllers.add(controller);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (_closed) return;
      if (!_retiredPageControllers.remove(controller)) return;
      if (controller.hasClients) {
        _retirePageController(controller);
        return;
      }
      controller.dispose();
    });
  }

  double sectionPositionFor(NovelSource value) {
    final selectedIndex = _sectionIndexFor(value);
    final controller = pageControllerFor(value);
    if (!controller.hasClients) return selectedIndex.toDouble();
    try {
      return controller.page ?? selectedIndex.toDouble();
    } catch (_) {
      return selectedIndex.toDouble();
    }
  }

  bool isSectionLoaded(NovelSource value, int index) =>
      loadedSectionKeys.contains(_sectionKey(value, index));

  int sectionCountFor(NovelSource value) => switch (value) {
    NovelSource.wenku8 => tabs.length,
    NovelSource.esj => esjTypeOptions.length,
    NovelSource.yamibo => yamiboForumOptions.length,
  };

  void changeSource(NovelSource value) {
    if (source.value == value) return;
    sourcePickerExpanded.value = false;
    previousSource.value = source.value;
    source.value = value;
    _activateSource(value);
    revealHomeSections();
  }

  void toggleSourcePicker() {
    sourcePickerExpanded.value = !sourcePickerExpanded.value;
    revealHomeSections();
  }

  void collapseSourcePicker() {
    if (sourcePickerExpanded.value) sourcePickerExpanded.value = false;
  }

  void changeSourceFromPicker(NovelSource value) {
    collapseSourcePicker();
    changeSource(value);
  }

  AxisDirection get sourceTransitionDirection =>
      activeSource.index >= previousSource.value.index
      ? AxisDirection.left
      : AxisDirection.right;

  void changeSourceSection(int index, {bool animate = true}) {
    final value = activeSource;
    final count = sectionCountFor(value);
    if (index < 0 || index >= count) return;
    _markSectionLoaded(value, index);
    _setSectionIndex(value, index);
    visibleSectionIndex.value = index;
    revealHomeSections();
    _replaceDetachedPageController(value, index);
    final controller = pageControllerFor(value);
    if (!controller.hasClients) {
      _pendingPageSyncSource = value;
      _pendingPageSyncIndex = index;
      _syncPageAfterAttach(value);
      return;
    }
    if (_pendingPageSyncSource == value) {
      _pendingPageSyncSource = null;
      _pendingPageSyncIndex = null;
    }
    if (animate && homeAnimationsEnabled) {
      controller
          .animateToPage(
            index,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          )
          .catchError((_) {
            _pendingPageSyncSource = value;
            _pendingPageSyncIndex = index;
            _syncPageAfterAttach(value);
          });
    } else {
      controller.jumpToPage(index);
    }
  }

  void handleSourcePageChanged(NovelSource value, int index) {
    _markSectionLoaded(value, index);
    _setSectionIndex(value, index);
    if (value == activeSource) {
      visibleSectionIndex.value = index;
      revealHomeSections();
    }
  }

  Future<String> refreshActiveSourceHome() => refreshSourceHome(activeSource);

  Future<String> refreshSourceHome(NovelSource value) async {
    try {
      await _refreshSourceHome(value);
      return 'source_refresh_success'.trParams({'source': value.titleKey.tr});
    } catch (e) {
      return 'source_refresh_failed'.trParams({
        'source': value.titleKey.tr,
        'error': e.toString(),
      });
    }
  }

  Future<void> _refreshSourceHome(NovelSource value) async {
    switch (value) {
      case NovelSource.wenku8:
        await refreshWenku8Home();
      case NovelSource.esj:
        final type = esjTypeForIndex(esjTabIndex.value);
        final tag = EsjController.tagForType(type);
        if (Get.isRegistered<EsjController>(tag: tag)) {
          await Get.find<EsjController>(tag: tag).getPage(false);
        }
      case NovelSource.yamibo:
        reloadYamiboForum();
    }
  }

  Future<void> refreshWenku8Home() async {
    final index = tabIndex.value;
    switch (index) {
      case 0:
        if (Get.isRegistered<RecommendController>()) {
          await Get.find<RecommendController>().getRecommend();
        }
      case 1:
        if (Get.isRegistered<CategoryController>()) {
          await Get.find<CategoryController>().getPage(false);
        }
      case 2:
        if (Get.isRegistered<RankingController>()) {
          await Get.find<RankingController>().getPage(false);
        }
      case 3:
        if (Get.isRegistered<CompletionController>()) {
          await Get.find<CompletionController>().getPage(false);
        }
    }
  }

  Future<String> setWenku8CompatibilityMode(bool enabled) async {
    LocalStorageService.instance.setWenku8CompatibilityMode(enabled);
    Wenku8WebViewTransport.setHostEnabled(enabled);
    wenku8CompatibilityMode.value = enabled;
    return enabled
        ? 'wenku8_compatibility_enabled'.tr
        : 'wenku8_compatibility_disabled'.tr;
  }

  String currentWenku8RequestUrl() {
    final index = tabIndex.value;
    return switch (index) {
      1 =>
        Get.isRegistered<CategoryController>()
            ? Get.find<CategoryController>().currentRequestUrl()
            : Api.getNovelByCategoryUrl(category: '校园', sort: '0', index: 1),
      2 =>
        Get.isRegistered<RankingController>()
            ? Get.find<RankingController>().currentRequestUrl()
            : Api.getNovelByRankingUrl(ranking: 'last_update', index: 1),
      3 =>
        Get.isRegistered<CompletionController>()
            ? Get.find<CompletionController>().currentRequestUrl()
            : Api.getCompletionNovelUrl(index: 1),
      _ => Api.getRecommendUrl(),
    };
  }

  Future<String> syncActiveSourceBookshelf() =>
      syncSourceBookshelf(activeSource);

  Future<String> syncSourceBookshelf(NovelSource value) async {
    final controller = Get.isRegistered<BookshelfController>()
        ? Get.find<BookshelfController>()
        : Get.put(BookshelfController());
    return controller.refreshSource(value);
  }

  Future<String?> handleConfirmedLogin(
    NovelSource value, {
    required bool syncFavorites,
  }) async {
    SourceConfigService.instance.enableSourceAfterLogin(value);
    if (activeSource != value) changeSource(value);
    if (!syncFavorites) return null;
    await refreshSourceHome(value);
    if (SourceConfigService.instance.shouldPullOnlineToLocal(value)) {
      return syncSourceBookshelf(value);
    }
    return 'source_refresh_success'.trParams({'source': value.titleKey.tr});
  }

  void reloadYamiboForum() => yamiboPageRevision.value++;

  int esjTypeForIndex(int index) {
    final options = esjTypeOptions;
    final safeIndex = index.clamp(0, options.length - 1);
    return options[safeIndex].$1;
  }

  String yamiboForumForIndex(int index) {
    final safeIndex = index.clamp(0, yamiboForumOptions.length - 1);
    return yamiboForumOptions[safeIndex].$1;
  }

  void ensureSectionLoaded(NovelSource value, int index) {
    final count = sectionCountFor(value);
    if (index < 0 || index >= count) return;
    _markSectionLoaded(value, index);
  }

  void revealHomeSections() {
    expandHomeSections();
  }

  void expandHomeSections() {
    if (!homeChromeCanCollapse) {
      _unlockHomeRefreshNow();
      if (!appBarSectionsExpanded.value) appBarSectionsExpanded.value = true;
      return;
    }
    if (!appBarSectionsExpanded.value) {
      appBarSectionsExpanded.value = true;
      _homeSectionsExpandedAt = DateTime.now();
      _scheduleHomeRefreshUnlock();
    } else {
      _homeSectionsExpandedAt ??= DateTime.now().subtract(_refreshArmDelay);
      if (_homeRefreshUnlockTimer?.isActive != true) {
        homeRefreshUnlocked.value = true;
      }
    }
  }

  void collapseHomeSections({bool force = false}) {
    if (!homeChromeCanCollapse) {
      expandHomeSections();
      return;
    }
    _homeRefreshUnlockTimer?.cancel();
    homeRefreshUnlocked.value = false;
    _homeSectionsExpandedAt = null;
    if (appBarSectionsExpanded.value) appBarSectionsExpanded.value = false;
  }

  void lockHomeRefreshForGesture() {
    if (!homeChromeCanCollapse) return;
    homeRefreshGestureLocked.value = true;
  }

  void releaseHomeRefreshGestureLock() {
    if (!homeRefreshGestureLocked.value) return;
    homeRefreshGestureLocked.value = false;
  }

  void beginHomeChromeGestureBlock() {
    _homeChromeGestureBlockCount++;
    releaseHomeRefreshGestureLock();
  }

  void endHomeChromeGestureBlock() {
    if (_homeChromeGestureBlockCount <= 0) return;
    _homeChromeGestureBlockCount--;
  }

  bool requestHomeRefresh() {
    if (!homeChromeCanCollapse) return true;
    if (!appBarSectionsExpanded.value) {
      expandHomeSections();
      return false;
    }
    if (!homeRefreshUnlocked.value) return false;
    final expandedAt = _homeSectionsExpandedAt;
    if (expandedAt == null) {
      _homeSectionsExpandedAt = DateTime.now();
      return false;
    }
    return DateTime.now().difference(expandedAt) >= _refreshArmDelay;
  }

  void refreshHomeChromeSettings() {
    homeAppBarAutoCollapse.value = LocalStorageService.instance
        .getHomeAppBarAutoCollapse();
    browsingEInkMode.value = LocalStorageService.instance.getBrowsingEInkMode();
    if (!homeChromeCanCollapse) {
      expandHomeSections();
    } else if (!appBarSectionsExpanded.value) {
      homeRefreshUnlocked.value = false;
    } else {
      homeRefreshUnlocked.value = true;
    }
  }

  void _scheduleHomeRefreshUnlock() {
    _homeRefreshUnlockTimer?.cancel();
    homeRefreshUnlocked.value = false;
    _homeRefreshUnlockTimer = Timer(_refreshArmDelay, () {
      if (_closed || !homeChromeCanCollapse || !appBarSectionsExpanded.value) {
        return;
      }
      homeRefreshUnlocked.value = true;
      _homeSectionsExpandedAt ??= DateTime.now().subtract(_refreshArmDelay);
    });
  }

  void _unlockHomeRefreshNow() {
    _homeRefreshUnlockTimer?.cancel();
    homeRefreshUnlocked.value = true;
    homeRefreshGestureLocked.value = false;
    _homeSectionsExpandedAt = DateTime.now().subtract(_refreshArmDelay);
  }

  void _activateSource(NovelSource value) {
    final index = _sectionIndexFor(value);
    _markSectionLoaded(value, index);
    visibleSectionIndex.value = index;
    _replaceDetachedPageController(value, index);
    _pendingPageSyncSource = value;
    _pendingPageSyncIndex = index;
    _syncPageAfterAttach(value);
  }

  void _syncPageAfterAttach(NovelSource value, {int attempt = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (activeSource != value) return;
      final pendingIndex = _pendingPageSyncSource == value
          ? _pendingPageSyncIndex
          : null;
      final index = pendingIndex ?? _sectionIndexFor(value);
      visibleSectionIndex.value = index;
      final controller = pageControllerFor(value);
      if (controller.hasClients) {
        controller.jumpToPage(index);
        if (_pendingPageSyncSource == value) {
          _pendingPageSyncSource = null;
          _pendingPageSyncIndex = null;
        }
        return;
      }
      if (attempt >= 20) return;
      Future<void>.delayed(
        const Duration(milliseconds: 45),
        () => _syncPageAfterAttach(value, attempt: attempt + 1),
      );
    });
  }

  void syncActivePageIfPending() {
    final value = _pendingPageSyncSource;
    if (value == null || value != activeSource) return;
    _syncPageAfterAttach(value);
  }

  void _setSectionIndex(NovelSource value, int index) {
    switch (value) {
      case NovelSource.wenku8:
        tabIndex.value = index;
      case NovelSource.esj:
        esjTabIndex.value = index;
      case NovelSource.yamibo:
        yamiboTabIndex.value = index;
    }
  }

  int _sectionIndexFor(NovelSource value) => switch (value) {
    NovelSource.wenku8 => tabIndex.value,
    NovelSource.esj => esjTabIndex.value,
    NovelSource.yamibo => yamiboTabIndex.value,
  };

  String _sectionLabelFor(NovelSource value, int index) {
    final safeIndex = index.clamp(0, sectionCountFor(value) - 1);
    return switch (value) {
      NovelSource.wenku8 => '${tabs[safeIndex]}',
      NovelSource.esj => esjTypeOptions[safeIndex].$2,
      NovelSource.yamibo => yamiboForumOptions[safeIndex].$2,
    };
  }

  String _sectionKey(NovelSource value, int index) => '${value.id}:$index';

  void _markSectionLoaded(NovelSource value, int index) {
    loadedSectionKeys.add(_sectionKey(value, index));
  }

  NovelSource _initialSource() {
    final enabled = SourceConfigService.instance.enabledSources;
    if (enabled.contains(NovelSource.wenku8)) return NovelSource.wenku8;
    if (enabled.contains(NovelSource.esj)) return NovelSource.esj;
    if (enabled.contains(NovelSource.yamibo)) return NovelSource.yamibo;
    return NovelSource.wenku8;
  }

  Future<String> changeWenku8Node(Wenku8Node node) async {
    LocalStorageService.instance.setWenku8Node(node);
    await refreshSourceHome(NovelSource.wenku8);
    return '${'node'.tr}: ${node.node}';
  }
}

const yamiboForumOptions = [
  (YamiboApi.literatureFid, '文学区'),
  (YamiboApi.lightNovelFid, '轻小说/译文区'),
  (YamiboApi.txtNovelFid, 'TXT 小说区'),
];
