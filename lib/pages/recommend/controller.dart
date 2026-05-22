import 'package:easy_refresh/easy_refresh.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/page_state.dart';

import '../../models/novel_cover.dart';
import '../../models/recommend_block.dart';
import '../../models/resource.dart';
import '../../network/api.dart';
import '../../network/parser.dart';

class RecommendController extends GetxController {
  final RxList<RecommendBlock> data = RxList();

  Rx<PageState> pageState = Rx(PageState.loading);
  String errorMsg = "";

  List<NovelCover> get eInkNovels =>
      data.expand((block) => block.list).toList(growable: false);

  @override
  void onReady() {
    super.onReady();
    getRecommend();
  }

  Future<IndicatorResult> getRecommend() async {
    pageState.value = PageState.loading;

    final result = await Api.getRecommend();
    switch (result) {
      case Success():
        try {
          final blocks = Parser.getRecommend(result.data);
          if (blocks.isEmpty) {
            errorMsg = "Wenku8 首页解析失败，请重试或检查网络";
            pageState.value = PageState.error;
            return IndicatorResult.fail;
          }
          data.clear();
          data.addAll(blocks);
          pageState.value = PageState.success;
          return IndicatorResult.success;
        } catch (e) {
          errorMsg = "Wenku8 首页解析失败：$e";
          pageState.value = PageState.error;
          return IndicatorResult.fail;
        }
      case Error():
        errorMsg = result.error;
        pageState.value = PageState.error;
        return IndicatorResult.fail;
    }
  }
}
