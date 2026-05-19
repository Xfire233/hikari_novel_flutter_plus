import 'dart:async';

import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/novel_cover.dart';
import 'package:hikari_novel_flutter/models/page_state.dart';
import 'package:hikari_novel_flutter/models/resource.dart';
import 'package:hikari_novel_flutter/models/source_config.dart';
import 'package:hikari_novel_flutter/network/esj_api.dart';
import 'package:hikari_novel_flutter/network/esj_parser.dart';
import 'package:hikari_novel_flutter/network/parser.dart';
import 'package:hikari_novel_flutter/network/yamibo_api.dart';
import 'package:hikari_novel_flutter/network/yamibo_parser.dart';
import 'package:hikari_novel_flutter/service/source_config_service.dart';

import '../../common/database/database.dart';
import '../../network/api.dart';
import '../../service/db_service.dart';
import '../../widgets/state_page.dart';

class SearchController extends GetxController {
  SearchController({
    required this.author,
    this.initialSource,
    this.esjTag,
    this.esjKeyword,
  });

  final String? author;
  final NovelSource? initialSource;
  final String? esjTag;
  final String? esjKeyword;

  final keywordController = TextEditingController();
  late final Rx<NovelSource> source = Rx(_resolveInitialSource());

  RxInt wenku8SearchMode = 0.obs;
  RxInt esjType = 0.obs;
  RxInt esjSort = 1.obs;
  RxnString selectedEsjTag = RxnString();
  RxString yamiboForumScope = yamiboLiteratureAllScope.obs;
  RxInt yamiboSearchMode = 0.obs;
  RxString yamiboOrderBy = 'dateline'.obs;
  RxString yamiboAscDesc = 'desc'.obs;
  RxString yamiboSearchFrom = '0'.obs;
  RxList<String> searchHistory = RxList();

  Rx<PageState> pageState = Rx(PageState.pleaseSelect);

  String errorMsg = "";

  StreamSubscription<List<SearchHistoryEntityData>>? _searchHistorySubscription;
  int _maxNum = 1;
  int _index = 0;
  String? _yamiboSearchId;
  DateTime? _lastYamiboSearchAt;
  final RxList<NovelCover> data = RxList();

  static const yamiboLiteratureAllScope = 'literature_all';

  List<NovelSource> get availableSources =>
      SourceConfigService.instance.enabledSources;

  bool get hasAvailableSources => availableSources.isNotEmpty;

  bool get isWenku8 => source.value == NovelSource.wenku8;

  bool get isEsj => source.value == NovelSource.esj;

  bool get isYamibo => source.value == NovelSource.yamibo;

  int get pageIndex => _index <= 0 ? 1 : _index;

  bool get canPreviousPage => _index > 1;

  bool get canNextPage => switch (source.value) {
    NovelSource.wenku8 => _index < _maxNum,
    NovelSource.esj => data.isNotEmpty,
    NovelSource.yamibo => _index < _maxNum,
  };

  List<(int, String)> get esjTypeOptions => [
    (0, 'esj_type_all'.tr),
    (1, 'esj_type_japan'.tr),
    (2, 'esj_type_original'.tr),
    (3, 'esj_type_korea'.tr),
  ];

  List<(int, String)> get esjSortOptions => [
    (1, 'esj_sort_latest_update'.tr),
    (2, 'esj_sort_latest_release'.tr),
    (3, 'esj_sort_rating'.tr),
    (4, 'esj_sort_views'.tr),
    (5, 'esj_sort_articles'.tr),
    (6, 'esj_sort_comments'.tr),
    (7, 'esj_sort_favorites'.tr),
    (8, 'esj_sort_words'.tr),
  ];

  List<String> get commonEsjTags => const [
    '异世界',
    '转生',
    '奇幻',
    '冒险',
    '恋爱',
    '魔法',
    '日轻',
    '原创',
    'R15',
    'R18',
    '百合',
    'TS',
    '战争',
    '校园',
    '喜剧',
  ];

  String get esjTypeText =>
      esjTypeOptions.firstWhere((item) => item.$1 == esjType.value).$2;

  String get esjSortText =>
      esjSortOptions.firstWhere((item) => item.$1 == esjSort.value).$2;

  List<(String, String)> get yamiboForumScopeOptions => [
    (yamiboLiteratureAllScope, 'yamibo_literature_all'.tr),
    (YamiboApi.literatureFid, 'yamibo_literature'.tr),
    (YamiboApi.lightNovelFid, 'yamibo_light_novel'.tr),
    (YamiboApi.txtNovelFid, 'yamibo_txt_novel'.tr),
  ];

