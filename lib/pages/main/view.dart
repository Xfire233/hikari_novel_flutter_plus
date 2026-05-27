import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/common/extension.dart';
import 'package:hikari_novel_flutter/models/page_state.dart';
import 'package:hikari_novel_flutter/network/wenku8_webview_transport.dart';
import 'package:hikari_novel_flutter/pages/main/controller.dart';
import 'package:hikari_novel_flutter/pages/novel_detail/controller.dart';
import 'package:hikari_novel_flutter/service/local_storage_service.dart';
import 'package:hikari_novel_flutter/widgets/wenku8_webview_transport_host.dart';

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
    if (LocalStorageService.instance.getWenku8CompatibilityMode()) {
      Wenku8WebViewTransport.ensureHost();
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          await _handleSystemBack(controller);
        }
      },
      child: Stack(
        children: [
          const Wenku8WebViewTransportHost(),
          Positioned.fill(
            child: context.isLargeScreen()
                ? _buildLargeScreenScaffold()
                : _buildSmallScreenScaffold(),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallScreenScaffold() {
    return Stack(
      children: [
        Obx(
          () => Scaffold(
            body: _AnimatedIndexedStack(
              index: controller.selectedIndex.value,
              previousIndex: controller.previousIndex.value,
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
                  onDestinationSelected: controller.changeTab,
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
          () => _ContentPaneOverlay(
            visible: controller.showContent.value,
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
              onDestinationSelected: controller.changeTab,
            ),
          ),
          Obx(
            () => Expanded(
              flex: 1,
              child: _AnimatedIndexedStack(
                index: controller.selectedIndex.value,
                previousIndex: controller.previousIndex.value,
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

class _AnimatedIndexedStack extends StatefulWidget {
  const _AnimatedIndexedStack({
    required this.index,
    required this.previousIndex,
    required this.children,
  });

  final int index;
  final int previousIndex;
  final List<Widget> children;

  @override
  State<_AnimatedIndexedStack> createState() => _AnimatedIndexedStackState();
}

class _AnimatedIndexedStackState extends State<_AnimatedIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  late int _currentIndex;
  int? _previousIndex;
  bool _forward = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.index;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _controller.value = 1;
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _previousIndex = null);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _AnimatedIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index == _currentIndex) return;
    final oldIndex = _currentIndex;
    _forward = widget.index >= oldIndex;
    _previousIndex = oldIndex;
    _currentIndex = widget.index;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previousIndex = _previousIndex;
    final hasPrevious =
        previousIndex != null &&
        previousIndex >= 0 &&
        previousIndex < widget.children.length &&
        previousIndex != _currentIndex;
    final hiddenIndexes = <int>[
      for (var i = 0; i < widget.children.length; i++)
        if (i != _currentIndex && (!hasPrevious || i != previousIndex)) i,
    ];
    return Stack(
      children: [
        for (final i in hiddenIndexes)
          Positioned.fill(
            child: Offstage(
              offstage: true,
              child: TickerMode(enabled: false, child: widget.children[i]),
            ),
          ),
        if (hasPrevious)
          Positioned.fill(
            child: _NavigationTransitionChild(
              animation: _animation,
              role: _NavigationTransitionRole.outgoing,
              forward: _forward,
              child: widget.children[previousIndex],
            ),
          ),
        Positioned.fill(
          child: _NavigationTransitionChild(
            animation: _animation,
            role: _NavigationTransitionRole.incoming,
            forward: _forward,
            child: widget.children[_currentIndex],
          ),
        ),
      ],
    );
  }
}

enum _NavigationTransitionRole { incoming, outgoing }

class _NavigationTransitionChild extends StatelessWidget {
  const _NavigationTransitionChild({
    required this.animation,
    required this.role,
    required this.forward,
    required this.child,
  });

  final Animation<double> animation;
  final _NavigationTransitionRole role;
  final bool forward;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = animation.value;
        final direction = forward ? 1.0 : -1.0;
        final offset = switch (role) {
          _NavigationTransitionRole.incoming => Offset(
            0.08 * direction * (1 - t),
            0,
          ),
          _NavigationTransitionRole.outgoing => Offset(
            -0.025 * direction * t,
            0,
          ),
        };
        final opacity = switch (role) {
          _NavigationTransitionRole.incoming => 0.86 + 0.14 * t,
          _NavigationTransitionRole.outgoing => 1.0 - 0.16 * t,
        };
        return TickerMode(
          enabled: role == _NavigationTransitionRole.incoming,
          child: IgnorePointer(
            ignoring: role != _NavigationTransitionRole.incoming,
            child: Opacity(
              opacity: opacity,
              child: FractionalTranslation(translation: offset, child: child),
            ),
          ),
        );
      },
    );
  }
}

class _ContentPaneOverlay extends StatelessWidget {
  const _ContentPaneOverlay({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0.04, 0),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: child,
        ),
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
    final routeName = route?.settings.name;
    if (!_isContentRouteName(routeName)) return;
    AppSubRouter.currentContentRouteName = routeName!;
    Get.find<MainController>().showContent.value = routeName != RoutePath.logo;
  }

  bool _isContentRouteName(String? routeName) {
    return switch (routeName) {
      RoutePath.logo ||
      RoutePath.novelDetail ||
      RoutePath.comment ||
      RoutePath.reply ||
      RoutePath.browsingHistory ||
      RoutePath.userInfo ||
      RoutePath.about ||
      RoutePath.setting ||
      RoutePath.search ||
      RoutePath.cacheQueue ||
      RoutePath.userBookshelf ||
      RoutePath.devTools ||
      RoutePath.yamiboForum ||
      RoutePath.yamiboAuthorThreads ||
      RoutePath.esjzone => true,
      _ => false,
    };
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
