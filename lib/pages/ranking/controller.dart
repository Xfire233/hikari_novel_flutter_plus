import 'package:get/get.dart';
import 'package:hikari_novel_flutter/base/base_select_list_page_controller.dart';
import 'package:hikari_novel_flutter/service/local_storage_service.dart';

import '../../models/novel_cover.dart';
import '../../models/resource.dart';
import '../../network/api.dart';
import '../../network/parser.dart';

class RankingController extends BaseSelectListPageController<NovelCover> {
  RxString ranking =
      (LocalStorageService.instance.getWenku8LastRanking() ?? "last_update".tr)
          .obs;

  @override
  void onInit() {
    super.onInit();
    //监听参数变化
    ever(ranking, (value) {
      LocalStorageService.instance.setWenku8LastRanking(value);
      getPage(false);
    });
    getPage(false);
  }

  @override
  Future<Resource> getData(int index) =>
      Api.getNovelByRanking(ranking: ranking.value, index: index);

  @override
  List<NovelCover> getParser(String html) => Parser.parseToList(html);
}
