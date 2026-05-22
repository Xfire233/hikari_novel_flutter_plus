import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/custom_exception.dart';
import 'package:hikari_novel_flutter/models/page_state.dart';
import 'package:hikari_novel_flutter/network/api.dart';
import 'package:hikari_novel_flutter/pages/recommend/controller.dart';
import 'package:hikari_novel_flutter/pages/recommend/widgets/recommend_block_view.dart';
import 'package:hikari_novel_flutter/service/local_storage_service.dart';
import 'package:hikari_novel_flutter/widgets/browsing_novel_grid.dart';
import 'package:hikari_novel_flutter/widgets/keep_alive_wrapper.dart';
import 'package:hikari_novel_flutter/widgets/state_page.dart';
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
              child: LoadingPage(),
            ),
          ),
          Obx(
            () => Offstage(
              offstage: controller.pageState.value != PageState.error,
              child: ErrorMessage(
                msg: controller.errorMsg,
                action: controller.getRecommend,
                extraAction: _isCloudflareError(controller.errorMsg)
                    ? () => openWenku8BrowserAssist(
                        url: Api.getRecommendUrl(),
                        onCaptured: controller.getRecommend,
                      )
                    : null,
                extraButtonText: 'wenku8_browser_verify',
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isCloudflareError(String msg) =>
      msg.contains(cloudflareChallengeExceptionMessage) ||
      msg.contains(cloudflare403ExceptionMessage);

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
      );
    }

    return EasyRefresh(
      onRefresh: controller.getRecommend,
      child: ListView(
        children: controller.data.map((item) {
          return RecommendBlockView(block: item);
        }).toList(),
      ),
    );
  }
}
