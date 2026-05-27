import 'dart:async';

import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/novel_cover.dart';
import 'package:hikari_novel_flutter/pages/home/controller.dart';
import 'package:hikari_novel_flutter/router/app_sub_router.dart';
import 'package:hikari_novel_flutter/service/local_storage_service.dart';
import 'package:hikari_novel_flutter/service/volume_key_service.dart';
import 'package:hikari_novel_flutter/widgets/novel_cover_card.dart';
import 'package:responsive_grid_list/responsive_grid_list.dart';

class BrowsingNovelGrid extends StatelessWidget {
  const BrowsingNovelGrid({
    super.key,
    required this.data,
    required this.onRefresh,
    required this.onLoad,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.page,
    required this.canPreviousPage,
    required this.canNextPage,
    this.easyRefreshController,
    this.forceListView = false,
    this.guardHomeRefresh = false,
  });

  final List<NovelCover> data;
  final Future<IndicatorResult> Function() onRefresh;
  final Future<IndicatorResult> Function() onLoad;
  final Future<IndicatorResult> Function() onPreviousPage;
  final Future<IndicatorResult> Function() onNextPage;
  final int page;
  final bool canPreviousPage;
  final bool canNextPage;
  final EasyRefreshController? easyRefreshController;
  final bool forceListView;
  final bool guardHomeRefresh;

  @override
  Widget build(BuildContext context) {
    if (forceListView) return _buildList(context);

    final grid = ResponsiveGridList(
      minItemWidth: 100,
      horizontalGridSpacing: 4,
      verticalGridSpacing: 4,
      children: data.map((item) => NovelCoverCard(novelCover: item)).toList(),
    );
    if (!LocalStorageService.instance.getBrowsingEInkMode()) {
      return _buildRefreshContainer(child: grid);
    }

    return BrowsingPageMode(
      page: page,
      canPreviousPage: canPreviousPage,
      canNextPage: canNextPage,
      onPreviousPage: onPreviousPage,
      onNextPage: onNextPage,
      onRefresh: onRefresh,
      localPageCountBuilder: (constraints) =>
          _gridMetrics(constraints, data.length).pageCount,
      contentBuilder: (context, constraints, localPage) {
        final metrics = _gridMetrics(constraints, data.length);
        final start = localPage * metrics.itemsPerPage;
        final end = (start + metrics.itemsPerPage).clamp(0, data.length);
        final visibleItems = start >= data.length
            ? <NovelCover>[]
            : data.sublist(start, end);

        return GridView.builder(
          padding: const EdgeInsets.all(4),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: metrics.crossAxisCount,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            childAspectRatio: 9 / 13.5,
          ),
          itemCount: visibleItems.length,
          itemBuilder: (_, index) =>
              NovelCoverCard(novelCover: visibleItems[index]),
        );
      },
    );
  }

  Widget _buildList(BuildContext context) {
    final list = ListView.separated(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 18),
      itemCount: data.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, index) => _NovelTitleListTile(novel: data[index]),
    );
    if (!LocalStorageService.instance.getBrowsingEInkMode()) {
      return _buildRefreshContainer(child: list);
    }

    return BrowsingPageMode(
      page: page,
      canPreviousPage: canPreviousPage,
      canNextPage: canNextPage,
      onPreviousPage: onPreviousPage,
      onNextPage: onNextPage,
      onRefresh: onRefresh,
      contentKey: 'list|$page|${data.length}',
      localPageCountBuilder: (constraints) =>
          _listMetrics(constraints, data.length).pageCount,
      contentBuilder: (context, constraints, localPage) {
        final metrics = _listMetrics(constraints, data.length);
        final start = localPage * metrics.itemsPerPage;
        final end = (start + metrics.itemsPerPage).clamp(0, data.length);
        final visibleItems = start >= data.length
            ? <NovelCover>[]
            : data.sublist(start, end);

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visibleItems.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, index) =>
              _NovelTitleListTile(novel: visibleItems[index], dense: true),
        );
      },
    );
  }

  static _GridPageMetrics _gridMetrics(BoxConstraints constraints, int count) {
    final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 360.0;
    final height = constraints.maxHeight.isFinite
        ? constraints.maxHeight
        : 560.0;
    const horizontalPadding = 8.0;
    const verticalPadding = 8.0;
    const spacing = 2.0;
    const minCardWidth = 80.0;
    final usableWidth = (width - horizontalPadding).clamp(1.0, width);
    final usableHeight = (height - verticalPadding).clamp(1.0, height);
    final crossAxisCount = (usableWidth / minCardWidth).floor().clamp(3, 14);
    final cardWidth =
        (usableWidth - spacing * (crossAxisCount - 1)) / crossAxisCount;
    final cardHeight = cardWidth * 13.5 / 9;
    final rows = ((usableHeight + spacing) / (cardHeight + spacing))
        .floor()
        .clamp(1, 12);
    final itemsPerPage = (crossAxisCount * rows).clamp(1, 64);
    final pageCount = count <= 0
        ? 1
        : ((count + itemsPerPage - 1) ~/ itemsPerPage);
    return _GridPageMetrics(
      crossAxisCount: crossAxisCount,
      itemsPerPage: itemsPerPage,
      pageCount: pageCount,
    );
  }

  Widget _buildRefreshContainer({required Widget child}) {
    final controller = easyRefreshController;
    if (!guardHomeRefresh || !Get.isRegistered<HomeController>()) {
      return _EasyRefreshWithFooterReset(
        controller: controller,
        onRefresh: onRefresh,
        onLoad: onLoad,
        child: child,
      );
    }
    final home = Get.find<HomeController>();
    return Obx(() {
      final refreshEnabled = home.homePullRefreshEnabled;
      return _EasyRefreshWithFooterReset(
        controller: controller,
        onRefresh: refreshEnabled ? onRefresh : null,
        onLoad: onLoad,
        child: child,
      );
    });
  }

  static _ListPageMetrics _listMetrics(BoxConstraints constraints, int count) {
    final height = constraints.maxHeight.isFinite
        ? constraints.maxHeight
        : 560.0;
    const verticalPadding = 12.0;
    const itemHeight = 82.0;
    final usableHeight = (height - verticalPadding).clamp(1.0, height);
    final itemsPerPage = (usableHeight / itemHeight).floor().clamp(1, 30);
    final pageCount = count <= 0
        ? 1
        : ((count + itemsPerPage - 1) ~/ itemsPerPage);
    return _ListPageMetrics(itemsPerPage: itemsPerPage, pageCount: pageCount);
  }
}

