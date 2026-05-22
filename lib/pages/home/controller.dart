import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/source_config.dart';
import 'package:hikari_novel_flutter/network/yamibo_api.dart';
import 'package:hikari_novel_flutter/service/local_storage_service.dart';
import 'package:hikari_novel_flutter/service/source_config_service.dart';

class HomeController extends GetxController with GetTickerProviderStateMixin {
  RxInt tabIndex = 0.obs; //保存tab索引位置
  late final Rx<NovelSource> source = Rx(_initialSource());
  late final Rx<NovelSource> previousSource = Rx(source.value);
  final yamiboPageRevision = 0.obs;
  final yamiboForumFid = YamiboApi.literatureFid.obs;

  late TabController tabController;
  final List tabs = [
    "recommend".tr,
    "category".tr,
    "ranking".tr,
    "completion".tr,
  ];

  @override
  void onInit() {
    tabController = TabController(
      length: tabs.length,
      vsync: this,
      initialIndex: tabIndex.value,
    );
    tabController.addListener(() {
      if (tabIndex.value != tabController.index) {
        tabIndex.value = tabController.index;
      }
    });
    super.onInit();
  }

  @override
  void onClose() {
    tabController.dispose();
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

  void changeSource(NovelSource value) {
    if (source.value == value) return;
    previousSource.value = source.value;
    source.value = value;
  }

  AxisDirection get sourceTransitionDirection =>
      activeSource.index >= previousSource.value.index
      ? AxisDirection.left
      : AxisDirection.right;

  void changeWenku8Tab(int index) {
    if (index < 0 || index >= tabs.length) return;
    tabIndex.value = index;
    tabController.animateTo(index);
  }

  void changeYamiboForum(String fid) {
    if (yamiboForumFid.value == fid) return;
    yamiboForumFid.value = fid;
    reloadYamiboForum();
  }

  void reloadYamiboForum() => yamiboPageRevision.value++;

  NovelSource _initialSource() {
    final enabled = SourceConfigService.instance.enabledSources;
    if (enabled.contains(NovelSource.wenku8)) return NovelSource.wenku8;
    if (enabled.contains(NovelSource.esj)) return NovelSource.esj;
    if (enabled.contains(NovelSource.yamibo)) return NovelSource.yamibo;
    return NovelSource.wenku8;
  }
}
