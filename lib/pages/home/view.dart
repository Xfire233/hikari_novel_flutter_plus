import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/source_config.dart';
import 'package:hikari_novel_flutter/network/yamibo_api.dart';
import 'package:hikari_novel_flutter/pages/category/view.dart';
import 'package:hikari_novel_flutter/pages/completion/view.dart';
import 'package:hikari_novel_flutter/pages/esj/controller.dart';
import 'package:hikari_novel_flutter/pages/esj/view.dart';
import 'package:hikari_novel_flutter/pages/home/controller.dart';
import 'package:hikari_novel_flutter/pages/ranking/view.dart';
import 'package:hikari_novel_flutter/pages/recommend/view.dart';
import 'package:hikari_novel_flutter/pages/yamibo_forum/view.dart';
import 'package:hikari_novel_flutter/router/app_sub_router.dart';
import 'package:hikari_novel_flutter/router/route_path.dart';
import 'package:hikari_novel_flutter/service/source_config_service.dart';
import 'package:hikari_novel_flutter/widgets/source_backdrop.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});

  final controller = Get.put(HomeController());

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hasSources = controller.hasEnabledSources;
      final activeSource = controller.activeSource;
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: hasSources ? 8 : 0,
          title: hasSources
              ? _SourceAnimatedSwitcher(
                  direction: controller.sourceTransitionDirection,
                  child: KeyedSubtree(
                    key: ValueKey('home-tabs-$activeSource'),
                    child: _HomeContentTabs(controller: controller),
                  ),
                )
              : const SizedBox.shrink(),
          actions: [
            hasSources
                ? PopupMenuButton<NovelSource>(
                    initialValue:
                        controller.enabledSources.contains(
                          controller.source.value,
                        )
                        ? controller.source.value
                        : null,
                    onSelected: controller.changeSource,
                    itemBuilder: (_) => controller.enabledSources
                        .map(
                          (source) => PopupMenuItem(
                            value: source,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SourceMark(source: source, size: 20),
                                const SizedBox(width: 10),
                                Text(source.titleKey.tr),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    icon: SourceMark(source: activeSource),
                  )
                : IconButton(
                    onPressed: AppSubRouter.toSetting,
                    icon: const Icon(Icons.travel_explore_outlined),
                    tooltip: 'source_settings'.tr,
                  ),
            IconButton(
              onPressed: hasSources
                  ? () => AppSubRouter.toSearch(source: activeSource)
                  : AppSubRouter.toSetting,
              icon: const Icon(Icons.search),
            ),
          ],
        ),
        body: hasSources
            ? SourceBackdrop(
                source: activeSource,
                child: _SourceAnimatedSwitcher(
                  direction: controller.sourceTransitionDirection,
                  child: KeyedSubtree(
                    key: ValueKey('home-content-$activeSource'),
                    child: _HomeContent(controller: controller),
                  ),
                ),
              )
            : const _NoSourcePrompt(),
      );
    });
  }
}

class _SourceAnimatedSwitcher extends StatelessWidget {
  const _SourceAnimatedSwitcher({required this.child, required this.direction});

  final Widget child;
  final AxisDirection direction;

  @override
  Widget build(BuildContext context) {
    final sign = direction == AxisDirection.left ? 1.0 : -1.0;
    return AnimatedSwitcher(
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

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return switch (controller.activeSource) {
        NovelSource.wenku8 =>
          controller.isWenku8LoggedIn
              ? TabBarView(
                  controller: controller.tabController,
                  children: [
                    RecommendView(),
                    CategoryView(),
                    RankingView(),
                    CompletionView(),
                  ],
                )
              : const _SourceLoginPrompt(source: NovelSource.wenku8),
        NovelSource.esj => EsjView(),
        NovelSource.yamibo => YamiboForumPage(
          key: ValueKey(controller.yamiboPageRevision.value),
          showAppBar: false,
          showForumTabs: false,
          initialFid: controller.yamiboForumFid.value,
        ),
      };
    });
  }
}

class _HomeContentTabs extends StatelessWidget {
  const _HomeContentTabs({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final items = switch (controller.activeSource) {
        NovelSource.wenku8 => _wenku8Items(),
        NovelSource.esj => _esjItems(),
        NovelSource.yamibo => _yamiboItems(),
      };
      return SizedBox(
        height: kToolbarHeight,
        child: _HomeTabStrip(items: items),
      );
    });
  }

  List<_HomeTabItem> _wenku8Items() => [
    for (var i = 0; i < controller.tabs.length; i++)
      _HomeTabItem(
        label: '${controller.tabs[i]}',
        selected: controller.tabIndex.value == i,
        onTap: () => controller.changeWenku8Tab(i),
      ),
  ];

  List<_HomeTabItem> _esjItems() {
    final esjController = Get.isRegistered<EsjController>()
        ? Get.find<EsjController>()
        : Get.put(EsjController());
    return [
      for (final item in esjController.typeOptions)
        _HomeTabItem(
          label: item.$2,
          selected: esjController.type.value == item.$1,
          onTap: () => esjController.changeType(item.$1),
        ),
    ];
  }

  List<_HomeTabItem> _yamiboItems() => [
    for (final item in _yamiboTabOptions)
      _HomeTabItem(
        label: item.$2,
        selected: controller.yamiboForumFid.value == item.$1,
        onTap: () => controller.changeYamiboForum(item.$1),
      ),
  ];
}

const _yamiboTabOptions = [
  (YamiboApi.literatureFid, '文学区'),
  (YamiboApi.lightNovelFid, '轻小说/译文区'),
  (YamiboApi.txtNovelFid, 'TXT 小说区'),
];

class _HomeTabStrip extends StatelessWidget {
  const _HomeTabStrip({required this.items});

  final List<_HomeTabItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final minItemWidth = items.length <= 3 ? 96.0 : 68.0;
        final needsScroll = constraints.maxWidth < minItemWidth * items.length;
        if (!needsScroll) {
          return Row(
            children: [
              for (final item in items) Expanded(child: _HomeTabButton(item)),
            ],
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              children: [
                for (final item in items)
                  SizedBox(width: minItemWidth, child: _HomeTabButton(item)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HomeTabButton extends StatelessWidget {
  const _HomeTabButton(this.item);

  final _HomeTabItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
      child: Material(
        color: item.selected
            ? selectedColor.withValues(alpha: 0.12)
            : Colors.transparent,
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
                  color: item.selected
                      ? selectedColor
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: item.selected ? FontWeight.w700 : FontWeight.w500,
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
  const _HomeTabItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
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
                switch (source) {
                  case NovelSource.wenku8:
                    Get.toNamed(RoutePath.login);
                  case NovelSource.esj:
                    AppSubRouter.toEsjzone();
                  case NovelSource.yamibo:
                    final result =
                        await Navigator.of(
                          context,
                          rootNavigator: true,
                        ).push<YamiboWebLoginResult>(
                          MaterialPageRoute(
                            builder: (_) => const YamiboWebLoginPage(),
                          ),
                        );
                    if (result?.loggedIn == true) {
                      SourceConfigService.instance.enableSourceAfterLogin(
                        NovelSource.yamibo,
                      );
                      Get.find<HomeController>().reloadYamiboForum();
                    }
                }
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