class _EasyRefreshWithFooterReset extends StatefulWidget {
  const _EasyRefreshWithFooterReset({
    required this.child,
    required this.onLoad,
    this.controller,
    this.onRefresh,
  });

  final EasyRefreshController? controller;
  final Future<IndicatorResult> Function()? onRefresh;
  final Future<IndicatorResult> Function()? onLoad;
  final Widget child;

  @override
  State<_EasyRefreshWithFooterReset> createState() =>
      _EasyRefreshWithFooterResetState();
}

class _EasyRefreshWithFooterResetState
    extends State<_EasyRefreshWithFooterReset> {
  @override
  void initState() {
    super.initState();
    _resetFooterAfterAttach();
  }

  @override
  void didUpdateWidget(covariant _EasyRefreshWithFooterReset oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _resetFooterAfterAttach();
    }
  }

  @override
  Widget build(BuildContext context) {
    return EasyRefresh(
      controller: widget.controller,
      onRefresh: widget.onRefresh,
      onLoad: widget.onLoad,
      child: widget.child,
    );
  }

  void _resetFooterAfterAttach() {
    final controller = widget.controller;
    if (controller == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      controller.resetFooter();
    });
  }
}

class _GridPageMetrics {
  const _GridPageMetrics({
    required this.crossAxisCount,
    required this.itemsPerPage,
    required this.pageCount,
  });

  final int crossAxisCount;
  final int itemsPerPage;
  final int pageCount;
}

class _ListPageMetrics {
  const _ListPageMetrics({required this.itemsPerPage, required this.pageCount});

  final int itemsPerPage;
  final int pageCount;
}

class _NovelTitleListTile extends StatelessWidget {
  const _NovelTitleListTile({required this.novel, this.dense = false});

  final NovelCover novel;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: dense,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      leading: const Icon(Icons.menu_book_outlined),
      title: Text(
        novel.title,
        softWrap: true,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(height: 1.28),
      ),
      onTap: () => AppSubRouter.toNovelDetail(aid: novel.aid, cover: novel),
    );
  }
}

class BrowsingPageMode extends StatefulWidget {
  const BrowsingPageMode({
    super.key,
    required this.page,
    required this.canPreviousPage,
    required this.canNextPage,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onRefresh,
    this.child,
    this.localPageCountBuilder,
    this.contentBuilder,
    this.contentKey,
  }) : assert(
         child != null ||
             (localPageCountBuilder != null && contentBuilder != null),
       );

  final Widget? child;
  final int page;
  final bool canPreviousPage;
  final bool canNextPage;
  final Future<IndicatorResult> Function() onPreviousPage;
  final Future<IndicatorResult> Function() onNextPage;
  final Future<IndicatorResult> Function() onRefresh;
  final int Function(BoxConstraints constraints)? localPageCountBuilder;
  final Widget Function(
    BuildContext context,
    BoxConstraints constraints,
    int localPage,
  )?
  contentBuilder;
  final Object? contentKey;

  @override
  State<BrowsingPageMode> createState() => _BrowsingPageModeState();
}

