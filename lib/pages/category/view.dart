import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/page_state.dart';
import 'package:hikari_novel_flutter/pages/category/controller.dart';
import 'package:hikari_novel_flutter/widgets/filter_capsule_controls.dart';
import 'package:hikari_novel_flutter/widgets/home_collapsible_filter_bar.dart';
import 'package:hikari_novel_flutter/widgets/wenku8_browser_assist.dart';

import '../../widgets/keep_alive_wrapper.dart';
import '../../widgets/browsing_novel_grid.dart';
import '../../widgets/state_page.dart';

class CategoryView extends StatefulWidget {
  const CategoryView({super.key});

  @override
  State<CategoryView> createState() => _CategoryViewState();
}

enum _CategoryFilterPanel { category, sort }

class _CategoryViewState extends State<CategoryView> {
  final controller = Get.put(CategoryController());
  _CategoryFilterPanel? _expandedPanel;

  @override
  Widget build(BuildContext context) {
    return KeepAliveWrapper(
      child: Column(
        children: [
          HomeCollapsibleFilterBar(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Obx(() {
                final categoryOptions = _categoryOptions();
                final sortOptions = _sortOptions();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FilterCapsuleOptionRow<String>(
                            options: categoryOptions,
                            selectedValue: controller.category.value,
                            expanded:
                                _expandedPanel == _CategoryFilterPanel.category,
                            tooltip: controller.category.value,
                            onToggleExpanded: () =>
                                _togglePanel(_CategoryFilterPanel.category),
                            onSelected: (value) {
                              controller.category.value = value;
                              _collapsePanel();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilterCapsuleButton(
                          width: 142,
                          label: controller.sortText.value,
                          emphasized: true,
                          expanded: _expandedPanel == _CategoryFilterPanel.sort,
                          onTap: () => _togglePanel(_CategoryFilterPanel.sort),
                        ),
                      ],
                    ),
                    FilterCapsulePanel<String>(
                      expanded: _expandedPanel != null,
                      options: _expandedPanel == _CategoryFilterPanel.sort
                          ? sortOptions
                          : categoryOptions,
                      selectedValue: _expandedPanel == _CategoryFilterPanel.sort
                          ? controller.sortValue
                          : controller.category.value,
                      onSelected: (value) {
                        if (_expandedPanel == _CategoryFilterPanel.sort) {
                          final selected = sortOptions.firstWhere(
                            (item) => item.value == value,
                          );
                          controller.sortValue = selected.value;
                          controller.sortText.value = selected.label;
                        } else {
                          controller.category.value = value;
                        }
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

  List<FilterCapsuleOption<String>> _categoryOptions() {
    return [
      for (final key in _categoryKeys)
        FilterCapsuleOption(value: key.tr, label: key.tr),
    ];
  }

  List<FilterCapsuleOption<String>> _sortOptions() {
    return [
      FilterCapsuleOption(value: '0', label: 'sort_by_update'.tr),
      FilterCapsuleOption(value: '1', label: 'sort_by_heat'.tr),
      FilterCapsuleOption(value: '2', label: 'sort_by_completion'.tr),
      FilterCapsuleOption(value: '3', label: 'sort_by_animated'.tr),
    ];
  }

  void _togglePanel(_CategoryFilterPanel panel) {
    setState(() {
      _expandedPanel = _expandedPanel == panel ? null : panel;
    });
  }

  void _collapsePanel() {
    if (_expandedPanel == null) return;
    setState(() => _expandedPanel = null);
  }

  Widget _buildErrorMessage() {
    return buildWenku8BrowserAssistErrorMessage(
      message: controller.errorMsg,
      url: controller.currentRequestUrl(),
      onRetry: () => controller.getPage(false),
    );
  }
}

const _categoryKeys = [
  'school',
  'youth',
  'love',
  'healing',
  'group_portrait',
  'sports',
  'music',
  'food',
  'travel',
  'joy',
  'manage',
  'workplace',
  'battle_of_wits',
  'brain_cavity',
  'otaku_culture',
  'pass_through',
  'fantasy',
  'magic',
  'supernatural_ability',
  'fighting',
  'science_fiction',
  'machine_warfare',
  'warfare',
  'adventure',
  'dragon_proud_sky',
  'suspense',
  'crime',
  'revenge',
  'darkness',
  'hunting_for_novelty',
  'thrilling',
  'spy',
  'apocalypse',
  'game',
  'battle_royale_game',
  'childhood_sweetheart',
  'younger_sisiter',
  'daughter',
  'JK',
  'JC',
  'princess',
  'sexual_conversion',
  'cross_dressing',
  'extra_human',
  'harem',
  'lily',
  'danmei',
  'ntr',
  'female_perspective',
];
