import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/novel_cover.dart';
import 'package:hikari_novel_flutter/models/page_state.dart';
import 'package:hikari_novel_flutter/models/resource.dart';
import 'package:hikari_novel_flutter/network/esj_api.dart';
import 'package:hikari_novel_flutter/network/esj_parser.dart';
import 'package:hikari_novel_flutter/widgets/state_page.dart';

class EsjController extends GetxController {
  final easyRefreshController = EasyRefreshController();
  final data = RxList<NovelCover>();
  final pageState = PageState.loading.obs;
  final type = 0.obs;
  final sort = 1.obs;
  final selectedTag = ''.obs;
  String errorMsg = '';
  int _page = 0;
  bool _hasMore = true;

  int get pageIndex => _page <= 0 ? 1 : _page;

  bool get canPreviousPage => _page > 1;

  bool get canNextPage => _hasMore;

  List<(int, String)> get typeOptions => [
    (0, 'esj_type_all'.tr),
    (1, 'esj_type_japan'.tr),
    (2, 'esj_type_original'.tr),
    (3, 'esj_type_korea'.tr),
  ];

  List<(int, String)> get sortOptions => [
    (1, 'esj_sort_latest_update'.tr),
    (2, 'esj_sort_latest_release'.tr),
    (3, 'esj_sort_rating'.tr),
    (4, 'esj_sort_views'.tr),
    (5, 'esj_sort_articles'.tr),
    (6, 'esj_sort_comments'.tr),
    (7, 'esj_sort_favorites'.tr),
    (8, 'esj_sort_words'.tr),
  ];

  List<String> get tagOptions => const [
    '異世界',
    '轉生',
    '奇幻',
    '冒險',
    '戀愛',
    '魔法',
    '日輕',
    '原創',
    'R15',
    'R18',
    '百合',
    'TS',
    '戰鬥',
    '校園',
    '喜劇',
  ];

  String get typeText =>
      typeOptions.firstWhere((item) => item.$1 == type.value).$2;

  String get sortText =>
      sortOptions.firstWhere((item) => item.$1 == sort.value).$2;

  String get tagText =>
      selectedTag.value.isEmpty ? 'esj_tag_all'.tr : selectedTag.value;

  @override
  void onReady() {
    super.onReady();
    getPage(false);
  }

  void changeType(int value) {
    type.value = value;
    getPage(false);
  }

  void changeSort(int value) {
    sort.value = value;
    getPage(false);
  }

  void changeTag(String value) {
    selectedTag.value = value;
    getPage(false);
  }

  Future<IndicatorResult> getPage(bool loadMore) async {
    if (!loadMore) {
      pageState.value = PageState.loading;
      data.clear();
      _page = 0;
      _hasMore = true;
    }
    if (!_hasMore) return IndicatorResult.noMore;
    _page += 1;
    final result = await _getCurrentPageData(_page);
    switch (result) {
      case Success():
        final items = EsjParser.getSearchResults(result.data);
        if (items.isEmpty) {
          _hasMore = false;
          if (!loadMore && data.isEmpty) pageState.value = PageState.empty;
          return IndicatorResult.noMore;
        }
        data.addAll(items);
        pageState.value = PageState.success;
        return IndicatorResult.success;
      case Error():
        if (!loadMore) {
          errorMsg = result.error.toString();
          pageState.value = PageState.error;
        } else {
          showErrorDialog(result.error.toString(), [
            TextButton(onPressed: Get.back, child: Text('confirm'.tr)),
          ]);
        }
        if (_page > 0) _page -= 1;
        return IndicatorResult.fail;
    }
  }

  Future<IndicatorResult> getBrowsingPage(int page) async {
    final target = page < 1 ? 1 : page;
    pageState.value = PageState.loading;
    final result = await _getCurrentPageData(target);
    switch (result) {
      case Success():
        final items = EsjParser.getSearchResults(result.data);
        if (items.isEmpty) {
          _hasMore = false;
          pageState.value = data.isEmpty ? PageState.empty : PageState.success;
          return IndicatorResult.noMore;
        }
        data.assignAll(items);
        _page = target;
        _hasMore = true;
        pageState.value = PageState.success;
        return IndicatorResult.success;
      case Error():
        errorMsg = result.error.toString();
        pageState.value = PageState.error;
        return IndicatorResult.fail;
    }
  }

  Future<IndicatorResult> getPreviousBrowsingPage() {
    if (!canPreviousPage) return Future.value(IndicatorResult.noMore);
    return getBrowsingPage(_page - 1);
  }

  Future<IndicatorResult> getNextBrowsingPage() {
    if (!canNextPage) return Future.value(IndicatorResult.noMore);
    return getBrowsingPage(_page + 1);
  }

  Future<Resource> _getCurrentPageData(int page) {
    if (selectedTag.value.trim().isNotEmpty) {
      return EsjApi.searchNovel(
        keyword: selectedTag.value.trim(),
        page: page,
        type: type.value,
        sort: sort.value,
      );
    }
    return EsjApi.getNovelList(type: type.value, sort: sort.value, page: page);
  }
}
