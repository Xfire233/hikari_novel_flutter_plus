import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/common/extension.dart';
import 'package:hikari_novel_flutter/models/page_state.dart';
import 'package:hikari_novel_flutter/pages/main/controller.dart';
import 'package:hikari_novel_flutter/pages/novel_detail/controller.dart';

import '../../common/common_widgets.dart';
import '../../router/app_pages.dart';
import '../../router/app_sub_router.dart';
import '../../router/route_path.dart';
import '../bookshelf/controller.dart';

class MainPage extends StatelessWidget {
  MainPage({super.key});

  final controller = Get.put(MainController());

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          await _handleSystemBack(controller);
        }
      },
      child: context.isLargeScreen()
          ? _buildLargeScreenScaffold()
          : _buildSmallScreenScaffold(),
    );
  }

  Widget _buildSmallScreenScaffold() {
    return Stack(
      children: [
        Obx(
          () => Scaffold(
            body: IndexedStack(
              index: controller.selectedIndex.value,
              children: controller.pages,
            ),
            bottomNavigationBar: Obx(() {
              if (controller.showBookshelfBottomActionBar.value) {
                BookshelfController bookshelfController = Get.find();
                BookshelfContentController currentTabController = Get.find(
                  tag:
                      "BookshelfContentController ${bookshelfController.currentClassId}",
                );
                return CommonWidgets.bookshelfBottomActionBar(
                  currentTabController,
                  bookshelfController,
                  edgeToEdge: true,
                );
              } else {
                return NavigationBar(
                  selectedIndex: controller.selectedIndex.value,
                  onDestinationSelected: (index) =>
                      controller.selectedIndex.value = index,
                  destinations: [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: "home".tr,
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.book_outlined),
                      selectedIcon: Icon(Icons.book),
                      label: "bookshelf".tr,
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: "my".tr,
                    ),
                  ],
                );
              }
            }),
          ),
        ),
        Obx(
          () => Offstage(
            offstage: !controller.showContent.value,
            child: _buildContentNavigator(controller),
          ),
        ),
      ],
    );
  }

  Widget _buildLargeScreenScaffold() {
    return Scaffold(
      body: Row(
        children: [
          Obx(
            () => NavigationRail(
              labelType: NavigationRailLabelType.all, //显示所有标签
              destinations: [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: Text("home".tr),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.book_outlined),
                  selectedIcon: Icon(Icons.book),
                  label: Text("bookshelf".tr),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: Text("my".tr),
                ),
              ],
              selectedIndex: controller.selectedIndex.value,
              onDestinationSelected: (index) =>
                  controller.selectedIndex.value = index,
            ),
          ),
          Obx(
            () => Expanded(
              flex: 1,
              child: IndexedStack(
                index: controller.selectedIndex.value,
                children: controller.pages,
              ),
            ),
          ),
          Expanded(flex: 1, child: _buildContentNavigator(controller)),
        ],
      ),
    );
  }
}

// Content navigator.
Widget _buildContentNavigator(MainController controller) {
  return ClipRect(
    child: Navigator(
      key: AppSubRouter.subNavigatorKey,
      initialRoute: RoutePath.logo,
      observers: [SubNavigatorObserver()],
      onGenerateRoute: (settings) => AppRoutes.subRoutePages(settings),
    ),
  );
}

Future<void> _handleSystemBack(MainController controller) async {
  // System back consumes exactly one level; only the root level asks to exit.
  if (Get.isDialogOpen == true || Get.isBottomSheetOpen == true) {
    Get.back();
    return;
  }

  // Keep detail-page selection mode from being discarded by a route pop.
  if (Get.isRegistered<NovelDetailController>()) {
    final novelDetailController = Get.find<NovelDetailController>();
    if (novelDetailController.isSelectionMode.value) {
      novelDetailController.exitSelectionMode();
      return;
    }
  }

  final subNavigator = AppSubRouter.subNavigatorKey?.currentState;
  if (subNavigator?.canPop() == true) {
    subNavigator!.pop();
    return;
  }
  if (controller.showContent.value) {
    // Route state can be left desynced after hot restart or nested navigator
    // replacement. Hide the content pane instead of making back appear dead.
    if (AppSubRouter.currentContentRouteName != RoutePath.logo) {
      AppSubRouter.currentContentRouteName = RoutePath.logo;
      controller.showContent.value = false;
      return;
    }
  }

  if (_handleBookshelfBack(controller)) return;

  await _confirmExitApp();
}

bool _handleBookshelfBack(MainController controller) {
  if (controller.selectedIndex.value != 1 ||
      !Get.isRegistered<BookshelfController>()) {
    return false;
  }

  final bookshelfController = Get.find<BookshelfController>();
  if (bookshelfController.pageState.value == PageState.bookshelfSearch) {
    bookshelfController.pageState.value = PageState.bookshelfContent;
    return true;
  }

  if (bookshelfController.isSelectionMode.value) {
    try {
      final currentTabController = Get.find<BookshelfContentController>(
        tag: "BookshelfContentController ${bookshelfController.currentClassId}",
      );
      currentTabController.exitSelectionMode();
    } catch (_) {
      bookshelfController.isSelectionMode.value = false;
      Get.find<MainController>().showBookshelfBottomActionBar.value = false;
    }
    return true;
  }

  if (bookshelfController.isInFolder) {
    bookshelfController.closeFolder();
    return true;
  }

  return false;
}

Future<void> _confirmExitApp() async {
  if (Get.isDialogOpen == true) return;
  final exit = await Get.dialog<bool>(
    AlertDialog(
      title: Text("exit".tr),
      content: Text("exit_app_confirm".tr),
      actions: [
        TextButton(onPressed: Get.back, child: Text("cancel".tr)),
        TextButton(
          onPressed: () => Get.back(result: true),
          child: Text("exit".tr),
        ),
      ],
    ),
  );
  if (exit == true) SystemNavigator.pop();
}

// Content navigator observer.
class SubNavigatorObserver extends NavigatorObserver {
  void _updateContentRoute(Route<dynamic>? route) {
    final routeName = route?.settings.name ?? RoutePath.logo;
    AppSubRouter.currentContentRouteName = routeName;
    Get.find<MainController>().showContent.value = routeName != RoutePath.logo;
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    if (previousRoute != null) {
      _updateContentRoute(route);
    }
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    _updateContentRoute(previousRoute);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _updateContentRoute(newRoute);
  }
}