  List<(int, String)> get yamiboSearchModeOptions => [
    (0, 'search_all_content'.tr),
    (1, 'search_title_only'.tr),
  ];

  List<(String, String)> get yamiboOrderOptions => [
    ('dateline', 'sort_by_post_time'.tr),
    ('lastpost', 'sort_by_last_reply'.tr),
    ('replies', 'sort_by_replies'.tr),
    ('views', 'sort_by_views'.tr),
  ];

  List<(String, String)> get yamiboAscDescOptions => [
    ('desc', 'descending'.tr),
    ('asc', 'ascending'.tr),
  ];

  List<(String, String)> get yamiboTimeRangeOptions => [
    ('0', 'time_range_all'.tr),
    ('86400', 'time_range_day'.tr),
    ('604800', 'time_range_week'.tr),
    ('2592000', 'time_range_month'.tr),
    ('31536000', 'time_range_year'.tr),
  ];

  String get yamiboForumScopeText =>
      _stringOptionText(yamiboForumScopeOptions, yamiboForumScope.value);

  String get yamiboSearchModeText => yamiboSearchModeOptions
      .firstWhere((item) => item.$1 == yamiboSearchMode.value)
      .$2;

  String get yamiboOrderText =>
      _stringOptionText(yamiboOrderOptions, yamiboOrderBy.value);

  String get yamiboAscDescText =>
      _stringOptionText(yamiboAscDescOptions, yamiboAscDesc.value);

  String get yamiboTimeRangeText =>
      _stringOptionText(yamiboTimeRangeOptions, yamiboSearchFrom.value);

  @override
  void onReady() {
    super.onReady();

    _searchHistorySubscription = DBService.instance
        .getAllSearchHistory()
        .listen(
          (sh) => searchHistory.assignAll(sh.reversed.map((e) => e.keyword)),
        );

    checkInitialSearch();
  }

  @override
  void onClose() {
    _searchHistorySubscription?.cancel();
    keywordController.dispose();
    super.onClose();
  }

  NovelSource _resolveInitialSource() {
    final enabled = availableSources;
    final requested = esjTag != null || esjKeyword != null
        ? NovelSource.esj
        : initialSource ?? (author != null ? NovelSource.wenku8 : null);
    if (requested != null && enabled.contains(requested)) return requested;
    if (enabled.isNotEmpty) return enabled.first;
    return requested ?? NovelSource.wenku8;
  }

  void checkInitialSearch() {
    if (!hasAvailableSources) {
      pageState.value = PageState.empty;
      return;
    }

    if (esjTag != null && availableSources.contains(NovelSource.esj)) {
      source.value = NovelSource.esj;
      keywordController.text = esjTag!;
      selectedEsjTag.value = esjTag;
      getPage(false);
    } else if (esjKeyword != null &&
        availableSources.contains(NovelSource.esj)) {
      source.value = NovelSource.esj;
      keywordController.text = esjKeyword!;
      getPage(false);
    } else if (author != null &&
        availableSources.contains(NovelSource.wenku8)) {
      source.value = NovelSource.wenku8;
      keywordController.text = author!;
      wenku8SearchMode.value = 1;
      getPage(false);
    }
  }

  void selectSource(NovelSource value) {
    if (!availableSources.contains(value) || source.value == value) return;
    source.value = value;
    _resetResult();
    if (value != NovelSource.esj) return;
    final keyword = keywordController.text.trim();
    selectedEsjTag.value = keyword.isEmpty ? null : keyword;
  }

  void selectWenku8Mode(int value) {
    wenku8SearchMode.value = value;
    _resetResult();
  }

  void changeYamiboForumScope(String value) {
    yamiboForumScope.value = value;
    _resetResult();
  }

  void changeYamiboSearchMode(int value) {
    yamiboSearchMode.value = value;
    _resetResult();
  }

  void changeYamiboOrderBy(String value) {
    yamiboOrderBy.value = value;
    _resetResult();
  }

  void changeYamiboAscDesc(String value) {
    yamiboAscDesc.value = value;
    _resetResult();
  }

  void changeYamiboSearchFrom(String value) {
    yamiboSearchFrom.value = value;
    _resetResult();
  }

  void searchFromHistory(String keyword) {
    keywordController.text = keyword;
    keywordController.selection = TextSelection.fromPosition(
      TextPosition(offset: keywordController.text.length),
    );
    if (isEsj) selectedEsjTag.value = keyword;
    _maxNum = 1;
    getPage(false);
    Get.focusScope?.unfocus();
  }

