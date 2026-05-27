import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/page_state.dart';
import 'package:hikari_novel_flutter/network/api.dart';
import 'package:hikari_novel_flutter/pages/home/controller.dart';
import 'package:hikari_novel_flutter/pages/recommend/controller.dart';
import 'package:hikari_novel_flutter/pages/recommend/widgets/recommend_block_view.dart';
import 'package:hikari_novel_flutter/service/local_storage_service.dart';
import 'package:hikari_novel_flutter/widgets/browsing_novel_grid.dart';
import 'package:hikari_novel_flutter/widgets/keep_alive_wrapper.dart';
import 'package:hikari_novel_flutter/widgets/wenku8_browser_assist.dart';

class RecommendView extends StatelessWidget {
  RecommendView({super.key});

  final controller = Get.put(RecommendController());

  @override
  Widget build(BuildContext context) {
    return KeepAliveWrapper(
      child: Stack(
        children: [
          Obx(
            () => Offstage(
              offstage: controller.pageState.value != PageState.success,
              child: Padding(
                padding: EdgeInsets.fromLTRB(8, 0, 8, 0),
                child: _buildContent(),
              ),
            ),
          ),
          Obx(
            () => Offstage(
              offstage: controller.pageState.value != PageState.loading,
              child: buildWenku8CompatibilityLoadingPage(),
            ),
          ),
          Obx(
            () => Offstage(
              offstage: controller.pageState.value != PageState.error,
              child: _buildErrorMessage(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return buildWenku8BrowserAssistErrorMessage(
      message: controller.errorMsg,
      url: Api.getRecommendUrl(),
      onRetry: controller.getRecommend,
    );
  }

  Widget _buildContent() {
    if (LocalStorageService.instance.getBrowsingEInkMode()) {
      return BrowsingNovelGrid(
        data: controller.eInkNovels,
        onRefresh: controller.getRecommend,
        onLoad: () async => IndicatorResult.noMore,
        onPreviousPage: () async => IndicatorResult.noMore,
        onNextPage: () async => IndicatorResult.noMore,
        page: 1,
        canPreviousPage: false,
        canNextPage: false,
        guardHomeRefresh: true,
      );
    }

    final list = ListView(
      children: controller.data.map((item) {
        return RecommendBlockView(block: item);
      }).toList(),
    );
    if (!Get.isRegistered<HomeController>()) {
      return EasyRefresh(onRefresh: controller.getRecommend, child: list);
    }
    final home = Get.find<HomeController>();
    return Obx(
      () => EasyRefresh(
        onRefresh: home.homePullRefreshEnabled ? controller.getRecommend : null,
        child: list,
      ),
    );
  }
}