class _BrowsingPageModeState extends State<BrowsingPageMode> {
  StreamSubscription<String>? _volumeKeySubscription;
  DateTime? _lastVolumeKeyAt;
  DateTime? _lastDesktopPageTurnAt;
  int _localPageIndex = 0;
  int _lastLocalPageCount = 1;
  bool _jumpToLastLocalPage = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _volumeKeySubscription = VolumeKeyService.volumeKeyStream.listen(
      _handleVolumeKey,
    );
  }

  @override
  void dispose() {
    _volumeKeySubscription?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BrowsingPageMode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.contentKey != oldWidget.contentKey ||
        widget.page != oldWidget.page) {
      if (_jumpToLastLocalPage) return;
      _localPageIndex = 0;
      _lastLocalPageCount = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Listener(
        onPointerSignal: _handlePointerSignal,
        child: Column(
          children: [
            Expanded(child: _buildContent(context)),
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _canPrevious && !_busy
                            ? _previousPage
                            : null,
                        icon: const Icon(Icons.chevron_left),
                        tooltip: 'previous_page'.tr,
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'page_indicator'.trParams({'page': _pageText}),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _busy ? null : _refresh,
                        icon: const Icon(Icons.refresh),
                        tooltip: 'refresh'.tr,
                      ),
                      IconButton(
                        onPressed: _canNext && !_busy ? _nextPage : null,
                        icon: const Icon(Icons.chevron_right),
                        tooltip: 'next_page'.tr,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (widget.contentBuilder == null || widget.localPageCountBuilder == null) {
      return widget.child!;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final pageCount = widget.localPageCountBuilder!(constraints).clamp(
          1,
          999999,
        );
        if (pageCount != _lastLocalPageCount ||
            _localPageIndex >= pageCount ||
            _jumpToLastLocalPage) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _lastLocalPageCount = pageCount;
              if (_jumpToLastLocalPage) {
                _localPageIndex = pageCount - 1;
                _jumpToLastLocalPage = false;
              } else if (_localPageIndex >= pageCount) {
                _localPageIndex = pageCount - 1;
              }
            });
          });
        }

        final safeLocalPage = _localPageIndex.clamp(0, pageCount - 1);
        return widget.contentBuilder!(context, constraints, safeLocalPage);
      },
    );
  }

  bool get _canPrevious => _localPageIndex > 0 || widget.canPreviousPage;

  bool get _canNext =>
      _localPageIndex < _lastLocalPageCount - 1 || widget.canNextPage;

  String get _pageText {
    final networkPage = widget.page.clamp(1, 999999);
    if (_lastLocalPageCount <= 1) return '$networkPage';
    return '$networkPage-${_localPageIndex + 1}/$_lastLocalPageCount';
  }

  bool get _isDesktop {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        return false;
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_isDesktop || event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.pageUp) {
      _previousPageThrottled();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.space) {
      _nextPageThrottled();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f5) {
      _refresh();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (!_isDesktop || event is! PointerScrollEvent) return;
    final primaryDelta =
        event.scrollDelta.dy.abs() >= event.scrollDelta.dx.abs()
        ? event.scrollDelta.dy
        : event.scrollDelta.dx;
    if (primaryDelta.abs() < 1) return;
    primaryDelta > 0 ? _nextPageThrottled() : _previousPageThrottled();
  }

  void _handleVolumeKey(String key) {
    final now = DateTime.now();
    final last = _lastVolumeKeyAt;
    if (last != null && now.difference(last).inMilliseconds < 280) return;
    _lastVolumeKeyAt = now;
    switch (key) {
      case 'volumeUp':
        _previousPage();
      case 'volumeDown':
        _nextPage();
    }
  }

  Future<void> _previousPage() async {
    if (_busy) return;
    if (_localPageIndex > 0) {
      setState(() => _localPageIndex--);
      return;
    }
    if (!widget.canPreviousPage) return;
    _jumpToLastLocalPage = true;
    await _run(widget.onPreviousPage);
  }

  Future<void> _nextPage() async {
    if (_busy) return;
    if (_localPageIndex < _lastLocalPageCount - 1) {
      setState(() => _localPageIndex++);
      return;
    }
    if (!widget.canNextPage) return;
    _localPageIndex = 0;
    await _run(widget.onNextPage);
  }

  void _previousPageThrottled() {
    if (_desktopTurnInCooldown()) return;
    _previousPage();
  }

  void _nextPageThrottled() {
    if (_desktopTurnInCooldown()) return;
    _nextPage();
  }

  bool _desktopTurnInCooldown() {
    final now = DateTime.now();
    final last = _lastDesktopPageTurnAt;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 220)) {
      return true;
    }
    _lastDesktopPageTurnAt = now;
    return false;
  }

  Future<void> _refresh() {
    _localPageIndex = 0;
    _jumpToLastLocalPage = false;
    return _run(widget.onRefresh);
  }

  Future<void> _run(Future<IndicatorResult> Function() action) async {
    setState(() => _busy = true);
    await action();
    if (mounted) setState(() => _busy = false);
  }
}
