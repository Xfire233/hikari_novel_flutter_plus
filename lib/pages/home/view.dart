import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/common/constants.dart';
import 'package:hikari_novel_flutter/models/common/wenku8_node.dart';
import 'package:hikari_novel_flutter/models/source_config.dart';
import 'package:hikari_novel_flutter/models/source_login_result.dart';
import 'package:hikari_novel_flutter/network/api.dart';
import 'package:hikari_novel_flutter/network/esj_api.dart';
import 'package:hikari_novel_flutter/network/yamibo_api.dart';
import 'package:hikari_novel_flutter/pages/category/view.dart';
import 'package:hikari_novel_flutter/pages/completion/view.dart';
import 'package:hikari_novel_flutter/pages/esj/view.dart';
import 'package:hikari_novel_flutter/pages/esjzone_web/view.dart';
import 'package:hikari_novel_flutter/pages/home/controller.dart';
import 'package:hikari_novel_flutter/pages/login/view.dart';
import 'package:hikari_novel_flutter/pages/ranking/view.dart';
import 'package:hikari_novel_flutter/pages/recommend/view.dart';
import 'package:hikari_novel_flutter/pages/yamibo_forum/view.dart';
import 'package:hikari_novel_flutter/router/app_sub_router.dart';
import 'package:hikari_novel_flutter/service/local_storage_service.dart';
import 'package:hikari_novel_flutter/widgets/source_backdrop.dart';
import 'package:hikari_novel_flutter/widgets/state_page.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});

  final controller = Get.put(HomeController());

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hasSources = controller.hasEnabledSources;
      final activeSource = controller.activeSource;
      final sectionsExpanded = controller.appBarSectionsExpanded.value;
      final animationsEnabled = controller.homeAnimationsEnabled;
      final titleText = sectionsExpanded
          ? activeSource.titleKey.tr
          : '${activeSource.titleKey.tr} · ${controller.currentSectionLabel}';
      final scaffold = Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: kPageHorizontalPadding,
          title: hasSources
              ? _MaybeAnimatedSwitcher(
                  enabled: animationsEnabled,
                  duration: const Duration(milliseconds: 160),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: Align(
                    key: ValueKey(titleText),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      titleText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
          bottom: hasSources
              ? _HomeSectionsBottom(
                  controller: controller,
                  activeSource: activeSource,
                  expanded: sectionsExpanded,
                )
              : null,
          actions: [
            if (hasSources)
              _HomeSourceSwitcher(controller: controller)
            else
              IconButton(
                onPressed: AppSubRouter.toSetting,
                icon: const Icon(Icons.travel_explore_outlined),
                tooltip: 'source_settings'.tr,
              ),
            IconButton(
              onPressed: () {
                controller.collapseSourcePicker();
                if (hasSources) {
                  AppSubRouter.toSearch(source: activeSource);
                } else {
                  AppSubRouter.toSetting();
                }
              },
              icon: const Icon(Icons.search),
              tooltip: 'search'.tr,
            ),
            if (hasSources)
              _HomeSourceMenu(controller: controller, source: activeSource),
          ],
        ),
        body: hasSources
            ? SourceBackdrop(
                source: activeSource,
                child: _SourceAnimatedSwitcher(
                  direction: controller.sourceTransitionDirection,
                  enabled: animationsEnabled,
                  child: KeyedSubtree(
                    key: ValueKey('home-content-$activeSource'),
                    child: _HomeContent(controller: controller),
                  ),
                ),
              )
            : const _NoSourcePrompt(),
      );
      return hasSources
          ? _HomeChromeAutoCollapse(controller: controller, child: scaffold)
          : scaffold;
    });
  }
}

class _HomeSourceSwitcher extends StatelessWidget {
  const _HomeSourceSwitcher({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final sources = controller.enabledSources;
      final activeSource = controller.activeSource;
      final expanded = controller.sourcePickerExpanded.value;
      final visibleSources = expanded
          ? <NovelSource>[
              ...sources.where((source) => source != activeSource),
              activeSource,
            ]
          : <NovelSource>[activeSource];
      return AnimatedSize(
        duration: controller.homeAnimationsEnabled
            ? const Duration(milliseconds: 180)
            : Duration.zero,
        curve: Curves.easeOutCubic,
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final source in visibleSources)
              _SourceSwitchButton(
                source: source,
                selected: source == activeSource,
                onTap: () {
                  if (!expanded) {
                    controller.toggleSourcePicker();
                    return;
                  }
                  if (source == activeSource) {
                    controller.collapseSourcePicker();
                  } else {
                    controller.changeSourceFromPicker(source);
                  }
                },
              ),
          ],
        ),
      );
    });
  }
}

