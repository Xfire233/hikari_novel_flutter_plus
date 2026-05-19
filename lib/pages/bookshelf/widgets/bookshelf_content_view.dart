import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/pages/bookshelf/controller.dart';
import 'package:responsive_grid_list/responsive_grid_list.dart';

import '../../../models/bookshelf.dart';
import '../../../models/page_state.dart';
import '../../../router/app_sub_router.dart';
import '../../../service/db_service.dart';
import '../../../widgets/keep_alive_wrapper.dart';
import '../../../widgets/local_rating_bar.dart';
import '../../../widgets/novel_cover_card.dart';
import '../../../widgets/state_page.dart';

class BookshelfContentView extends StatelessWidget {
  final String classId;
  final bool isSmartFolder;
  final List<String> smartFolderAids;
  final BookshelfController bookshelfController = Get.find();
  final BookshelfContentController controller;

  BookshelfContentView({
    super.key,
    required this.classId,
    this.isSmartFolder = false,
    this.smartFolderAids = const [],
  }) : controller = Get.put(
         BookshelfContentController(
           classId: classId,
           isSmartFolder: isSmartFolder,
           smartFolderAids: smartFolderAids,
         ),
         tag: "BookshelfContentController $classId",
       );

  @override
  Widget build(BuildContext context) {
    return KeepAliveWrapper(
      child: Obx(
        () => AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(
            key: ValueKey(
              'bookshelf-content-${controller.pageState.value}-${bookshelfController.useListView.value}',
            ),
            child: _buildStateContent(context),
          ),
        ),
      ),
    );
  }

  Widget _buildStateContent(BuildContext context) {
    return switch (controller.pageState.value) {
      PageState.success =>
        controller.bookshelf.value?.list.isNotEmpty == true
            ? controller.isTitleSort || bookshelfController.useListView.value
                  ? _buildListView(context)
                  : _buildGridView()
            : bookshelfController.currentChildFolders.isEmpty
            ? EmptyPage()
            : const SizedBox.shrink(),
      PageState.loading => const LoadingPage(),
      PageState.empty =>
        bookshelfController.currentChildFolders.isEmpty
            ? const EmptyPage()
            : const SizedBox.shrink(),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildGridView() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: ResponsiveGridList(
        minItemWidth: 100,
        horizontalGridSpacing: 4,
        verticalGridSpacing: 4,
        children: controller.bookshelf.value!.list.map((item) {
          return BookshelfCoverCard(
            bookshelfNovelInfo: item,
            onTap: () => _onTap(item.aid),
            onLongPress: () => _onLongPress(item.aid),
            onRatingChanged: (rating) => controller.setRating(item.aid, rating),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildListView(BuildContext context) {
    final list = controller.bookshelf.value!.list;
    if (controller.isTitleSort) {
      return _buildAlphabetIndexedListView(context, list);
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: list.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        return _buildListRow(context, list[index]);
      },
    );
  }

  Widget _buildAlphabetIndexedListView(
    BuildContext context,
    List<BookshelfNovelInfo> list,
  ) {
    final activeLetters = {
      for (final item in list)
        BookshelfContentController.titleInitial(item.title),
    };
    final sectionKeys = {
      for (final letter in activeLetters) letter: GlobalKey(),
    };
    final children = <Widget>[];
    var previousLetter = '';
    for (final item in list) {
      final letter = BookshelfContentController.titleInitial(item.title);
      if (letter != previousLetter) {
        previousLetter = letter;
        children.add(
          Padding(
            key: sectionKeys[letter],
            padding: const EdgeInsets.fromLTRB(16, 12, 40, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                letter,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      }
      children
        ..add(_buildListRow(context, item))
        ..add(const Divider(height: 1));
    }

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(children: children),
        ),
        Positioned.fill(
          child: Align(
            alignment: Alignment.centerRight,
            child: _AlphabetIndexBar(
              activeLetters: activeLetters,
              onSelect: (letter) {
                final target = sectionKeys[letter]?.currentContext;
                if (target == null) return;
                Scrollable.ensureVisible(
                  target,
                  duration: Duration.zero,
                  alignment: 0,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListRow(BuildContext context, BookshelfNovelInfo item) {
    return Obx(
      () => InkWell(
        onTap: () => _onTap(item.aid),
        onLongPress: () => _onLongPress(item.aid),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              controller.isSelectionMode
                  ? Checkbox(
                      value: item.isSelected.value,
                      onChanged: (_) =>
                          controller.toggleCoverSelection(item.aid),
                    )
                  : const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.article_outlined),
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: controller.isTitleSort ? 20 : 0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines:
                                  (controller.isYamiboBookshelf ||
                                      controller.isEsjBookshelf)
                                  ? 8
                                  : 4,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: item.isSelected.value
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: item.isSelected.value
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                            ),
                          ),
                          if (item.hasUpdate)
                            _buildBadge(
                              context,
                              label: "updated".tr,
                              color: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onPrimary,
                            )
                          else if (item.isReadComplete)
                            _buildBadge(
                              context,
                              label: "read_complete".tr,
                              color: Theme.of(
                                context,
                              ).colorScheme.secondaryContainer,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onSecondaryContainer,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _metadataLine(item),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          LocalRatingBar(
                            rating: item.rating,
                            onChanged: (rating) =>
                                controller.setRating(item.aid, rating),
                            size: 16,
                            compact: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _metadataLine(BookshelfNovelInfo item) {
    return [
      if (item.author.trim().isNotEmpty) item.author.trim(),
      if (item.sourceLabel.trim().isNotEmpty) item.sourceLabel.trim(),
    ].join(' / ');
  }

  Widget _buildBadge(
    BuildContext context, {
    required String label,
    required Color color,
    required Color foregroundColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 8, top: 1),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  void _onTap(String aid) {
    if (controller.isSelectionMode) {
      controller.toggleCoverSelection(aid);
    } else {
      DBService.instance.clearBookshelfUpdate(aid);
      AppSubRouter.toNovelDetail(aid: aid);
    }
  }

  void _onLongPress(String aid) {
    if (!controller.isSelectionMode) {
      controller.enterSelectionMode();
      controller.toggleCoverSelection(aid);
    }
  }
}

class _AlphabetIndexBar extends StatelessWidget {
  const _AlphabetIndexBar({
    required this.activeLetters,
    required this.onSelect,
  });

  static const _letters = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
    '#',
  ];

  final Set<String> activeLetters;
  final void Function(String letter) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      left: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (details) =>
                _selectAt(details.localPosition.dy, constraints.maxHeight),
            onVerticalDragUpdate: (details) =>
                _selectAt(details.localPosition.dy, constraints.maxHeight),
            child: Container(
              width: 28,
              margin: const EdgeInsets.only(right: 2),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: _letters.map((letter) {
                  final active = activeLetters.contains(letter);
                  return Expanded(
                    child: Center(
                      child: Text(
                        letter,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: active
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  void _selectAt(double dy, double height) {
    if (height <= 0 || activeLetters.isEmpty) return;
    final index = (dy / height * _letters.length).floor().clamp(
      0,
      _letters.length - 1,
    );
    final letter = _nearestActiveLetter(index);
    if (letter != null) onSelect(letter);
  }

  String? _nearestActiveLetter(int index) {
    final current = _letters[index];
    if (activeLetters.contains(current)) return current;
    for (var offset = 1; offset < _letters.length; offset++) {
      final forward = index + offset;
      if (forward < _letters.length &&
          activeLetters.contains(_letters[forward])) {
        return _letters[forward];
      }
      final backward = index - offset;
      if (backward >= 0 && activeLetters.contains(_letters[backward])) {
        return _letters[backward];
      }
    }
    return null;
  }
}
