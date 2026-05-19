import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/page_state.dart';
import 'package:hikari_novel_flutter/models/source_config.dart';
import 'package:hikari_novel_flutter/router/app_sub_router.dart';
import 'package:hikari_novel_flutter/widgets/source_backdrop.dart';

import '../../service/db_service.dart';
import '../../widgets/browsing_novel_grid.dart';
import 'controller.dart' as c;

class SearchPage extends StatefulWidget {
  final String? author;
  final NovelSource? initialSource;
  final String? esjTag;
  final String? esjKeyword;

  const SearchPage({
    super.key,
    required this.author,
    this.initialSource,
    this.esjTag,
    this.esjKeyword,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final String controllerTag;
  late final c.SearchController controller;
  bool _resultListMode = false;
  bool _advancedExpanded = false;

  @override
  void initState() {
    super.initState();
    controllerTag = 'SearchController_${UniqueKey()}';
    controller = Get.put(
      c.SearchController(
        author: widget.author,
        initialSource: widget.initialSource,
        esjTag: widget.esjTag,
        esjKeyword: widget.esjKeyword,
      ),
      tag: controllerTag,
    );
  }

  @override
  void dispose() {
    Get.delete<c.SearchController>(tag: controllerTag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("search".tr),
        titleSpacing: 16,
        actions: [
          IconButton(
            onPressed: () => setState(() => _resultListMode = !_resultListMode),
            icon: Icon(
              _resultListMode
                  ? Icons.grid_view_outlined
                  : Icons.view_list_outlined,
            ),
            tooltip: _resultListMode ? 'grid_view'.tr : 'list_view'.tr,
          ),
          IconButton(
            onPressed: () => _showSearchGuide(context),
            icon: const Icon(Icons.help_outline),
            tooltip: 'search_guide'.tr,
          ),
        ],
      ),
      body: Obx(
        () => SourceBackdrop(
          source: controller.source.value,
          child: Column(
            children: [
              _buildSearchHeader(context),
              const Divider(height: 1),
              Expanded(child: _buildResultBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchHeader(BuildContext context) {
    return SourceSurface(
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(() => _buildSourceSelector(context)),
              const SizedBox(height: 10),
              Obx(
                () => TextField(
                  controller: controller.keywordController,
                  textInputAction: TextInputAction.search,
                  enabled: controller.hasAvailableSources,
                  decoration: InputDecoration(
                    hintText: _keywordHint(controller.source.value),
                    border: const OutlineInputBorder(),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: controller.clearKeyword,
                        ),
                        IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () => controller.getPage(false),
                        ),
                      ],
                    ),
                  ),
                  onSubmitted: (_) => controller.getPage(false),
                ),
              ),
              Obx(() => _buildAdvancedSearchPanel(context)),
              const SizedBox(height: 8),
              _buildSearchHistory(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceSelector(BuildContext context) {
    final sources = controller.availableSources;
    if (sources.isEmpty) {
      return Row(
        children: [
          Expanded(child: Text('search_no_source_enabled'.tr)),
          TextButton(
            onPressed: AppSubRouter.toSetting,
            child: Text('source_settings'.tr),
          ),
        ],
      );
    }

    if (sources.length == 1) {
      final source = sources.first;
      return Row(
        children: [
          SourceMark(source: source, size: 20),
          const SizedBox(width: 8),
          Text(
            source.titleKey.tr,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: sources
            .map(
              (source) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  avatar: SourceMark(source: source, size: 18),
                  label: Text(source.titleKey.tr),
                  selected: controller.source.value == source,
                  showCheckmark: false,
                  onSelected: (_) => controller.selectSource(source),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildSourceOptions(BuildContext context) {
    if (!controller.hasAvailableSources) return const SizedBox.shrink();
    return switch (controller.source.value) {
      NovelSource.wenku8 => _buildWenku8Options(),
      NovelSource.esj => _buildEsjOptions(context),
      NovelSource.yamibo => _buildYamiboOptions(context),
    };
  }

  Widget _buildAdvancedSearchPanel(BuildContext context) {
    if (!controller.hasAvailableSources) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () =>
                  setState(() => _advancedExpanded = !_advancedExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tune_outlined, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _advancedSummary(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Icon(
                      _advancedExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: _buildSourceOptions(context),
              ),
              crossFadeState: _advancedExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 160),
              sizeCurve: Curves.easeOut,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWenku8Options() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text("search_by_title".tr),
                selected: controller.wenku8SearchMode.value == 0,
                onSelected: (_) => controller.selectWenku8Mode(0),
              ),
              ChoiceChip(
                label: Text("search_by_author".tr),
                selected: controller.wenku8SearchMode.value == 1,
                onSelected: (_) => controller.selectWenku8Mode(1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEsjOptions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _optionChip<int>(
                label: 'source_category'.tr,
                valueText: controller.esjTypeText,
                options: controller.esjTypeOptions,
                onSelected: controller.changeEsjType,
              ),
              _optionChip<int>(
                label: 'search_sort'.tr,
                valueText: controller.esjSortText,
                options: controller.esjSortOptions,
                onSelected: controller.changeEsjSort,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: controller.commonEsjTags.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final tag = controller.commonEsjTags[index];
                return Obx(
                  () => ChoiceChip(
                    label: Text(tag, style: const TextStyle(fontSize: 13)),
                    selected: controller.selectedEsjTag.value == tag,
                    onSelected: (_) => controller.selectEsjTag(tag),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYamiboOptions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _optionChip<String>(
                label: 'source_category'.tr,
                valueText: controller.yamiboForumScopeText,
                options: controller.yamiboForumScopeOptions,
                onSelected: controller.changeYamiboForumScope,
              ),
              _optionChip<int>(
                label: 'search_scope'.tr,
                valueText: controller.yamiboSearchModeText,
                options: controller.yamiboSearchModeOptions,
                onSelected: controller.changeYamiboSearchMode,
              ),
              _optionChip<String>(
                label: 'search_sort'.tr,
                valueText: controller.yamiboOrderText,
                options: controller.yamiboOrderOptions,
                onSelected: controller.changeYamiboOrderBy,
              ),
              _optionChip<String>(
                label: 'search_order'.tr,
                valueText: controller.yamiboAscDescText,
                options: controller.yamiboAscDescOptions,
                onSelected: controller.changeYamiboAscDesc,
              ),
              _optionChip<String>(
                label: 'search_time_range'.tr,
                valueText: controller.yamiboTimeRangeText,
                options: controller.yamiboTimeRangeOptions,
                onSelected: controller.changeYamiboSearchFrom,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _advancedSummary() {
    final prefix = 'advanced_search'.tr;
    return switch (controller.source.value) {
      NovelSource.wenku8 =>
        '$prefix: ${controller.wenku8SearchMode.value == 0 ? "search_by_title".tr : "search_by_author".tr}',
      NovelSource.esj =>
        '$prefix: ${controller.esjTypeText} / ${controller.esjSortText}',
      NovelSource.yamibo =>
        '$prefix: ${controller.yamiboForumScopeText} / ${controller.yamiboSearchModeText}',
    };
  }

  Widget _optionChip<T>({
    required String label,
    required String valueText,
    required List<(T, String)> options,
    required void Function(T value) onSelected,
  }) {
    return ActionChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: $valueText'),
          const Icon(Icons.arrow_drop_down_outlined),
        ],
      ),
      onPressed: () => _showOptionMenu<T>(Get.context!, options, onSelected),
    );
  }

  Widget _buildSearchHistory() {
    return Obx(() {
      if (controller.searchHistory.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "search_history".tr,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: controller.searchHistory.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      return ActionChip(
                        label: Text(
                          controller.searchHistory[index],
                          style: const TextStyle(fontSize: 13),
                        ),
                        onPressed: () => controller.searchFromHistory(
                          controller.searchHistory[index],
                        ),
                      );
                    },
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: "clear_all_history".tr,
                onPressed: DBService.instance.deleteAllSearchHistory,
              ),
            ],
          ),
        ],
      );
    });
  }

  Widget _buildResultBody() {
    return Stack(
      children: [
        Obx(
          () => Offstage(
            offstage: controller.pageState.value != PageState.success,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: BrowsingNovelGrid(
                data: controller.data.toList(),
                onRefresh: () => controller.getPage(false),
                onLoad: () => controller.getPage(true),
                onPreviousPage: controller.getPreviousBrowsingPage,
                onNextPage: controller.getNextBrowsingPage,
                page: controller.pageIndex,
                canPreviousPage: controller.canPreviousPage,
                canNextPage: controller.canNextPage,
                forceListView: _resultListMode,
              ),
            ),
          ),
        ),
        Obx(
          () => Offstage(
            offstage: controller.pageState.value != PageState.loading,
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
        Obx(
          () => Offstage(
            offstage: controller.pageState.value != PageState.empty,
            child: Center(
              child: Text(
                controller.hasAvailableSources
                    ? "content_of_search_is_empty".tr
                    : "search_no_source_enabled".tr,
              ),
            ),
          ),
        ),
        Obx(
          () => Offstage(
            offstage: controller.pageState.value != PageState.error,
            child: Center(child: Text(controller.errorMsg)),
          ),
        ),
        Obx(
          () => Offstage(
            offstage: controller.pageState.value != PageState.jumpToOtherPage,
            child: Center(child: Text("jumped_to_other_page".tr)),
          ),
        ),
        Obx(
          () => Offstage(
            offstage: controller.pageState.value != PageState.inFiveSecond,
            child: Center(child: Text("search_too_quickly_tip".tr)),
          ),
        ),
      ],
    );
  }

  void _showSearchGuide(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('search_guide'.tr),
        content: Text('search_guide_content'.tr),
        actions: [TextButton(onPressed: Get.back, child: Text('confirm'.tr))],
      ),
    );
  }

  void _showOptionMenu<T>(
    BuildContext context,
    List<(T, String)> options,
    void Function(T value) onSelected,
  ) {
    showMenu<T>(
      context: context,
      position: RelativeRect.fill,
      items: options
          .map((item) => PopupMenuItem(value: item.$1, child: Text(item.$2)))
          .toList(),
    ).then((value) {
      if (value != null) onSelected(value);
    });
  }

  String _keywordHint(NovelSource source) => switch (source) {
    NovelSource.wenku8 => 'search_wenku8_hint'.tr,
    NovelSource.esj => 'search_esj_hint'.tr,
    NovelSource.yamibo => 'search_yamibo_hint'.tr,
  };
}