class _SourceSwitchButton extends StatelessWidget {
  const _SourceSwitchButton({
    required this.source,
    required this.selected,
    required this.onTap,
  });

  final NovelSource source;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: source.titleKey.tr,
      child: Semantics(
        button: true,
        selected: selected,
        label: source.titleKey.tr,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Material(
            color: selected
                ? scheme.primaryContainer.withValues(alpha: 0.72)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(child: SourceMark(source: source, size: 24)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeSectionsBottom extends StatelessWidget
    implements PreferredSizeWidget {
  const _HomeSectionsBottom({
    required this.controller,
    required this.activeSource,
    required this.expanded,
  });

  final HomeController controller;
  final NovelSource activeSource;
  final bool expanded;

  @override
  Size get preferredSize => Size.fromHeight(expanded ? kToolbarHeight : 0);

  @override
  Widget build(BuildContext context) {
    final duration = expanded
        ? (controller.homeAnimationsEnabled
              ? const Duration(milliseconds: 340)
              : Duration.zero)
        : (controller.homeAnimationsEnabled
              ? const Duration(milliseconds: 700)
              : Duration.zero);
    final opacityDuration = expanded
        ? (controller.homeAnimationsEnabled
              ? const Duration(milliseconds: 260)
              : Duration.zero)
        : (controller.homeAnimationsEnabled
              ? const Duration(milliseconds: 520)
              : Duration.zero);
    return ClipRect(
      child: AnimatedContainer(
        duration: duration,
        curve: expanded ? Curves.easeOutCubic : Curves.easeInOutCubic,
        height: expanded ? kToolbarHeight : 0,
        child: AnimatedOpacity(
          opacity: expanded ? 1 : 0,
          duration: opacityDuration,
          child: _SourceAnimatedSwitcher(
            direction: controller.sourceTransitionDirection,
            enabled: controller.homeAnimationsEnabled,
            child: KeyedSubtree(
              key: ValueKey('home-tabs-$activeSource'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: kPageHorizontalPadding,
                ),
                child: _HomeContentTabs(controller: controller),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeChromeAutoCollapse extends StatefulWidget {
  const _HomeChromeAutoCollapse({
    required this.controller,
    required this.child,
  });

  final HomeController controller;
  final Widget child;

  @override
  State<_HomeChromeAutoCollapse> createState() =>
      _HomeChromeAutoCollapseState();
}

class _HomeChromeAutoCollapseState extends State<_HomeChromeAutoCollapse> {
  static const _scrollCollapseDistance = 44.0;
  static const _dragCollapseDistance = 32.0;
  static const _expandDistance = 18.0;
  static const _filterGestureHeight = 72.0;
  static const _topCollapseDeadZone = 48.0;
  int? _pointer;
  Offset? _startPosition;
  double _scrollCollapseOffset = 0;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!widget.controller.homeChromeCanCollapse) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.controller.expandHomeSections();
        });
        return widget.child;
      }
      final hasFilterBar = widget.controller.activeSectionHasFilterBar;
      final sectionsExpanded = widget.controller.appBarSectionsExpanded.value;
      final topChromeHeight =
          MediaQuery.paddingOf(context).top +
          kToolbarHeight * (sectionsExpanded ? 2 : 1) +
          (hasFilterBar ? _filterGestureHeight : 16);
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          _pointer = event.pointer;
          if (widget.controller.homeChromeGestureBlocked) {
            _startPosition = null;
            return;
          }
          final startsInChrome =
              !sectionsExpanded || event.position.dy <= topChromeHeight;
          _startPosition = startsInChrome ? event.position : null;
          if (!sectionsExpanded) {
            widget.controller.lockHomeRefreshForGesture();
          }
        },
        onPointerMove: (event) {
          if (event.pointer != _pointer) return;
          if (widget.controller.homeChromeGestureBlocked) return;
          final start = _startPosition;
          if (start == null) return;
          final delta = event.position - start;
          if (delta.dy.abs() <= delta.dx.abs()) return;
          if (delta.dy >= _expandDistance) {
            widget.controller.revealHomeSections();
            _startPosition = null;
            return;
          }
          if (delta.dy <= -_dragCollapseDistance) {
            widget.controller.collapseHomeSections(force: true);
            _startPosition = null;
          }
        },
        onPointerUp: (_) => _resetPointer(),
        onPointerCancel: (_) => _resetPointer(),
        child: NotificationListener<ScrollUpdateNotification>(
          onNotification: (notification) {
            if (widget.controller.homeChromeGestureBlocked) return false;
            if (notification.metrics.axis != Axis.vertical) return false;
            if (notification.dragDetails == null ||
                notification.metrics.outOfRange ||
                notification.metrics.pixels <= _topCollapseDeadZone) {
              _scrollCollapseOffset = 0;
              return false;
            }
            final delta = notification.scrollDelta ?? 0;
            if (delta <= 0) {
              _scrollCollapseOffset = 0;
              return false;
            }
            _scrollCollapseOffset += delta;
            if (_scrollCollapseOffset >= _scrollCollapseDistance) {
              widget.controller.collapseHomeSections();
              _scrollCollapseOffset = 0;
            }
            return false;
          },
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (_) => false,
            child: widget.child,
          ),
        ),
      );
    });
  }

  void _resetPointer() {
    _pointer = null;
    _startPosition = null;
    widget.controller.releaseHomeRefreshGestureLock();
  }
}

class _SourceAnimatedSwitcher extends StatelessWidget {
  const _SourceAnimatedSwitcher({
    required this.child,
    required this.direction,
    this.enabled = true,
  });

