import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/pages/home/controller.dart';

class HomeCollapsibleFilterBar extends StatelessWidget {
  const HomeCollapsibleFilterBar({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled || !Get.isRegistered<HomeController>()) return child;
    final controller = Get.find<HomeController>();
    return Obx(() {
      if (!controller.homeChromeCanCollapse) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          controller.expandHomeSections();
        });
        return child;
      }
      final expanded = controller.appBarSectionsExpanded.value;
      final animationsEnabled = controller.homeAnimationsEnabled;
      return TweenAnimationBuilder<double>(
        tween: Tween<double>(end: expanded ? 1 : 0),
        duration: animationsEnabled
            ? (expanded
                  ? const Duration(milliseconds: 340)
                  : const Duration(milliseconds: 700))
            : Duration.zero,
        curve: expanded ? Curves.easeOutCubic : Curves.easeInOutCubic,
        child: child,
        builder: (context, factor, child) {
          final safeFactor = factor.clamp(0.0, 1.0);
          final opacity = expanded
              ? safeFactor
              : (safeFactor * 1.6).clamp(0.0, 1.0);
          return ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: safeFactor,
              child: Opacity(
                opacity: opacity,
                child: IgnorePointer(
                  ignoring: safeFactor < 0.98,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          );
        },
      );
    });
  }
}
