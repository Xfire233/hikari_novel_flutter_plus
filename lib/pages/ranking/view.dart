import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/page_state.dart';
import 'package:hikari_novel_flutter/pages/ranking/controller.dart';
import 'package:hikari_novel_flutter/widgets/filter_capsule_controls.dart';
import 'package:hikari_novel_flutter/widgets/home_collapsible_filter_bar.dart';
import 'package:hikari_novel_flutter/widgets/wenku8_browser_assist.dart';

import '../../widgets/keep_alive_wrapper.dart';
import '../../widgets/browsing_novel_grid.dart';
import '../../widgets/state_page.dart';

class RankingView extends StatefulWidget {
  const RankingView({super.key});

  @override
  State<RankingView> createState() => _RankingViewState();
}

class _RankingViewState extends State<RankingView> {
  final controller = Get.put(RankingController());
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return KeepAliveWrapper(
      child: Column(
        children: [
          HomeCollapsibleFilterBar(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Obx(() {
                final options = _rankingOptions();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilterCapsuleOptionRow<String>(
                      options: options,
                      selectedValue: controller.ranking.value,
                      expanded: _expanded,
                      tooltip: controller.ranking.value,
                      onToggleExpanded: _togglePanel,
                      onSelected: (value) {
                        controller.ranking.value = value;
                        _collapsePanel();
                      },
                    ),
                    FilterCapsulePanel<String>(
                      expanded: _expanded,
                      options: options,
                      selectedValue: controller.ranking.value,
                      onSelected: (value) {
                        controller.ranking.value = value;
                        _collapsePanel();
                      },
                    ),
                  ],
                );
              }),
            ),
          ),
          Expanded(
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
                    offstage:
                        controller.pageState.value != PageState.pleaseSelect,
                    child: PleaseSelectPage(),
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
          ),
        ],
      ),
    );
  }

  List<FilterCapsuleOption<String>> _rankingOptions() {
    return [
      for (final key in RankingController.rankingKeys)
        FilterCapsuleOption(value: key, label: key.tr),
    ];
  }

  void _togglePanel() {
    setState(() => _expanded = !_expanded);
  }

  void _collapsePanel() {
    if (!_expanded) return;
    setState(() => _expanded = false);
  }

  Widget _buildErrorMessage() {
    return buildWenku8BrowserAssistErrorMessage(
      message: controller.errorMsg,
      url: controller.currentRequestUrl(),
      onRetry: () => controller.getPage(false),
    );
  }
}