  final Widget child;
  final AxisDirection direction;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final sign = direction == AxisDirection.left ? 1.0 : -1.0;
    return _MaybeAnimatedSwitcher(
      enabled: enabled,
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: Offset(0.035 * sign, 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: child,
    );
  }
}

class _MaybeAnimatedSwitcher extends StatelessWidget {
  const _MaybeAnimatedSwitcher({
    required this.child,
    required this.enabled,
    required this.duration,
    this.switchInCurve = Curves.linear,
    this.switchOutCurve = Curves.linear,
    this.transitionBuilder,
  });

  final Widget child;
  final bool enabled;
  final Duration duration;
  final Curve switchInCurve;
  final Curve switchOutCurve;
  final AnimatedSwitcherTransitionBuilder? transitionBuilder;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: switchInCurve,
      switchOutCurve: switchOutCurve,
      transitionBuilder:
          transitionBuilder ?? AnimatedSwitcher.defaultTransitionBuilder,
      child: child,
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final content = switch (controller.activeSource) {
        NovelSource.wenku8 =>
          controller.isWenku8LoggedIn
              ? PageView.builder(
                  controller: controller.pageControllerFor(NovelSource.wenku8),
                  physics: const PageScrollPhysics(),
                  onPageChanged: (index) => controller.handleSourcePageChanged(
                    NovelSource.wenku8,
                    index,
                  ),
                  itemCount: controller.tabs.length,
                  itemBuilder: (context, index) =>
                      _buildWenku8Section(context, index),
                )
              : const _SourceLoginPrompt(source: NovelSource.wenku8),
        NovelSource.esj => PageView.builder(
          controller: controller.pageControllerFor(NovelSource.esj),
          physics: const PageScrollPhysics(),
          onPageChanged: (index) =>
              controller.handleSourcePageChanged(NovelSource.esj, index),
          itemCount: controller.esjTypeOptions.length,
          itemBuilder: (context, index) => _LazySourceSection(
            key: ValueKey('esj-section-$index'),
            controller: controller,
            source: NovelSource.esj,
            index: index,
            builder: (_) {
              final item = controller.esjTypeOptions[index];
              return EsjView(
                key: ValueKey('esj-${item.$1}'),
                initialType: item.$1,
              );
            },
          ),
        ),
        NovelSource.yamibo => PageView.builder(
          controller: controller.pageControllerFor(NovelSource.yamibo),
          physics: const PageScrollPhysics(),
          onPageChanged: (index) =>
              controller.handleSourcePageChanged(NovelSource.yamibo, index),
          itemCount: yamiboForumOptions.length,
          itemBuilder: (context, index) => _LazySourceSection(
            key: ValueKey('yamibo-section-$index'),
            controller: controller,
            source: NovelSource.yamibo,
            index: index,
            builder: (_) => _buildYamiboSection(index),
          ),
        ),
      };
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => controller.syncActivePageIfPending(),
      );
      return content;
    });
  }

  Widget _buildWenku8Section(BuildContext context, int index) =>
      switch (index) {
        0 => RecommendView(),
        1 => CategoryView(),
        2 => RankingView(),
        3 => CompletionView(),
        _ => const SizedBox.expand(),
      };

  Widget _buildYamiboSection(int index) {
    final fid = yamiboForumOptions[index].$1;
    return YamiboForumPage(
      key: ValueKey(
        'yamibo-active-$fid-${controller.yamiboPageRevision.value}',
      ),
      showAppBar: false,
      showForumTabs: false,
      initialFid: fid,
    );
  }
}

