import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/page_state.dart';
import 'package:hikari_novel_flutter/pages/completion/controller.dart';
import 'package:hikari_novel_flutter/widgets/keep_alive_wrapper.dart';
import 'package:hikari_novel_flutter/widgets/wenku8_browser_assist.dart';

import '../../widgets/browsing_novel_grid.dart';

class CompletionView extends StatelessWidget {
  CompletionView({super.key});

  final controller = Get.put(CompletionController());

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
                child: BrowsingNovelGrid(
                  data: controller.data.toList(),
                  easyRefreshController: controller.easyRefreshController,
                  onRefresh: () => controller.getPage(false),
                  onLoad: () => controller.getPage(true),
                  onPreviousPage: controller.getPreviousBrowsingPage,
                  onNextPage: controller.getNextBrowsingPage,
                  page: controller.pageIndex,
                  canPreviousPage: controller.canPreviousPage,
                  canNextPage: controller.canNextPage,
                  guardHomeRefresh: true,
                ),
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
      url: controller.currentRequestUrl(),
      onRetry: () => controller.getPage(false),
    );
  }
}
