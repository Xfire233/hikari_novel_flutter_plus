import 'package:blur/blur.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:expandable_text/expandable_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/common/constants.dart';
import 'package:hikari_novel_flutter/models/page_state.dart';
import 'package:hikari_novel_flutter/models/reader_direction.dart';
import 'package:hikari_novel_flutter/models/source_config.dart';
import 'package:hikari_novel_flutter/pages/novel_detail/controller.dart';
import 'package:hikari_novel_flutter/pages/novel_detail/widgets/bottom_text_icon_button.dart';
import 'package:hikari_novel_flutter/pages/novel_detail/widgets/icon_text.dart';
import 'package:hikari_novel_flutter/router/app_sub_router.dart';
import 'package:hikari_novel_flutter/router/route_path.dart';
import 'package:hikari_novel_flutter/service/db_service.dart';

import '../../network/request.dart';
import '../../service/local_storage_service.dart';
import '../../widgets/local_rating_bar.dart';
import '../../widgets/source_backdrop.dart';
import '../../widgets/state_page.dart';

class NovelDetailPage extends StatefulWidget {
  final String aid;

  const NovelDetailPage({super.key, required this.aid});

  @override
  State<NovelDetailPage> createState() => _NovelDetailPageState();
}

class _NovelDetailPageState extends State<NovelDetailPage> {
  late final NovelDetailController controller;
  final RxDouble _opacity = 0.0.obs;
  final ScrollController _scrollController = ScrollController();

  bool _isFabVisible = false;

