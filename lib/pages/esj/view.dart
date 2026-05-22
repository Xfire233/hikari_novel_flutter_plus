import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/page_state.dart';
import 'package:hikari_novel_flutter/pages/esj/controller.dart';
import 'package:hikari_novel_flutter/widgets/browsing_novel_grid.dart';
import 'package:hikari_novel_flutter/widgets/keep_alive_wrapper.dart';
import 'package:hikari_novel_flutter/widgets/state_page.dart';

class EsjView extends StatelessWidget {
  EsjView({super.key});

  final controller = _esjController();

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

EsjController _esjController() =>
    Get.isRegistered<EsjController>() ? Get.find() : Get.put(EsjController());

class _EsjFilterBar extends StatelessWidget {
  const _EsjFilterBar({required this.controller});

  final EsjController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Obx(() {
        final tags = _visibleFrequentTags(controller.orderedTagOptions);
        final chips = <Widget>[
          _buildTagChip(
            context,
            label: 'esj_tag_all'.tr,
            selected: controller.selectedTag.value.isEmpty,
            onSelected: () => controller.changeTag(''),
          ),
          for (final tag in tags)
            _buildTagChip(
              context,
              label: tag,
              selected: controller.selectedTag.value == tag,
              onSelected: () => controller.changeTag(tag),
            ),
        ];
        return SizedBox(
          height: 52,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSortBlock(context),
              const SizedBox(width: 8),
              Expanded(child: _buildTagBlock(context, chips)),
            ],
          ),
        );
      }),
    );
  }

  List<String> _visibleFrequentTags(List<String> orderedTags) {
    final selected = controller.selectedTag.value.trim();
    final visible = <String>[];
    if (selected.isNotEmpty && orderedTags.contains(selected)) {
      visible.add(selected);
    }
    for (final tag in orderedTags) {
      if (visible.length >= 4) break;
      if (!visible.contains(tag)) visible.add(tag);
    }
    return visible;
  }

  Widget _buildSortBlock(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 126,
      child: Builder(
        builder: (sortContext) => Material(
          color: scheme.secondaryContainer.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _showSortMenu(sortContext),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 6),
                    child: Text(
                      controller.sortText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                _buildDropdownArea(
                  context,
                  tooltip: controller.sortText,
                  foreground: scheme.onSecondaryContainer,
                  background: scheme.secondaryContainer.withValues(alpha: 0.1),
                  onTap: () => _showSortMenu(sortContext),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTagBlock(BuildContext context, List<Widget> chips) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withValues(alpha: 0.54),
      borderRadius: BorderRadius.circular(18),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
              child: Row(
                children: [
                  for (var i = 0; i < chips.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    chips[i],
                  ],
                ],
              ),
            ),
          ),
          _buildDropdownArea(
            context,
            tooltip: 'esj_tag_all'.tr,
            foreground: scheme.onSurfaceVariant,
            background: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            onTap: () => _showAllTags(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 32,
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        backgroundColor: scheme.surface.withValues(alpha: 0.82),
        selectedColor: scheme.primaryContainer.withValues(alpha: 0.92),
        side: BorderSide(
          color: selected
              ? scheme.primary.withValues(alpha: 0.38)
              : scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildDropdownArea(
    BuildContext context, {
    required String tooltip,
    required Color foreground,
    required Color background,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 42,
        height: double.infinity,
        child: Material(
          color: background,
          borderRadius: const BorderRadius.horizontal(
            right: Radius.circular(18),
          ),
          child: InkWell(
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(18),
            ),
            onTap: onTap,
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 26,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }

  void _showSortMenu(BuildContext context) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final box = context.findRenderObject() as RenderBox?;
    final topLeft = box?.localToGlobal(Offset.zero, ancestor: overlay);
    final size = box?.size ?? Size.zero;
    final position = topLeft == null
        ? RelativeRect.fill
        : RelativeRect.fromRect(topLeft & size, Offset.zero & overlay.size);
    showMenu<int>(
      context: context,
      position: position,
      items: controller.sortOptions
          .map((item) => PopupMenuItem(value: item.$1, child: Text(item.$2)))
          .toList(),
    ).then((value) {
      if (value != null) controller.changeSort(value);
    });
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
