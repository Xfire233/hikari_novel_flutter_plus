import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/common/constants.dart';
import 'package:hikari_novel_flutter/models/page_state.dart';
import 'package:hikari_novel_flutter/pages/esj/controller.dart';
import 'package:hikari_novel_flutter/widgets/browsing_novel_grid.dart';
import 'package:hikari_novel_flutter/widgets/keep_alive_wrapper.dart';
import 'package:hikari_novel_flutter/widgets/source_backdrop.dart';
import 'package:hikari_novel_flutter/widgets/state_page.dart';

class EsjView extends StatelessWidget {
  EsjView({super.key});

  final controller = _esjController();

  @override
  Widget build(BuildContext context) {
    return KeepAliveWrapper(
      child: Column(
        children: [
          const SizedBox(height: 4),
          _EsjFilterBar(controller: controller),
          const SizedBox(height: 4),
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

class EsjHomeTabs extends StatelessWidget {
  EsjHomeTabs({super.key});

  final controller = _esjController();

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => LayoutBuilder(
        builder: (context, constraints) {
          final scrollable = constraints.maxWidth < 280;
          return DefaultTabController(
            key: ValueKey(controller.type.value),
            length: controller.typeOptions.length,
            initialIndex: controller.typeOptions
                .indexWhere((item) => item.$1 == controller.type.value)
                .clamp(0, controller.typeOptions.length - 1)
                .toInt(),
            child: TabBar(
              tabs: controller.typeOptions
                  .map(
                    (item) => Tab(
                      child: Text(item.$2, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              dividerHeight: 0,
              isScrollable: scrollable,
              tabAlignment: scrollable ? TabAlignment.start : null,
              onTap: (index) =>
                  controller.changeType(controller.typeOptions[index].$1),
            ),
          );
        },
      ),
    );
  }
}

EsjController _esjController() =>
    Get.isRegistered<EsjController>() ? Get.find() : Get.put(EsjController());

class _EsjFilterBar extends StatelessWidget {
  const _EsjFilterBar({required this.controller});

  final EsjController controller;

  @override
  Widget build(BuildContext context) {
    return SourceSurface(
      child: SizedBox(
        height: 46,
        child: Obx(() {
          final tags = controller.orderedTagOptions.take(6).toList();
          return ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: kPageHorizontalPadding,
            ),
            scrollDirection: Axis.horizontal,
            itemCount: tags.length + 3,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return ActionChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(controller.sortText),
                      const Icon(Icons.arrow_drop_down_outlined),
                    ],
                  ),
                  onPressed: () =>
                      showMenu<int>(
                        context: context,
                        position: RelativeRect.fill,
                        items: controller.sortOptions
                            .map(
                              (item) => PopupMenuItem(
                                value: item.$1,
                                child: Text(item.$2),
                              ),
                            )
                            .toList(),
                      ).then((value) {
                        if (value != null) controller.changeSort(value);
                      }),
                );
              }
              if (index == 1) {
                return ChoiceChip(
                  label: Text('esj_tag_all'.tr),
                  selected: controller.selectedTag.value.isEmpty,
                  onSelected: (_) => controller.changeTag(''),
                );
              }
              if (index == tags.length + 2) {
                return ActionChip(
                  label: Text(controller.tagText),
                  avatar: const Icon(Icons.expand_more),
                  onPressed: () => _showAllTags(context),
                );
              }
              final tag = tags[index - 2];
              return ChoiceChip(
                label: Text(tag),
                selected: controller.selectedTag.value == tag,
                onSelected: (_) => controller.changeTag(tag),
              );
            },
          );
        }),
      ),
    );
  }

  void _showAllTags(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          ListTile(
            title: Text('esj_tag_all'.tr),
            onTap: () {
              Navigator.pop(context);
              controller.changeTag('');
            },
          ),
          for (final tag in controller.orderedTagOptions)
            ListTile(
              title: Text(tag),
              trailing: controller.selectedTag.value == tag
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                Navigator.pop(context);
                controller.changeTag(tag);
              },
            ),
        ],
      ),
    );
  }
}