  @override
  void initState() {
    super.initState();

    Get.delete<NovelDetailController>();
    controller = Get.put(NovelDetailController(aid: widget.aid));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isWenku8 => !controller.isEsj && !controller.isYamibo;

  NovelSource get _source => controller.isEsj
      ? NovelSource.esj
      : controller.isYamibo
      ? NovelSource.yamibo
      : NovelSource.wenku8;

  bool _hasText(String value) => value.trim().isNotEmpty;

  bool _hasSourceMetadata(String value) {
    final text = value.trim();
    if (text.isEmpty) return false;
    if (controller.isYamibo && text == 'Yamibo') return false;
    if (controller.isEsj && text == 'ESJZone') return false;
    return true;
  }

  List<String> _visibleTags(List<String> tags) {
    return tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
  }

  List<String> _allVisibleTags() {
    final detailTags = controller.novelDetail.value?.tags ?? const <String>[];
    return _visibleTags([
      ...detailTags,
      ...controller.remoteTags,
      ...controller.localTags,
    ]);
  }

  bool _usableCoverUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  Widget _buildDetailCoverImage(
    BuildContext context, {
    required String url,
    required double width,
    double? height,
    required String title,
    required BoxFit fit,
    bool subtle = false,
  }) {
    if (url.isEmpty) {
      return SizedBox(
        width: width,
        height: height,
        child: _DetailCoverPlaceholder(
          title: title,
          source: _source,
          subtle: subtle,
        ),
      );
    }
    return CachedNetworkImage(
      width: width,
      height: height,
      imageUrl: url,
      httpHeaders: Request.userAgent,
      fit: fit,
      progressIndicatorBuilder: (context, url, downloadProgress) => Center(
        child: CircularProgressIndicator(value: downloadProgress.progress),
      ),
      errorWidget: (context, url, error) => _DetailCoverPlaceholder(
        title: title,
        source: _source,
        subtle: subtle,
      ),
    );
  }

  VoidCallback? _authorSearchAction(String author) {
    if (!_hasSourceMetadata(author)) return null;
    if (_isWenku8) {
      return () => AppSubRouter.toSearch(author: author);
    }
    if (controller.isEsj) {
      return () => AppSubRouter.toEsjSearch(keyword: author);
    }
    if (controller.isYamibo && controller.yamiboAuthorId.isNotEmpty) {
      return () => AppSubRouter.toYamiboAuthorThreads(
        authorName: author,
        authorId: controller.yamiboAuthorId,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Obx(
          () => Offstage(
            offstage: controller.pageState.value != PageState.success,
            child: _buildPage(context),
          ),
        ),
        Obx(
          () => Offstage(
            offstage: controller.pageState.value != PageState.loading,
            child: _buildLoadingPage(),
          ),
        ),
        Obx(
          () => Offstage(
            offstage: controller.pageState.value != PageState.error,
            child: _buildErrorPage(),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingPage() => Scaffold(
    appBar: AppBar(),
    body: _buildBackdrop(
      Obx(
        () => LoadingPage(
          message: controller.loadingMessage.value.isEmpty
              ? null
              : controller.loadingMessage.value,
        ),
      ),
    ),
  );

  Widget _buildErrorPage() => Scaffold(
    appBar: AppBar(),
    body: _buildBackdrop(
      ErrorMessage(
        msg: controller.errorMsg,
        action: controller.getNovelDetail,
        extraAction: controller.isYamibo ? controller.openWithBrowser : null,
        extraButtonText: controller.isYamibo ? 'yamibo_open_web' : null,
        extraIconData: Icons.open_in_browser,
      ),
    ),
  );

  Widget _buildBackdrop(Widget child) {
    return SourceBackdrop(source: _source, child: child);
  }

  Widget _buildPage(BuildContext context) {
    return Obx(
      () => controller.novelDetail.value == null
          ? _buildLoadingPage()
          : Obx(
              () => Scaffold(
                extendBodyBehindAppBar: true,
                appBar: _buildAppBar(context),
                body: _buildBackdrop(
                  NotificationListener<Notification>(
                    onNotification: (Notification notification) {
                      if (notification is UserScrollNotification) {
                        if (!_isFabVisible) return false;

                        final direction = notification.direction;
                        if (direction == ScrollDirection.forward) {
                          controller.showFab();
                        } else if (direction == ScrollDirection.reverse) {
                          controller.hideFab();
                        }
                      } else if (notification is ScrollNotification) {
                        final double offset = notification.metrics.pixels;
                        _opacity.value = offset > 0 ? 1 : 0;
                      }
                      return false;
                    },
                    child: Obx(() {
                      //濡傛灉澶勪簬澶氶€夋ā寮忎笅锛屽簲璇ユ殏鏃剁Щ闄ゅ埛鏂板姛鑳?
                      return RefreshIndicator(
                        onRefresh: controller.isSelectionMode.value
                            ? () async {}
                            : controller.getNovelDetail,
                        edgeOffset:
                            kToolbarHeight + MediaQuery.of(context).padding.top,
                        child: _buildContent(context),
                      );
                    }),
                  ),
                ),
                floatingActionButton: _buildContinueFab(),
                bottomNavigationBar: _buildBottomBar(context),
              ),
            ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return GetBuilder(
      id: "customScrollView",
      init: controller,
      builder: (_) => CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildInfo(context)),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ExpandableText(
                controller.novelDetail.value!.introduce,
                maxLines: 3,
                expandText: "expand".tr,
                collapseText: "collapse".tr,
                linkColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          if (_allVisibleTags().isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allVisibleTags()
                      .map(
                        (e) => ActionChip(
                          label: Text(e),
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                          onPressed: controller.isEsj
                              ? () => AppSubRouter.toEsjTagSearch(tag: e)
                              : null,
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          SliverToBoxAdapter(child: _buildLocalTagEditor(context)),
          if (controller.isYamibo)
            SliverToBoxAdapter(child: _buildYamiboCatalogueStatus(context)),
          SliverToBoxAdapter(
            child: SizedBox(height: _allVisibleTags().isEmpty ? 10 : 20),
          ),
          SliverToBoxAdapter(
            child: Obx(() {
              final value = controller.isChapterOrderReversed.value;
              return Row(
                children: [
                  const SizedBox(width: 10),
                  TextButton.icon(
                    onPressed: () {
                      controller.isChapterOrderReversed.toggle();
                      controller.update([
                        "customScrollView",
                      ]); //閫氱煡閲嶇粯CustomScrollView
                    },
                    icon: value
                        ? const Icon(Icons.arrow_upward)
                        : const Icon(Icons.arrow_downward),
                    label: Text(value ? "descending".tr : "ascending".tr),
                  ),
                  const Spacer(),
                ],
              );
            }),
          ),
          _buildCatalogueSliver(context),
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.of(context).padding.bottom),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    if (controller.isSelectionMode.value) {
      return AppBar(
        automaticallyImplyLeading: false,
        leading: CloseButton(onPressed: controller.exitSelectionMode),
        title: Text(controller.getSelectedCount().toString()),
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        titleSpacing: 16,
        actions: [
          IconButton(
            onPressed: controller.selectAll,
            icon: const Icon(Icons.select_all),
          ),
          IconButton(
            onPressed: controller.deselect,
            icon: const Icon(Icons.deselect),
          ),
        ],
      );
    }

    return AppBar(
      systemOverlayStyle: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      backgroundColor: _opacity.value == 0
          ? Colors.transparent
          : Theme.of(context).colorScheme.surface,
      title: Obx(
        () => AnimatedOpacity(
          opacity: _opacity.value,
          duration: const Duration(milliseconds: 200),
          child: Text(controller.novelDetail.value!.title),
        ),
      ),
      titleSpacing: 16,
      actions: [
        IconButton(
          onPressed: controller.enterSelectionMode,
          icon: Icon(Icons.download_outlined),
          tooltip: "cache".tr,
        ),
        PopupMenuButton<_MenuItem>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == _MenuItem.cacheQueue) {
              AppSubRouter.toCacheQueue();
            } else if (value == _MenuItem.deleteCache) {
              controller.deleteCache();
            } else if (value == _MenuItem.delAllReadHistory) {
              controller.deleteAllReadHistory();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _MenuItem.cacheQueue,
              child: Text("view_cache_queue".tr),
            ),
            PopupMenuItem(
              value: _MenuItem.deleteCache,
              child: Text("delete_cache".tr),
            ),
            PopupMenuItem(
              value: _MenuItem.delAllReadHistory,
              child: Text("del_all_read_history".tr),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildYamiboCatalogueStatus(BuildContext context) {
    return Obx(() {
      final status = controller.yamiboCatalogueStatus.value.trim();
      final building = controller.yamiboCatalogueBuilding.value;
      if (!building && status.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(kCardBorderRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                if (building) ...[
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                ] else ...[
                  const Icon(Icons.check_circle_outline, size: 18),
                  const SizedBox(width: 10),
                ],
                Expanded(child: Text(status)),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildLocalTagEditor(BuildContext context) {
    return Obx(() {
      final tags = controller.localTags.toList();
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final tag in tags)
              InputChip(
                label: Text(tag),
                onDeleted: () {
                  final next = tags.where((item) => item != tag).toList();
                  controller.setLocalTags(next);
                },
              ),
            ActionChip(
              avatar: const Icon(Icons.add),
              label: Text('local_tag_add'.tr),
              onPressed: () => _showAddLocalTagDialog(context, tags),
            ),
          ],
        ),
      );
    });
  }

  void _showAddLocalTagDialog(BuildContext context, List<String> tags) {
    final textController = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: Text('local_tag_add'.tr),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: InputDecoration(hintText: 'local_tag_hint'.tr),
          onSubmitted: (_) {
            final value = textController.text.trim();
            if (value.isNotEmpty) controller.setLocalTags([...tags, value]);
            Get.back();
          },
        ),
        actions: [
          TextButton(onPressed: Get.back, child: Text('cancel'.tr)),
          TextButton(
            onPressed: () {
              final value = textController.text.trim();
              if (value.isNotEmpty) controller.setLocalTags([...tags, value]);
              Get.back();
            },
            child: Text('confirm'.tr),
          ),
        ],
      ),
    );
  }

  Widget _buildInfo(BuildContext context) {
    final detail = controller.novelDetail.value!;
    final coverUrl = _usableCoverUrl(detail.imgUrl) ? detail.imgUrl.trim() : '';
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 1),
            child: Blur(
              blur: 3,
              blurColor: Theme.of(context).colorScheme.surface,
              child: _buildDetailCoverImage(
                context,
                url: coverUrl,
                width: double.infinity,
                title: detail.title,
                fit: BoxFit.fitWidth,
                subtle: true,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                  Theme.of(context).colorScheme.surface.withValues(alpha: 1),
                ],
              ),
            ),
          ),
        ),
        Column(
          children: [
            SizedBox(
              height: kToolbarHeight + MediaQuery.of(context).padding.top + 10,
            ),
            Row(
              children: [
                const SizedBox(width: 20),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(kCardBorderRadius),
                  ),
                  elevation: 0,
                  clipBehavior: Clip.hardEdge,
                  child: GestureDetector(
                    onTap: coverUrl.isEmpty
                        ? null
                        : () => Get.toNamed(
                            RoutePath.photo,
                            arguments: {"gallery_mode": false, "url": coverUrl},
                          ),
                    child: _buildDetailCoverImage(
                      context,
                      url: coverUrl,
                      width: 120,
                      height: 180,
                      title: detail.title,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_hasSourceMetadata(detail.author)) ...[
                        _authorSearchAction(detail.author) != null
                            ? GestureDetector(
                                onTap: _authorSearchAction(detail.author),
                                child: IconText(
                                  icon: Icons.person_outline,
                                  text: detail.author,
                                  color: Theme.of(context).colorScheme.primary,
                                  bold: true,
                                ),
                              )
                            : IconText(
                                icon: Icons.person_outline,
                                text: detail.author,
                                bold: true,
                              ),
                        const SizedBox(height: 4),
                      ],
                      if (_hasSourceMetadata(detail.status)) ...[
                        IconText(icon: Icons.schedule, text: detail.status),
                        const SizedBox(height: 4),
                      ],
                      if (_hasText(detail.finUpdate)) ...[
                        IconText(icon: Icons.update, text: detail.finUpdate),
                        const SizedBox(height: 4),
                      ],
                      if (_isWenku8) ...[
                        IconText(
                          icon: Icons.tv,
                          text: detail.isAnimated
                              ? "animated".tr
                              : "unanimated".tr,
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (_isWenku8 && _hasText(detail.heat)) ...[
                        IconText(
                          icon: Icons.local_fire_department_outlined,
                          text: detail.heat,
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (_isWenku8 && _hasText(detail.trending))
                        IconText(
                          icon: Icons.trending_up,
                          text: detail.trending,
                        ),
                      const SizedBox(height: 8),
                      Obx(
                        () => Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Icon(
                              Icons.star_outline,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            LocalRatingBar(
                              rating: controller.localRating.value,
                              onChanged: controller.setLocalRating,
                              size: 18,
                              compact: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Obx(
                    () => BottomTextIconButton(
                      label: controller.isInBookshelf.value
                          ? "favorited".tr
                          : "favorite".tr,
                      icon: controller.isInBookshelf.value
                          ? Icons.favorite
                          : Icons.favorite_outline,
                      onPressed: () => controller.isInBookshelf.value
                          ? controller.removeFromBookshelf()
                          : controller.addToBookshelf(),
                    ),
                  ),
                  if (_isWenku8)
                    BottomTextIconButton(
                      label: "recommend".tr,
                      icon: Icons.recommend_outlined,
                      onPressed: controller.recommendThisNovel,
                    ),
                  BottomTextIconButton(
                    label: "Web",
                    icon: Icons.public,
                    onPressed: controller.openWithBrowser,
                  ),
                  if (_isWenku8)
                    BottomTextIconButton(
                      label: "comment".tr,
                      icon: Icons.comment_outlined,
                      onPressed: () => AppSubRouter.toComment(aid: widget.aid),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ],
    );
  }

  //灏嗙洰褰曟瀯寤轰负涓€涓?Sliver锛堟瘡涓嵎浣滀负涓€涓?item锛?
  Widget _buildCatalogueSliver(BuildContext context) {
    final detail = controller.novelDetail.value!;

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, volumeIndex) {
        if (controller.isChapterOrderReversed.value) {
          volumeIndex = detail.catalogue.length - volumeIndex - 1;
        }
        final volume = detail.catalogue[volumeIndex];
        final volumeCids = volume.chapters
            .map((catChapter) => catChapter.cid)
            .toList();
        final totalChaps = volume.chapters.length;

        //姣忎釜鍗风敤涓€涓?Card/ExpansionTile 琛ㄧず锛涘唴閮ㄧ珷鑺備娇鐢?ListTile 鍒楄〃
        return StreamBuilder(
          stream: DBService.instance.getWatchableReadHistoryByVolume(
            controller.aid,
            volumeCids,
          ),
          builder: (context, volumeSnapshot) => Obx(() {
            final selectedChaps = volume.chapters
                .where((c) => c.isSelected.value)
                .length;
            final isPartiallySelected =
                selectedChaps > 0 && selectedChaps < totalChaps;
            final bool? volumeCheckboxValue =
                selectedChaps == totalChaps && totalChaps > 0
                ? true
                : (isPartiallySelected ? null : false);

            final volumeSubtitle = controller.getReadHistoryProgressByVolume(
              volumeSnapshot.data ?? [],
              volume.chapters.length,
            );

            Color volumeTitleColor = Theme.of(
              context,
            ).colorScheme.onSurface; // 榛樿棰滆壊
            Color volumeSubtitleColor = Theme.of(context).colorScheme.primary;

            if (volumeSubtitle == "all_reading_completed".tr) {
              volumeTitleColor = Theme.of(
                context,
              ).disabledColor; // 宸茶瀹岋紝瀛椾綋鍙樼伆
              volumeSubtitleColor = Theme.of(context).disabledColor;
            }

            return GestureDetector(
              onLongPress: () {
                if (!controller.isSelectionMode.value) {
                  controller.enterSelectionMode();
                  controller.toggleVolumeSelection(volumeIndex);
                }
              },
              child: ExpansionTile(
                key: PageStorageKey("volume_$volumeIndex"),
                shape: const Border(),
                leading: controller.isSelectionMode.value
                    ? Checkbox(
                        tristate: true,
                        value: volumeCheckboxValue,
                        onChanged: (bool? v) {
                          final makeSelected = v == true;
                          final volumeRef = controller
                              .novelDetail
                              .value!
                              .catalogue[volumeIndex];
                          for (final c in volumeRef.chapters) {
                            c.isSelected.value = makeSelected;
                          }
                        },
                      )
                    : null,
                title: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    volume.title,
                    style: TextStyle(fontSize: 15, color: volumeTitleColor),
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    volumeSubtitle,
                    style: TextStyle(fontSize: 13, color: volumeSubtitleColor),
                  ),
                ),
                children: volume.chapters.asMap().entries.map((entry) {
                  final chapterIndex = entry.key;
                  final chapter = entry.value;

                  controller.checkIsChapterCached(chapter.cid);

                  //浣跨敤FutureBuilder澶勭悊寮傛鐨勯槄璇诲巻鍙叉暟鎹?
                  return StreamBuilder(
                    stream: DBService.instance.getWatchableReadHistoryByCid(
                      controller.aid,
                      chapter.cid,
                    ),
                    builder: (context, chapterSnapshot) {
                      return Obx(() {
                        Color chapterTitleColor = Theme.of(
                          context,
                        ).colorScheme.onSurface; // 榛樿棰滆壊
                        Color chapterSubtitleColor = Theme.of(
                          context,
                        ).colorScheme.primary;

                        final readHistory = chapterSnapshot.data;
                        if (readHistory != null &&
                            readHistory.progress == 100) {
                          chapterTitleColor = Theme.of(
                            context,
                          ).disabledColor; // 宸茶瀹岋紝瀛椾綋鍙樼伆
                          chapterSubtitleColor = Theme.of(
                            context,
                          ).disabledColor;
                        }

                        var cacheString =
                            controller.cachedChapter.contains(chapter.cid)
                            ? " · ${"cached".tr}"
                            : "";
                        var lastReadString = readHistory?.isLatest == true
                            ? "${"last_read".tr} · "
                            : "";

                        return ListTile(
                          leading: controller.isSelectionMode.value
                              ? Checkbox(
                                  value: chapter.isSelected.value,
                                  onChanged: (_) =>
                                      controller.toggleChapterSelection(
                                        volumeIndex,
                                        chapterIndex,
                                      ),
                                )
                              : null,
                          title: Text(
                            chapter.title,
                            style: TextStyle(
                              fontSize: 13,
                              color: chapterTitleColor,
                            ),
                          ),
                          subtitle: Text(
                            lastReadString +
                                controller.getReadHistoryProgressByCid(
                                  chapterSnapshot.data,
                                ) +
                                cacheString,
                            style: TextStyle(
                              fontSize: 13,
                              color: chapterSubtitleColor,
                            ),
                            overflow: TextOverflow.clip,
                          ),
                          contentPadding: const EdgeInsets.only(
                            left: 50.0,
                            right: 24.0,
                          ),
                          onTap: () async {
                            if (controller.isSelectionMode.value) {
                              controller.toggleChapterSelection(
                                volumeIndex,
                                chapterIndex,
                              );
                              return;
                            }

                            //鑾峰彇涓婃闃呰鐨勪綅缃?
                            final history = await DBService.instance
                                .getReadHistoryByCid(
                                  controller.aid,
                                  chapter.cid,
                                );
                            var location =
                                0; //娌℃湁璁板綍鎴栬€呮湁涓嶉€傜敤鐨勮褰曞垯浠庡ご寮€濮嬮槄璇伙紙鍗抽槄璇讳綅缃负0锛?
                            final currDirection = LocalStorageService.instance
                                .getReaderDirection();
                            if ((history?.readerMode == kScrollReadMode &&
                                    currDirection ==
                                        ReaderDirection.upToDown) ||
                                (history?.readerMode == kPageReadMode &&
                                    (currDirection ==
                                            ReaderDirection.leftToRight ||
                                        currDirection ==
                                            ReaderDirection.rightToLeft))) {
                              location = history?.location ?? 0;
                            }
                            Get.toNamed(
                              RoutePath.reader,
                              parameters: {
                                "cid": chapter.cid,
                                "location": "$location",
                              },
                            );
                          },
                          onLongPress: () {
                            if (!controller.isSelectionMode.value) {
                              controller.enterSelectionMode();
                            }
                            controller.toggleChapterSelection(
                              volumeIndex,
                              chapterIndex,
                            );
                          },
                        );
                      });
                    },
                  );
                }).toList(),
              ),
            );
          }),
        );
      }, childCount: detail.catalogue.length),
    );
  }

  Widget _buildContinueFab() {
    return Obx(
      () => Offstage(
        offstage: controller.isSelectionMode.value,
        child: StreamBuilder(
          stream: DBService.instance.getLastestReadHistoryByAid(controller.aid),
          builder: (_, snapshot) {
            if (snapshot.data == null ||
                !controller.isValidReadHistory(snapshot.data)) {
              _isFabVisible = false;
              return Container();
            }
            _isFabVisible = true;
            final history = snapshot.data;
            return SlideTransition(
              position: controller.animation,
              child: FloatingActionButton.extended(
                onPressed: () {
                  if (history == null) return;
                  Get.toNamed(
                    RoutePath.reader,
                    parameters: {
                      "cid": history.cid,
                      "location": "${history.location}",
                    },
                  );
                },
                label: Row(
                  children: [
                    const Icon(Icons.play_arrow),
                    const SizedBox(width: 10),
                    Text("continue_reading".tr),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    return Obx(
      () => Offstage(
        offstage: !controller.isSelectionMode.value,
        child: BottomAppBar(
          height: 72,
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () async {
                    //TODO 涓嬭浇鏁伴噺闄愬埗
                    await controller.startCache();
                    controller.exitSelectionMode();
                    AppSubRouter.toCacheQueue();
                  },
                  icon: Icon(Icons.download_outlined, color: onSurfaceColor),
                  label: Text(
                    "cache".tr,
                    style: TextStyle(color: onSurfaceColor),
                  ),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () async {
                    await controller.markAsRead();
                    controller.exitSelectionMode();
                  },
                  icon: Icon(Icons.done_all, color: onSurfaceColor),
                  label: Text(
                    "mark_as_read".tr,
                    style: TextStyle(color: onSurfaceColor),
                  ),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () async {
                    await controller.markAsUnRead();
                    controller.exitSelectionMode();
                  },
                  icon: Icon(Icons.remove_done, color: onSurfaceColor),
                  label: Text(
                    "mark_as_unread".tr,
                    style: TextStyle(color: onSurfaceColor),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailCoverPlaceholder extends StatelessWidget {
  const _DetailCoverPlaceholder({
    required this.title,
    required this.source,
    this.subtle = false,
  });

  final String title;
  final NovelSource source;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = SourceBackdropPalette.of(context, source);
    return ColoredBox(
      color: Color.lerp(
        scheme.surfaceContainerHighest,
        palette.backgroundStart,
        subtle ? 0.35 : 0.55,
      )!,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -18,
            bottom: -14,
            child: SourceMark(
              source: source,
              size: subtle ? 160 : 96,
              color: palette.mark,
              opacity: subtle ? 0.10 : 0.16,
            ),
          ),
          if (!subtle)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Center(
                child: Text(
                  title,
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _MenuItem { deleteCache, cacheQueue, delAllReadHistory }
