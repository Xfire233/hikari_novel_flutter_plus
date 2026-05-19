import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/source_config.dart';
import 'package:hikari_novel_flutter/network/yamibo_api.dart';
import 'package:hikari_novel_flutter/pages/bookshelf/controller.dart';
import 'package:hikari_novel_flutter/pages/category/view.dart';
import 'package:hikari_novel_flutter/pages/completion/view.dart';
import 'package:hikari_novel_flutter/pages/esj/view.dart';
import 'package:hikari_novel_flutter/pages/home/controller.dart';
import 'package:hikari_novel_flutter/pages/ranking/view.dart';
import 'package:hikari_novel_flutter/pages/recommend/view.dart';
import 'package:hikari_novel_flutter/pages/yamibo_forum/view.dart';
import 'package:hikari_novel_flutter/router/app_sub_router.dart';
import 'package:hikari_novel_flutter/router/route_path.dart';
import 'package:hikari_novel_flutter/service/source_config_service.dart';
import 'package:hikari_novel_flutter/widgets/source_backdrop.dart';
import 'package:hikari_novel_flutter/widgets/state_page.dart';

enum _HomeYamiboAction { login, syncFavorites }

class HomePage extends StatelessWidget {
  final controller = Get.put(HomeController());

  HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Obx(
          () => controller.activeSource == NovelSource.wenku8
              ? TabBar(
                  tabs: controller.tabs.map((e) => Tab(text: e)).toList(),
                  controller: controller.tabController,
                  dividerHeight: 0,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                )
              : Text(controller.activeSource.titleKey.tr),
        ),
        titleSpacing: 16,
        actions: [
          Obx(
            () => controller.hasEnabledSources
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
                    icon: SourceMark(source: controller.activeSource),
                  )
                : IconButton(
                    onPressed: AppSubRouter.toSetting,
                    icon: const Icon(Icons.travel_explore_outlined),
                    tooltip: 'source_settings'.tr,
                  ),
          ),
          Obx(
            () => IconButton(
              onPressed: controller.hasEnabledSources
                  ? () => AppSubRouter.toSearch(source: controller.activeSource)
                  : AppSubRouter.toSetting,
              icon: const Icon(Icons.search),
            ),
          ),
          Obx(
            () => controller.activeSource == NovelSource.yamibo
                ? PopupMenuButton<_HomeYamiboAction>(
                    onSelected: (action) =>
                        _handleYamiboAction(context, action),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: _HomeYamiboAction.login,
                        child: Text('yamibo_web_login'.tr),
                      ),
                      PopupMenuItem(
                        value: _HomeYamiboAction.syncFavorites,
                        child: Text('sync_yamibo_favorites'.tr),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: Obx(
        () => controller.hasEnabledSources
            ? SourceBackdrop(
                source: controller.activeSource,
                child: switch (controller.activeSource) {
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
                  ),
                },
              )
            : const _NoSourcePrompt(),
      ),
    );
  }

  Future<void> _handleYamiboAction(
    BuildContext context,
    _HomeYamiboAction action,
  ) async {
    switch (action) {
      case _HomeYamiboAction.login:
        await _openYamiboLogin(context);
      case _HomeYamiboAction.syncFavorites:
        await _syncYamiboFavorites(context);
    }
  }

  Future<void> _openYamiboLogin(BuildContext context) async {
    final loggedIn = await Navigator.of(
      context,
      rootNavigator: true,
    ).push<bool>(MaterialPageRoute(builder: (_) => const YamiboWebLoginPage()));
    if (!context.mounted) return;
    if (loggedIn != true && !YamiboApi.hasCookie) return;

    SourceConfigService.instance.setSourceEnabled(NovelSource.yamibo, true);
    if (SourceConfigService.instance.shouldPullOnlineToLocal(
      NovelSource.yamibo,
    )) {
      await BookshelfController.syncYamiboFavoritesToBookshelf();
      if (Get.isRegistered<BookshelfController>()) {
        await Get.find<BookshelfController>().loadFolders();
      }
    }
    controller.reloadYamiboForum();
    if (!context.mounted) return;
    showSnackBar(message: 'update_successfully'.tr, context: context);
  }

  Future<void> _syncYamiboFavorites(BuildContext context) async {
    if (!YamiboApi.hasCookie) {
      showErrorDialog('source_login_required'.tr, [
        TextButton(onPressed: Get.back, child: Text('confirm'.tr)),
      ]);
      return;
    }

    final result = await BookshelfController.syncYamiboFavoritesToBookshelf();
    if (!context.mounted) return;
    if (result) {
      if (Get.isRegistered<BookshelfController>()) {
        await Get.find<BookshelfController>().loadFolders();
      }
      controller.reloadYamiboForum();
      if (!context.mounted) return;
      showSnackBar(message: 'update_successfully'.tr, context: context);
    } else {
      showErrorDialog('update_failed'.tr, [
        TextButton(onPressed: Get.back, child: Text('confirm'.tr)),
      ]);
    }
  }
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
              onPressed: () {
                switch (source) {
                  case NovelSource.wenku8:
                    Get.toNamed(RoutePath.login);
                  case NovelSource.esj:
                    AppSubRouter.toEsjzone();
                  case NovelSource.yamibo:
                    AppSubRouter.toYamiboForum();
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