class _LazySourceSection extends StatelessWidget {
  const _LazySourceSection({
    super.key,
    required this.controller,
    required this.source,
    required this.index,
    required this.builder,
  });

  final HomeController controller;
  final NovelSource source;
  final int index;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    controller.ensureSectionLoaded(source, index);
    return builder(context);
  }
}

class _HomeContentTabs extends StatelessWidget {
  const _HomeContentTabs({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final activeSource = controller.activeSource;
      final items = switch (activeSource) {
        NovelSource.wenku8 => _wenku8Items(),
        NovelSource.esj => _esjItems(),
        NovelSource.yamibo => _yamiboItems(),
      };
      final pageController = controller.pageControllerFor(activeSource);
      return SizedBox(
        height: kToolbarHeight,
        child: AnimatedBuilder(
          animation: pageController,
          builder: (context, _) {
            final selectedIndex = controller.visibleSectionIndex.value;
            final selectedPosition = controller
                .sectionPositionFor(activeSource)
                .clamp(0, (items.length - 1).toDouble())
                .toDouble();
            return _HomeTabStrip(
              items: items,
              selectedIndex: selectedIndex,
              selectedPosition: selectedPosition,
            );
          },
        ),
      );
    });
  }

  List<_HomeTabItem> _wenku8Items() => [
    for (var i = 0; i < controller.tabs.length; i++)
      _HomeTabItem(
        label: '${controller.tabs[i]}',
        onTap: () => controller.changeSourceSection(i),
      ),
  ];

  List<_HomeTabItem> _esjItems() {
    final options = controller.esjTypeOptions;
    return [
      for (var i = 0; i < options.length; i++)
        _HomeTabItem(
          label: options[i].$2,
          onTap: () => controller.changeSourceSection(i),
        ),
    ];
  }

  List<_HomeTabItem> _yamiboItems() => [
    for (var i = 0; i < yamiboForumOptions.length; i++)
      _HomeTabItem(
        label: yamiboForumOptions[i].$2,
        onTap: () => controller.changeSourceSection(i),
      ),
  ];
}

class _HomeTabStrip extends StatelessWidget {
  const _HomeTabStrip({
    required this.items,
    required this.selectedIndex,
    required this.selectedPosition,
  });

  final List<_HomeTabItem> items;
  final int selectedIndex;
  final double selectedPosition;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final minItemWidth = items.length <= 3 ? 96.0 : 68.0;
        final needsScroll = constraints.maxWidth < minItemWidth * items.length;
        if (!needsScroll) {
          final itemWidth = constraints.maxWidth / items.length;
          return _HomeTabTrack(
            items: items,
            selectedIndex: selectedIndex,
            selectedPosition: selectedPosition,
            itemWidth: itemWidth,
            totalWidth: constraints.maxWidth,
          );
        }
        final totalWidth = minItemWidth * items.length;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: _HomeTabTrack(
              items: items,
              selectedIndex: selectedIndex,
              selectedPosition: selectedPosition,
              itemWidth: minItemWidth,
              totalWidth: totalWidth,
            ),
          ),
        );
      },
    );
  }
}

class _HomeTabTrack extends StatelessWidget {
  const _HomeTabTrack({
    required this.items,
    required this.selectedIndex,
    required this.selectedPosition,
    required this.itemWidth,
    required this.totalWidth,
  });

  final List<_HomeTabItem> items;
  final int selectedIndex;
  final double selectedPosition;
  final double itemWidth;
  final double totalWidth;

