import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/page_state.dart';
import 'package:hikari_novel_flutter/pages/esj/controller.dart';
import 'package:hikari_novel_flutter/widgets/browsing_novel_grid.dart';
import 'package:hikari_novel_flutter/widgets/keep_alive_wrapper.dart';
import 'package:hikari_novel_flutter/widgets/source_backdrop.dart';
import 'package:hikari_novel_flutter/widgets/state_page.dart';

class EsjView extends StatelessWidget {
  EsjView({super.key});

  final controller = Get.put(EsjController());

  @override
  Widget build(BuildContext context) {
    return KeepAliveWrapper(
      child: Column(
        children: [
          const SizedBox(height: 4),
          SourceSurface(
            child: Row(
              children: [
                const SizedBox(width: 14),
                Obx(
                  () => ActionChip(
                    label: Row(
                      children: [
                        Text(controller.typeText),
                        const Icon(Icons.arrow_drop_down_outlined),
                      ],
                    ),
                    onPressed: () =>
                        showMenu(
                          context: context,
                          position: RelativeRect.fill,
                          items: controller.typeOptions
                              .map(
                                (item) => PopupMenuItem(
                                  value: item.$1,
                                  child: Text(item.$2),
                                ),
                              )
                              .toList(),
                        ).then((value) {
                          if (value != null) controller.changeType(value);
                        }),
                  ),
                ),
                const SizedBox(width: 10),
                Obx(
                  () => ActionChip(
                    label: Row(
                      children: [
                        Text(controller.sortText),
                        const Icon(Icons.arrow_drop_down_outlined),
                      ],
                    ),
                    onPressed: () =>
                        showMenu(
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
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SourceSurface(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Obx(
                () => ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      const Icon(Icons.sell_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          controller.tagText,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          ChoiceChip(
                            label: Text('esj_tag_all'.tr),
                            selected: controller.selectedTag.value.isEmpty,
                            onSelected: (_) => controller.changeTag(''),
                          ),
                          ...controller.tagOptions.map(
                            (tag) => ChoiceChip(
                              label: Text(tag),
                              selected: controller.selectedTag.value == tag,
                              onSelected: (_) => controller.changeTag(tag),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
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
