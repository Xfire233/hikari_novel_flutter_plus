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

  final controller = Get.put(EsjController());

  @override
  Widget build(BuildContext context) {
    return KeepAliveWrapper(
      child: Column(
        children: [
          const SizedBox(height: 4),
          SourceSurface(
            child: SizedBox(
              height: 48,
              child: Row(
                children: [
                  Expanded(
                    child: Obx(
                      () => ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: kPageHorizontalPadding,
                        ),
                        scrollDirection: Axis.horizontal,
                        itemCount: controller.typeOptions.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final item = controller.typeOptions[index];
                          return ChoiceChip(
                            label: Text(item.$2),
                            selected: controller.type.value == item.$1,
                            onSelected: (_) => controller.changeType(item.$1),
                          );
                        },
                      ),
                    ),
                  ),
                  Obx(
                    () => Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ActionChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
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
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          SourceSurface(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                kPageHorizontalPadding,
                8,
                kPageHorizontalPadding,
                8,
              ),
              child: Obx(
                () => Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ChoiceChip(
                      label: Text('esj_tag_all'.tr),
                      selected: controller.selectedTag.value.isEmpty,
                      onSelected: (_) => controller.changeTag(''),
                    ),
                    ...controller.orderedTagOptions.take(6).map(
                      (tag) => ChoiceChip(
                        label: Text(tag),
                        selected: controller.selectedTag.value == tag,
                        onSelected: (_) => controller.changeTag(tag),
                      ),
                    ),
                    ActionChip(
                      label: Text(controller.tagText),
                      avatar: const Icon(Icons.expand_more),
                      onPressed: () => showModalBottomSheet<void>(
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
                      ),
                    ),
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
