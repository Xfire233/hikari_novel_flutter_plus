import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/page_state.dart';
import 'package:hikari_novel_flutter/pages/esj/controller.dart';
import 'package:hikari_novel_flutter/widgets/browsing_novel_grid.dart';
import 'package:hikari_novel_flutter/widgets/filter_capsule_controls.dart';
import 'package:hikari_novel_flutter/widgets/home_collapsible_filter_bar.dart';
import 'package:hikari_novel_flutter/widgets/keep_alive_wrapper.dart';
import 'package:hikari_novel_flutter/widgets/state_page.dart';

class EsjView extends StatelessWidget {
  EsjView({super.key, this.initialType = 0})
    : controller = _esjController(initialType);

  final int initialType;
  final EsjController controller;

  @override
  Widget build(BuildContext context) {
    return KeepAliveWrapper(
      child: Column(
        children: [
          _EsjFilterBar(controller: controller),
          Expanded(
            child: Stack(
              children: [
                Obx(
                  () => Offstage(
                    offstage: controller.pageState.value != PageState.success,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
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
                    child: const LoadingPage(),
                  ),
                ),
                Obx(
                  () => Offstage(
                    offstage: controller.pageState.value != PageState.empty,
                    child: const EmptyPage(),
                  ),
                ),
                Obx(
                  () => Offstage(
                    offstage: controller.pageState.value != PageState.error,
                    child: ErrorMessage(
                      msg: controller.errorMsg,
                      action: () => controller.getPage(false),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

EsjController _esjController(int type) {
  final tag = EsjController.tagForType(type);
  return Get.isRegistered<EsjController>(tag: tag)
      ? Get.find<EsjController>(tag: tag)
      : Get.put(EsjController(initialType: type), tag: tag);
}

class _EsjFilterBar extends StatefulWidget {
  const _EsjFilterBar({required this.controller});

  final EsjController controller;

  @override
  State<_EsjFilterBar> createState() => _EsjFilterBarState();
}

enum _EsjFilterPanel { sort, tag }

class _EsjFilterBarState extends State<_EsjFilterBar> {
  _EsjFilterPanel? _expandedPanel;

  EsjController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    return HomeCollapsibleFilterBar(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Obx(() {
          final tagOptions = [
            FilterCapsuleOption(value: '', label: 'esj_tag_all'.tr),
            for (final tag in controller.orderedTagOptions)
              FilterCapsuleOption(value: tag, label: tag),
          ];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 52,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSortBlock(context),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilterCapsuleOptionRow<String>(
                        options: tagOptions,
                        selectedValue: controller.selectedTag.value,
                        expanded: _expandedPanel == _EsjFilterPanel.tag,
                        tooltip: 'esj_tag_all'.tr,
                        onToggleExpanded: () =>
                            _togglePanel(_EsjFilterPanel.tag),
                        onSelected: (value) {
                          controller.changeTag(value);
                          _collapsePanel();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              FilterCapsulePanel<String>(
                expanded: _expandedPanel != null,
                options: _expandedPanel == _EsjFilterPanel.sort
                    ? [
                        for (final item in controller.sortOptions)
                          FilterCapsuleOption(
                            value: '${item.$1}',
                            label: item.$2,
                          ),
                      ]
                    : tagOptions,
                selectedValue: _expandedPanel == _EsjFilterPanel.sort
                    ? '${controller.sort.value}'
                    : controller.selectedTag.value,
                onSelected: (value) {
                  if (_expandedPanel == _EsjFilterPanel.sort) {
                    controller.changeSort(int.parse(value));
                  } else {
                    controller.changeTag(value);
                  }
                  _collapsePanel();
                },
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSortBlock(BuildContext context) {
    return FilterCapsuleButton(
      width: 126,
      label: controller.sortText,
      emphasized: true,
      expanded: _expandedPanel == _EsjFilterPanel.sort,
      onTap: () => _togglePanel(_EsjFilterPanel.sort),
    );
  }

  void _togglePanel(_EsjFilterPanel panel) {
    setState(() {
      _expandedPanel = _expandedPanel == panel ? null : panel;
    });
  }

  void _collapsePanel() {
    if (_expandedPanel == null) return;
    setState(() => _expandedPanel = null);
  }
}