  @override
  Widget build(BuildContext context) {
    final safeIndex = selectedIndex.clamp(0, items.length - 1);
    final safePosition = selectedPosition
        .clamp(0, (items.length - 1).toDouble())
        .toDouble();
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: totalWidth,
      height: kToolbarHeight,
      child: Stack(
        children: [
          Positioned(
            left: itemWidth * safePosition + 2,
            top: 8,
            bottom: 8,
            width: itemWidth - 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < items.length; i++)
                SizedBox(
                  width: itemWidth,
                  child: _HomeTabButton(
                    item: items[i],
                    selected: safeIndex == i,
                    emphasis:
                        1 - (safePosition - i).abs().clamp(0, 1).toDouble(),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeTabButton extends StatelessWidget {
  const _HomeTabButton({
    required this.item,
    required this.selected,
    required this.emphasis,
  });

  final _HomeTabItem item;
  final bool selected;
  final double emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.primary;
    final textColor = Color.lerp(
      theme.colorScheme.onSurfaceVariant,
      selectedColor,
      emphasis,
    );
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Tooltip(
        message: item.label,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: item.onTap,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: textColor,
                      fontWeight: emphasis > 0.5
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeTabItem {
  const _HomeTabItem({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;
}

class _NoSourcePrompt extends StatelessWidget {
  const _NoSourcePrompt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.travel_explore_outlined, size: 48),
            const SizedBox(height: 14),
            Text(
              'search_no_source_enabled'.tr,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: AppSubRouter.toSetting,
              icon: const Icon(Icons.settings_outlined),
              label: Text('source_settings'.tr),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceLoginPrompt extends StatelessWidget {
  const _SourceLoginPrompt({required this.source});

  final NovelSource source;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SourceMark(source: source, size: 48),
            const SizedBox(height: 14),
            Text(
              'source_home_login_required'.trParams({
                'source': source.titleKey.tr,
              }),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                await _openSourceLogin(context, source);
              },
              icon: const Icon(Icons.login),
              label: Text('source_go_login'.tr),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeSourceMenu extends StatelessWidget {
  const _HomeSourceMenu({required this.controller, required this.source});

  final HomeController controller;
  final NovelSource source;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_HomeMenuAction>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'source_more_actions'.tr,
      constraints: const BoxConstraints(minWidth: 216, maxWidth: 256),
      onSelected: (action) {
        controller.collapseSourcePicker();
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!context.mounted) return;
          switch (action) {
            case _HomeMenuAction.login:
              await _openSourceLogin(context, source);
            case _HomeMenuAction.syncBookshelf:
              final message = await controller.syncSourceBookshelf(source);
              if (context.mounted) {
                showSnackBar(message: message, context: context);
              }
            case _HomeMenuAction.openWeb:
              await _openSourceWeb(context, source);
          }
        });
      },
      itemBuilder: (menuContext) => [
        PopupMenuItem(
          value: _HomeMenuAction.openWeb,
          height: 58,
          padding: EdgeInsets.zero,
          child: _SourceMenuHeader(controller: controller, source: source),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _HomeMenuAction.login,
          height: 48,
          padding: EdgeInsets.zero,
          child: _HomeMenuItemRow(
            icon: Icons.verified_user_outlined,
            label: 'source_check_login_status'.tr,
          ),
        ),
        PopupMenuItem(
          value: _HomeMenuAction.syncBookshelf,
          height: 48,
          padding: EdgeInsets.zero,
          child: _HomeMenuItemRow(
            icon: Icons.cloud_download_outlined,
            label: 'source_sync_online_favorites'.tr,
          ),
        ),
        if (source == NovelSource.wenku8)
          PopupMenuItem<_HomeMenuAction>(
            enabled: false,
            height: 58,
            padding: EdgeInsets.zero,
            child: Obx(
              () => SwitchListTile(
                dense: true,
                contentPadding: const EdgeInsetsDirectional.fromSTEB(
                  16,
                  0,
                  10,
                  0,
                ),
                secondary: const Icon(Icons.web_asset_outlined, size: 22),
                title: Text(
                  'wenku8_compatibility_mode'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                subtitle: Text(
                  controller.wenku8CompatibilityMode.value
                      ? 'wenku8_compatibility_webview'.tr
                      : 'wenku8_compatibility_native'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                value: controller.wenku8CompatibilityMode.value,
                onChanged: (value) async {
                  Navigator.of(menuContext).pop();
                  final message = await controller.setWenku8CompatibilityMode(
                    value,
                  );
                  await controller.refreshSourceHome(source);
                  if (context.mounted) {
                    showSnackBar(message: message, context: context);
                  }
                },
              ),
            ),
          ),
        if (source == NovelSource.wenku8)
          PopupMenuItem<_HomeMenuAction>(
            enabled: false,
            height: 58,
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              dense: true,
              contentPadding: const EdgeInsetsDirectional.fromSTEB(
                16,
                0,
                10,
                0,
              ),
              secondary: const Icon(Icons.lan_outlined, size: 22),
              title: Text(
                'node'.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              subtitle: Text(
                Uri.parse(
                  LocalStorageService.instance.getWenku8Node().node,
                ).host,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              value:
                  LocalStorageService.instance.getWenku8Node() ==
                  Wenku8Node.wwwWenku8Cc,
              onChanged: (value) async {
                Navigator.of(menuContext).pop();
                final node = value
                    ? Wenku8Node.wwwWenku8Cc
                    : Wenku8Node.wwwWenku8Net;
                final message = await controller.changeWenku8Node(node);
                if (context.mounted) {
                  showSnackBar(message: message, context: context);
                }
              },
            ),
          ),
      ],
    );
  }
}

class _SourceMenuHeader extends StatelessWidget {
  const _SourceMenuHeader({required this.controller, required this.source});

  final HomeController controller;
  final NovelSource source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 240,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 12, 8),
        child: Row(
          children: [
            SourceMark(source: source, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    source.titleKey.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    controller.sourceStatusText(source),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeMenuItemRow extends StatelessWidget {
  const _HomeMenuItemRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 240,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 12, 0),
        child: Row(
          children: [
            Icon(icon, size: 22, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _HomeMenuAction { login, syncBookshelf, openWeb }

Future<void> _openSourceLogin(BuildContext context, NovelSource source) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final result = switch (source) {
    NovelSource.wenku8 => await _openWenku8LoginOrAccount(),
    NovelSource.esj =>
      EsjApi.hasCookie
          ? await navigator.push<SourceLoginResult>(
              MaterialPageRoute(
                builder: (_) => const EsjzoneWebPage(
                  initialUrl: '${EsjApi.baseUrl}/my/view',
                  accountMode: true,
                ),
              ),
            )
          : await navigator.push<SourceLoginResult>(
              MaterialPageRoute(builder: (_) => const EsjzoneWebPage()),
            ),
    NovelSource.yamibo =>
      YamiboApi.hasCookie
          ? await navigator.push<YamiboWebLoginResult>(
              MaterialPageRoute(
                builder: (_) => const YamiboWebLoginPage(accountMode: true),
              ),
            )
          : await navigator.push<YamiboWebLoginResult>(
              MaterialPageRoute(builder: (_) => const YamiboWebLoginPage()),
            ),
  };
  if (!context.mounted || result?.loggedIn != true) return;
  final message = await Get.find<HomeController>().handleConfirmedLogin(
    source,
    syncFavorites: result!.syncFavorites,
  );
  if (context.mounted && message != null) {
    showSnackBar(message: message, context: context);
  }
}

Future<SourceLoginResult?> _openWenku8LoginOrAccount() async {
  final hasCookie =
      LocalStorageService.instance.getCookie()?.trim().isNotEmpty == true;
  if (!hasCookie) return await Get.to<SourceLoginResult>(() => LoginPage());
  return await Get.to<SourceLoginResult>(
    () => LoginPage(),
    arguments: {
      'accountMode': true,
      'initialUrl': '${Api.wenku8Node.node}/userdetail.php',
    },
  );
}

Future<void> _openSourceWeb(BuildContext context, NovelSource source) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final result = switch (source) {
    NovelSource.wenku8 => await Get.to<SourceLoginResult>(
      () => LoginPage(),
      arguments: {
        'accountMode': true,
        'initialUrl': '${Api.wenku8Node.node}/userdetail.php',
      },
    ),
    NovelSource.esj => await navigator.push<SourceLoginResult>(
      MaterialPageRoute(
        builder: (_) => const EsjzoneWebPage(accountMode: true),
      ),
    ),
    NovelSource.yamibo => await navigator.push<YamiboWebLoginResult>(
      MaterialPageRoute(
        builder: (_) => const YamiboWebLoginPage(accountMode: true),
      ),
    ),
  };
  if (!context.mounted || result?.loggedIn != true) return;
  final message = await Get.find<HomeController>().handleConfirmedLogin(
    source,
    syncFavorites: result!.syncFavorites,
  );
  if (context.mounted && message != null) {
    showSnackBar(message: message, context: context);
  }
}
