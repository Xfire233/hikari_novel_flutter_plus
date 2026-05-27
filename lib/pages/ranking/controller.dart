import 'package:get/get.dart';
import 'package:hikari_novel_flutter/base/base_select_list_page_controller.dart';
import 'package:hikari_novel_flutter/service/local_storage_service.dart';

import '../../models/novel_cover.dart';
import '../../models/resource.dart';
import '../../network/api.dart';
import '../../network/parser.dart';

class RankingController extends BaseSelectListPageController<NovelCover> {
  static const rankingKeys = [
    'last_update',
    'post_date',
    'all_visit',
    'all_vote',
    'good_num',
    'day_visit',
    'day_vote',
    'month_visit',
    'month_vote',
    'week_visit',
    'week_vote',
    'size',
    'animated',
    'unanimated',
  ];

  RxString ranking = _normalizeRanking(
    LocalStorageService.instance.getWenku8LastRanking(),
  ).obs;

  @override
  void onInit() {
    super.onInit();
    LocalStorageService.instance.setWenku8LastRanking(ranking.value);
    ever(ranking, (value) {
      final normalized = _normalizeRanking(value);
      if (normalized != value) {
        ranking.value = normalized;
        return;
      }
      LocalStorageService.instance.setWenku8LastRanking(normalized);
      getPage(false);
    });
    getPage(false);
  }

  @override
  Future<Resource> getData(int index) =>
      Api.getNovelByRanking(ranking: ranking.value, index: index);

  String currentRequestUrl() =>
      Api.getNovelByRankingUrl(ranking: ranking.value, index: pageIndex);

  @override
  List<NovelCover> getParser(String html) => Parser.parseToList(html);

  static String _normalizeRanking(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return 'last_update';
    for (final key in rankingKeys) {
      if (raw == key || raw == key.tr) return key;
    }
    if (raw == 'not_animated') return 'unanimated';
    return 'last_update';
  }
}