  void selectEsjTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty || !availableSources.contains(NovelSource.esj)) return;
    source.value = NovelSource.esj;
    selectedEsjTag.value = trimmed;
    keywordController.text = trimmed;
    keywordController.selection = TextSelection.fromPosition(
      TextPosition(offset: keywordController.text.length),
    );
    _maxNum = 1;
    getPage(false);
    Get.focusScope?.unfocus();
  }

  void clearKeyword() {
    keywordController.clear();
    if (isEsj) selectedEsjTag.value = null;
    _resetResult();
  }

  void changeEsjType(int value) {
    esjType.value = value;
    if (isEsj && keywordController.text.trim().isNotEmpty) {
      _maxNum = 1;
      getPage(false);
    }
  }

  void changeEsjSort(int value) {
    esjSort.value = value;
    if (isEsj && keywordController.text.trim().isNotEmpty) {
      _maxNum = 1;
      getPage(false);
    }
  }

  Future<IndicatorResult> getPage(bool loadMore) async {
    if (!hasAvailableSources) {
      pageState.value = PageState.empty;
      return IndicatorResult.noMore;
    }

    final keyword = keywordController.text.trim();
    if (keyword.isEmpty) {
      _resetResult();
      pageState.value = PageState.empty;
      return IndicatorResult.noMore;
    }

    if (!loadMore && isYamibo && YamiboApi.extractTid(keyword) == null) {
      final now = DateTime.now();
      final last = _lastYamiboSearchAt;
      if (last != null && now.difference(last) < const Duration(seconds: 10)) {
        _showSearchTooQuicklyTip();
        return IndicatorResult.fail;
      }
      _lastYamiboSearchAt = now;
    }

    if (!loadMore) {
      pageState.value = PageState.loading;
      DBService.instance.upsertSearchHistory(
        SearchHistoryEntityData(keyword: keyword),
      );

      data.clear();
      _index = 0;
      if (isYamibo) _yamiboSearchId = null;
    }
    if (_index >= _maxNum) {
      return IndicatorResult.noMore;
    }
    _index += 1;

    final result = await _requestPage(keyword);
    return _handleResult(result, loadMore: loadMore);
  }

  Future<Resource> _requestPage(String keyword) {
    return switch (source.value) {
      NovelSource.esj => EsjApi.searchNovel(
        keyword: keyword,
        page: _index,
        type: esjType.value,
        sort: esjSort.value,
      ),
      NovelSource.yamibo => _requestYamibo(keyword),
      NovelSource.wenku8 =>
        wenku8SearchMode.value == 0
            ? Api.searchNovelByTitle(title: keyword, index: _index)
            : Api.searchNovelByAuthor(author: keyword, index: _index),
    };
  }

  Future<Resource> _requestYamibo(String keyword) {
    final tid = YamiboApi.extractTid(keyword);
    if (tid != null) return YamiboApi.getThreadPage(tid: tid);
    return YamiboApi.searchThreads(
      keyword: keyword,
      page: _index,
      searchId: _yamiboSearchId,
      forumIds: _yamiboForumIds,
      orderBy: yamiboOrderBy.value,
      ascDesc: yamiboAscDesc.value,
      searchFrom: yamiboSearchFrom.value,
      titleOnly: yamiboSearchMode.value == 1,
    );
  }

  Future<IndicatorResult> _handleResult(
    Resource result, {
    required bool loadMore,
  }) async {
    switch (result) {
      case Success():
        {
          if (isEsj) return _handleEsjResult(result.data, loadMore: loadMore);
          if (isYamibo) {
            return _handleYamiboResult(result.data, loadMore: loadMore);
          }
          return _handleWenku8Result(result.data, loadMore: loadMore);
        }
      case Error():
        {
          if (!loadMore) {
            errorMsg = result.error;
            pageState.value = PageState.error;
          } else {
            showErrorDialog(result.error.toString(), [
              TextButton(onPressed: Get.back, child: Text("confirm".tr)),
            ]);
          }
          if (_index > 0) {
            _index -= 1;
          }
          return IndicatorResult.fail;
        }
    }
  }

  IndicatorResult _handleEsjResult(String html, {required bool loadMore}) {
    selectedEsjTag.value = keywordController.text.trim().isEmpty
        ? null
        : keywordController.text.trim();
    final parsedHtml = EsjParser.getSearchResults(html);
    if (parsedHtml.isEmpty) {
      if (!loadMore && data.isEmpty) pageState.value = PageState.empty;
      return IndicatorResult.noMore;
    }
    _maxNum = _index + 1;
    data.addAll(parsedHtml);
    if (!loadMore) pageState.value = PageState.success;
    return IndicatorResult.success;
  }

  IndicatorResult _handleYamiboResult(
    dynamic payload, {
    required bool loadMore,
  }) {
    if (payload is YamiboSearchPageResponse) {
      if (YamiboParser.isSearchTooQuicklyPage(payload.html)) {
        _showSearchTooQuicklyTip();
        return IndicatorResult.fail;
      }
      final parsed = YamiboParser.getSearchPageData(
        payload.html,
        allowedForumIds: _yamiboForumIds.toSet(),
      );
      _yamiboSearchId = payload.searchId ?? parsed.searchId ?? _yamiboSearchId;
      if (parsed.items.isEmpty) {
        if (!loadMore && data.isEmpty) pageState.value = PageState.empty;
        _maxNum = _index;
        return IndicatorResult.noMore;
      }
      data.addAll(parsed.items);
      final hasMore = parsed.hasMore && _yamiboSearchId != null;
      _maxNum = hasMore ? _index + 1 : _index;
      if (!loadMore) pageState.value = PageState.success;
      return hasMore ? IndicatorResult.success : IndicatorResult.noMore;
    }

    final jsonText = payload is String ? payload : '';
    if (jsonText.isEmpty) {
      pageState.value = PageState.empty;
      return IndicatorResult.noMore;
    }
    data.add(YamiboParser.getThreadCover(jsonText));
    _maxNum = 1;
    pageState.value = PageState.success;
    return IndicatorResult.noMore;
  }

  IndicatorResult _handleWenku8Result(String html, {required bool loadMore}) {
    if (Parser.isError(html)) {
      if (!loadMore) {
        pageState.value = PageState.inFiveSecond;
      } else {
        Get.dialog(
          AlertDialog(
            title: Text("warning".tr),
            content: Text("search_too_quickly_tip".tr),
            actions: [
              TextButton(onPressed: Get.back, child: Text("confirm".tr)),
            ],
          ),
        );
      }

      return IndicatorResult.fail;
    }

    final onlyOne = Parser.isSearchResultOnlyOne(html);

    if (!loadMore) {
      _maxNum = (onlyOne != null) ? 1 : Parser.getMaxNum(html);
    }

    final parsedHtml = (onlyOne != null)
        ? <NovelCover>[onlyOne]
        : Parser.parseToList(html);

    if (parsedHtml.isEmpty) {
      pageState.value = PageState.empty;
      return IndicatorResult.noMore;
    }

    data.addAll(parsedHtml);
    if (!loadMore) pageState.value = PageState.success;
    return (onlyOne != null) ? IndicatorResult.noMore : IndicatorResult.success;
  }

  Future<IndicatorResult> getBrowsingPage(int page) async {
    final target = page < 1 ? 1 : page;
    if (source.value != NovelSource.esj && target > _maxNum) {
      return IndicatorResult.noMore;
    }
    pageState.value = PageState.loading;
    DBService.instance.upsertSearchHistory(
      SearchHistoryEntityData(keyword: keywordController.text.trim()),
    );

    final previousIndex = _index;
    _index = target - 1;
    final previousData = List<NovelCover>.from(data);
    data.clear();
    final result = await getPage(true);
    if ((result == IndicatorResult.noMore || result == IndicatorResult.fail) &&
        previousData.isNotEmpty) {
      data.assignAll(previousData);
      _index = previousIndex;
      pageState.value = PageState.success;
    } else if (result == IndicatorResult.success && data.isNotEmpty) {
      pageState.value = PageState.success;
    }
    return result;
  }

  Future<IndicatorResult> getPreviousBrowsingPage() {
    if (!canPreviousPage) return Future.value(IndicatorResult.noMore);
    return getBrowsingPage(_index - 1);
  }

  Future<IndicatorResult> getNextBrowsingPage() {
    if (!canNextPage) return Future.value(IndicatorResult.noMore);
    return getBrowsingPage(_index + 1);
  }

  void _resetResult() {
    _maxNum = 1;
    _index = 0;
    _yamiboSearchId = null;
    data.clear();
    pageState.value = PageState.pleaseSelect;
  }

  void _showSearchTooQuicklyTip() {
    if (data.isEmpty) pageState.value = PageState.inFiveSecond;
    if (Get.isDialogOpen == true) return;
    showErrorDialog("search_too_quickly_tip".tr, [
      TextButton(onPressed: Get.back, child: Text("confirm".tr)),
    ]);
  }

  List<String> get _yamiboForumIds {
    if (yamiboForumScope.value == yamiboLiteratureAllScope) {
      return const [
        YamiboApi.literatureFid,
        YamiboApi.lightNovelFid,
        YamiboApi.txtNovelFid,
      ];
    }
    return [yamiboForumScope.value];
  }

  String _stringOptionText(List<(String, String)> options, String value) =>
      options.firstWhere((item) => item.$1 == value).$2;
}
