import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/reader_direction.dart';
import 'package:hikari_novel_flutter/pages/reader/controller.dart';
import 'package:hikari_novel_flutter/pages/reader/widgets/custom_header.dart';
import 'package:hikari_novel_flutter/pages/reader/widgets/custom_slider.dart';
import 'package:hikari_novel_flutter/pages/reader/widgets/horizontal_read_page.dart';
import 'package:hikari_novel_flutter/pages/reader/widgets/reader_background.dart';
import 'package:hikari_novel_flutter/pages/reader/widgets/vertical_read_page.dart';
import 'package:hikari_novel_flutter/widgets/state_page.dart';
import 'package:hikari_novel_flutter/widgets/wenku8_browser_assist.dart';
import 'package:intl/intl.dart';
import 'package:hikari_novel_flutter/service/tts_service.dart';
import 'package:hikari_novel_flutter/pages/reader/widgets/tts_floating_controller.dart';

import '../../common/constants.dart';
import '../../models/page_state.dart';
import '../../network/api.dart';
import '../../router/route_path.dart';

enum _ReaderTapAction { previous, center, next }

class ReaderPage extends StatelessWidget {
  ReaderPage({super.key});

  final controller = Get.put(ReaderController());

  final GlobalKey<VerticalReadPageState> _verticalReadPageKey = GlobalKey();

  EdgeInsets _contentPadding(
    BuildContext context, {
    required bool inPageStatusBar,
  }) {
    final settings = controller.readerSettingsState.value;
    final eInkMode = settings.eInkMode;
    final safeTop = MediaQuery.viewPaddingOf(context).top;
    double margin(double value) => eInkMode ? value.clamp(4.0, 12.0) : value;
    final statusPadding = eInkMode ? 18.0 : kStatusBarPadding.toDouble();

    return EdgeInsets.fromLTRB(
      margin(settings.leftMargin),
      safeTop + margin(settings.topMargin),
      margin(settings.rightMargin),
      settings.showStatusBar
          ? margin(settings.bottomMargin) +
                statusPadding +
                (inPageStatusBar ? MediaQuery.of(context).padding.bottom : 0)
          : margin(settings.bottomMargin),
    );
  }

  TextStyle get textStyle => TextStyle(
    fontFamily: controller.readerSettingsState.value.textFamily,
    height: controller.readerSettingsState.value.lineSpacing,
    fontSize: controller.readerSettingsState.value.fontSize,
    color: controller.effectiveTextColor(Get.context!),
  );

  Duration get _barAnimationDuration =>
      controller.readerSettingsState.value.eInkMode
      ? Duration.zero
      : const Duration(milliseconds: 100);

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

  bool _useOverlayBottomStatusBar() {
    final settings = controller.readerSettingsState.value;
    return settings.showStatusBar &&
        settings.direction == ReaderDirection.upToDown;
  }

  bool _useInPageBottomStatusBar() {
    final settings = controller.readerSettingsState.value;
    return settings.showStatusBar &&
        settings.direction != ReaderDirection.upToDown;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Listener(
        onPointerSignal: _handlePointerSignal,
        child: Scaffold(
          body: Stack(
            children: [
              Obx(
                () => controller.pageState.value == PageState.success
                    ? ReaderBackground(
                        child: Obx(
                          () => Padding(
                            padding: EdgeInsets.only(
                              bottom: _useOverlayBottomStatusBar()
                                  ? kStatusBarPadding +
                                        MediaQuery.of(context).padding.bottom
                                  : 0,
                            ),
                            child: _buildReadPage(context),
                          ),
                        ),
                      )
                    : Container(),
              ),
              Obx(
                () => Offstage(
                  offstage: controller.pageState.value != PageState.loading,
                  child: buildWenku8CompatibilityLoadingPage(
                    enabled: !controller.isEsj && !controller.isYamibo,
                  ),
                ),
              ),
              Obx(
                () => Offstage(
                  offstage: controller.pageState.value != PageState.error,
                  child: _buildErrorMessage(),
                ),
              ),
              _buildBottomStatusBar(context),
              const TtsFloatingController(),
              Obx(() {
                //椤舵爮
                double statusBarHeight = MediaQuery.of(context).padding.top;
                return AnimatedPositioned(
                  top: controller.showBar.value
                      ? 0
                      : -(kToolbarHeight + statusBarHeight),
                  left: 0,
                  right: 0,
                  duration: _barAnimationDuration,
                  child: AppBar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.secondaryContainer,
                    title: Text(controller.chapterTitle.value),
                    titleSpacing: 16,
                  ),
                );
              }),
              Obx(() {
                //搴曟爮
                double navigationBarHeight = MediaQuery.of(
                  context,
                ).padding.bottom;
                int bottomBarHeight = 100;
                return AnimatedPositioned(
                  left: 0,
                  right: 0,
                  bottom: controller.showBar.value
                      ? 0
                      : -(navigationBarHeight + bottomBarHeight),
                  duration: _barAnimationDuration,
                  child: Container(
                    height: navigationBarHeight + bottomBarHeight,
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    alignment: Alignment.center,
                    child: Obx(
                      () => Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: _buildProgressBar(context),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: IconButton(
                                  onPressed: () {
                                    if (controller
                                            .readerSettingsState
                                            .value
                                            .direction ==
                                        ReaderDirection.rightToLeft) {
                                      controller.nextChapter();
                                    } else {
                                      controller.prevChapter();
                                    }
                                  },
                                  icon: const Icon(Icons.arrow_back),
                                ),
                              ),
                              Expanded(
                                child: IconButton(
                                  onPressed: () => _showCatalogue(context),
                                  icon: const Icon(Icons.list_alt),
                                ),
                              ),
                              Expanded(
                                child: IconButton(
                                  onPressed: () =>
                                      Get.toNamed(RoutePath.readerSetting),
                                  icon: const Icon(Icons.settings_outlined),
                                ),
                              ),
                              Expanded(
                                child: TtsService.instance.enabled.value
                                    ? IconButton(
                                        tooltip: "listen_to_books".tr,
                                        onPressed: () async {
                                          final tts = TtsService.instance;
                                          final text = controller.text.value;
                                          final cleaned = text
                                              .replaceAll(RegExp(r'\s+'), ' ')
                                              .trim();
                                          if (cleaned.isEmpty) {
                                            showSnackBar(
                                              message:
                                                  "chapter_content_loading_tip"
                                                      .tr,
                                              context: context,
                                            );
                                            return;
                                          }

                                          if (tts.isPlaying.value) {
                                            await tts.stop();
                                            return;
                                          }
                                          if (tts.isPaused.value &&
                                              tts.isSessionActive.value) {
                                            await tts.resumeSession();
                                            return;
                                          }

                                          await tts.startChapter(cleaned);
                                        },
                                        icon: Obx(() {
                                          final tts = TtsService.instance;
                                          if (tts.isPlaying.value) {
                                            return const Icon(
                                              Icons.stop_circle_outlined,
                                            );
                                          }
                                          return const Icon(
                                            Icons.play_circle_outline,
                                          );
                                        }),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              Expanded(
                                child: IconButton(
                                  onPressed: () {
                                    if (controller
                                            .readerSettingsState
                                            .value
                                            .direction ==
                                        ReaderDirection.rightToLeft) {
                                      controller.prevChapter();
                                    } else {
                                      controller.nextChapter();
                                    }
                                  },
                                  icon: const Icon(Icons.arrow_forward),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    final isWenku8 = !controller.isEsj && !controller.isYamibo;
    return buildWenku8BrowserAssistErrorMessage(
      message: controller.errorMsg,
      url: Api.getNovelContentUrl(aid: controller.aid, cid: controller.cid),
      onRetry: controller.getContent,
      enabled: isWenku8,
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_isDesktop || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.pageUp) {
      controller.turnReadingPageThrottled(forward: false);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.space) {
      controller.turnReadingPageThrottled(forward: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      controller.showBar.value = false;
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (!_isDesktop || event is! PointerScrollEvent) return;
    if (controller.readerSettingsState.value.direction ==
        ReaderDirection.upToDown) {
      return;
    }

    final primaryDelta =
        event.scrollDelta.dy.abs() >= event.scrollDelta.dx.abs()
        ? event.scrollDelta.dy
        : event.scrollDelta.dx;
    if (primaryDelta.abs() < 1) return;
    controller.turnReadingPageThrottled(forward: primaryDelta > 0);
  }

  _ReaderTapAction _readerTapAction(
    Offset position,
    Size size, {
    bool reverse = false,
  }) {
    if (size.width <= 0 || size.height <= 0) return _ReaderTapAction.center;
    final third = size.width / 3;
    final x = reverse
        ? (size.width - position.dx).clamp(0.0, size.width)
        : position.dx.clamp(0.0, size.width);
    if (x < third) return _ReaderTapAction.previous;
    if (x < third * 2) return _ReaderTapAction.center;
    return _ReaderTapAction.next;
  }

  void _handleReadPageTap(Offset position, Size size, {bool reverse = false}) {
    switch (_readerTapAction(position, size, reverse: reverse)) {
      case _ReaderTapAction.previous:
        controller.turnReadingPageThrottled(forward: false);
      case _ReaderTapAction.center:
        controller.showBar.value = !controller.showBar.value;
      case _ReaderTapAction.next:
        controller.turnReadingPageThrottled(forward: true);
    }
  }

  Widget _buildReadPage(BuildContext context) {
    return Obx(() {
      if (controller.pageState.value == PageState.success) {
        return controller.readerSettingsState.value.direction ==
                ReaderDirection.upToDown
            ? _buildVertical(context)
            : _buildHorizontal(context);
      } else {
        return Container();
      }
    });
  }

  Widget _buildVertical(BuildContext context) {
    controller.verticalPageTurner = (forward) =>
        _verticalReadPageKey.currentState?.turnPage(
          forward: forward,
          animate: controller.usePageTurningAnimation,
        ) ??
        false;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (details) => _handleReadPageTap(details.localPosition, size),
          child: SizedBox(
            height: double.infinity,
            child: EasyRefresh(
              header: MaterialHeader2(
                triggerOffset: 80,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.arrow_circle_up,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              footer: MaterialFooter2(
                triggerOffset: 80,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.arrow_circle_down,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              refreshOnStart: false,
              onRefresh: controller.prevChapter,
              onLoad: controller.nextChapter,
              child: VerticalReadPage(
                key: _verticalReadPageKey,
                controller.text.value,
                controller.images,
                initialOffset: controller.initialVerticalOffset,
                initialProgress: controller.modeSwitchInitialProgress,
                padding: _contentPadding(context, inPageStatusBar: false),
                style: textStyle,
                paraSpacing:
                    controller.readerSettingsState.value.readerParaSpacing,
                paraIndent:
                    controller.readerSettingsState.value.readerParaIndent,
                eInkMode: controller.readerSettingsState.value.eInkMode,
                onScroll: (position, max) {
                  if (max == 0 && position == 0) {
                    controller.currentLocation.value = 0;
                    controller.verticalProgress.value = 100;
                    controller.setReadHistory();
                  } else if (max > 0) {
                    controller.currentLocation.value = position.toInt();
                    controller.verticalProgress.value = ((position / max) * 100)
                        .clamp(0, 100)
                        .toInt();
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHorizontal(BuildContext context) {
    final eInkMode = controller.readerSettingsState.value.eInkMode;
    final horizontalReader = HorizontalReadPage(
      controller.text.value,
      controller.images,
      initIndex: controller.initialHorizontalIndex,
      initProgress: controller.modeSwitchInitialProgress,
      padding: _contentPadding(
        context,
        inPageStatusBar: _useInPageBottomStatusBar(),
      ),
      style: textStyle,
      reverse:
          controller.readerSettingsState.value.direction ==
          ReaderDirection.rightToLeft,
      isDualPage: controller.isDualPage,
      dualPageSpacing: controller.readerSettingsState.value.dualPageSpacing,
      controller: controller.pageController,
      pageTurningAnimation: false,
      eInkMode: eInkMode,
      paraSpacing: controller.readerSettingsState.value.readerParaSpacing,
      paraIndent: controller.readerSettingsState.value.readerParaIndent,
      paperCurlController: controller.paperCurlController,
      backgroundColor: controller.effectiveBgColor(context),
      backsideColor: Color.lerp(
        controller.effectiveBgColor(context),
        Theme.of(context).colorScheme.surfaceTint,
        Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.10,
      ),
      pageFooter: _useInPageBottomStatusBar()
          ? _buildInPageStatusBar(context)
          : null,
      onCenterTap: () => controller.showBar.value = !controller.showBar.value,
      onLeftTap: controller.prevPage,
      onRightTap: controller.nextPage,
      onReachStart: () => controller.prevChapter(openAtEnd: true),
      onReachEnd: controller.nextChapter,
      onPageChanged: (index, max) {
        controller.currentIndex.value = index;
        controller.maxPage.value = max;
        if (max == 1 && index == 0) {
          controller.horizontalProgress.value = 100;
          controller.setReadHistory();
        } else if (max > 0) {
          controller.horizontalProgress.value = int.parse(
            ((index + 1) / max * 100.0).toStringAsFixed(0),
          ).clamp(0, 100);
        }
      },
      onViewImage: (index) => Get.toNamed(
        RoutePath.photo,
        arguments: {
          "gallery_mode": true,
          "list": controller.images,
          "index": index,
        },
      ),
    );

    if (eInkMode) {
      return horizontalReader;
    }

    return EasyRefresh(
      header: MaterialHeader2(
        triggerOffset: 80,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(12),
          child: Icon(
            Icons.arrow_circle_left_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
      footer: MaterialFooter2(
        triggerOffset: 80,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(12),
          child: Icon(
            Icons.arrow_circle_right_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
      refreshOnStart: false,
      onRefresh: () => controller.prevChapter(openAtEnd: true),
      onLoad: controller.nextChapter,
      child: horizontalReader,
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    return Obx(() {
      if (controller.pageState.value != PageState.success) {
        return SizedBox(height: 48, child: Container());
      }
      if (controller.readerSettingsState.value.direction ==
          ReaderDirection.upToDown) {
        int value = controller.verticalProgress.value;

        return SizedBox(
          height: 48,
          child: Row(
            children: [
              SizedBox(width: 60, child: Center(child: Text("$value%"))),
              Expanded(
                child: Slider(
                  activeColor: Theme.of(context).colorScheme.primary,
                  inactiveColor: Theme.of(context).colorScheme.surface,
                  value: value.toDouble(),
                  max: 100.0,
                  onChanged: (e) {
                    _verticalReadPageKey.currentState!.jumpToProgress(e);
                  },
                  divisions: 99,
                ),
              ),
              SizedBox(width: 60, child: Center(child: Text("100%"))),
            ],
          ),
        );
      } else {
        int value = controller.currentIndex.value + 1;
        int max = controller.maxPage.value;

        if (value > max || max == 1) {
          return SizedBox(
            height: 48,
            child: Center(child: Text("only_one_page".tr)),
          );
        }
        return SizedBox(
          height: 48,
          child: Row(
            children: [
              SizedBox(
                width: 60,
                child: Center(
                  child:
                      controller.readerSettingsState.value.direction ==
                          ReaderDirection.leftToRight
                      ? Text(value.toString())
                      : Text(max.toString()),
                ),
              ),
              Expanded(
                child: CustomSlider(
                  min: 1,
                  max: max.toDouble(),
                  value: value.toDouble(),
                  divisions: max - 1,
                  onChanged: (v) => controller.jumpToPage((v - 1).toInt()),
                  focusNode: null,
                  reversed:
                      controller.readerSettingsState.value.direction !=
                      ReaderDirection.leftToRight,
                ),
              ),
              SizedBox(
                width: 60,
                child: Center(
                  child:
                      controller.readerSettingsState.value.direction ==
                          ReaderDirection.leftToRight
                      ? Text(max.toString())
                      : Text(value.toString()),
                ),
              ),
            ],
          ),
        );
      }
    });
  }

  void _showCatalogue(BuildContext context) {
    showModalBottomSheet(
      context: context,
      enableDrag: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: BottomSheet(
          onClosing: () {},
          builder: (_) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: controller.catalogue.length,
                  itemBuilder: (context, volumeIndex) {
                    final volume = controller.catalogue[volumeIndex];

                    return ExpansionTile(
                      shape: const Border(),
                      title: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          volume.title,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                      children: volume.chapters.asMap().entries.map((entry) {
                        final chapterIndex = entry.key;
                        final chapter = entry.value;

                        return ListTile(
                          title: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              volumeIndex == controller.currentVolumeIndex &&
                                      chapterIndex ==
                                          controller.currentChapterIndex
                                  ? Row(
                                      children: [
                                        SizedBox(
                                          height: 22,
                                          child: Icon(
                                            Icons.arrow_circle_right,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                      ],
                                    )
                                  : Container(),
                              Text(
                                chapter.title,
                                style:
                                    volumeIndex ==
                                            controller.currentVolumeIndex &&
                                        chapterIndex ==
                                            controller.currentChapterIndex
                                    ? TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      )
                                    : const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                          contentPadding: const EdgeInsets.only(
                            left: 50.0,
                            right: 24.0,
                          ),
                          onTap: () {
                            controller.currentVolumeIndex = volumeIndex;
                            controller.currentChapterIndex = chapterIndex;
                            controller.getContent();
                            Get.back();
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomStatusBar(BuildContext context) {
    final spacing = controller
        .readerSettingsState
        .value
        .readerBottomStatusBarHorizontalSpacing
        .toDouble();
    return Positioned(
      right: 8,
      left: 8,
      bottom: 4,
      child: Obx(
        () => Offstage(
          offstage:
              !(_useOverlayBottomStatusBar() &&
                  controller.pageState.value == PageState.success),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              spacing,
              0,
              spacing,
              MediaQuery.of(context).padding.bottom,
            ),
            child: _buildStatusBarContent(context),
          ),
        ),
      ),
    );
  }

  Widget _buildInPageStatusBar(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final spacing = controller
        .readerSettingsState
        .value
        .readerBottomStatusBarHorizontalSpacing
        .toDouble();
    return SizedBox(
      width: double.infinity,
      height: kStatusBarPadding.toDouble() + bottomInset,
      child: Padding(
        padding: EdgeInsets.fromLTRB(spacing, 0, spacing, bottomInset),
        child: _buildStatusBarContent(context),
      ),
    );
  }

  Widget _buildStatusBarContent(BuildContext context) {
    return Obx(() {
      final textColor = controller.effectiveTextColor(context);
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          StreamBuilder(
            stream: controller.clockStream(),
            builder: (_, snapshot) {
              final now = snapshot.data ?? DateTime.now();
              final timeString = DateFormat('HH:mm').format(now);
              return Text(
                timeString,
                style: TextStyle(fontSize: 13, color: textColor),
              );
            },
          ),
          const SizedBox(width: 8),
          IconTheme(
            data: IconThemeData(color: textColor),
            child: _buildBattery(context, controller.batteryLevel.value),
          ),
          Text(
            "${controller.batteryLevel.value}%",
            style: TextStyle(fontSize: 13, color: textColor),
          ),
          const Spacer(),
          controller.readerSettingsState.value.direction ==
                  ReaderDirection.upToDown
              ? Text(
                  "${controller.verticalProgress.value} %",
                  style: TextStyle(fontSize: 13, color: textColor),
                )
              : Text(
                  "${controller.currentIndex.value + 1} / ${controller.maxPage.value}",
                  style: TextStyle(fontSize: 13, color: textColor),
                ),
        ],
      );
    });
  }

  Widget _buildBattery(BuildContext context, int value) {
    if (value >= 95) {
      return const Icon(Icons.battery_full, size: kSmallIconSize);
    } else if (value >= 85) {
      return const Icon(Icons.battery_6_bar, size: kSmallIconSize); // ~90%
    } else if (value >= 65) {
      return const Icon(Icons.battery_5_bar, size: kSmallIconSize); // ~80%
    } else if (value >= 45) {
      return const Icon(Icons.battery_4_bar, size: kSmallIconSize); // ~60%
    } else if (value >= 35) {
      return const Icon(Icons.battery_3_bar, size: kSmallIconSize); // ~50%
    } else if (value >= 25) {
      return const Icon(Icons.battery_2_bar, size: kSmallIconSize); // ~30%
    } else if (value >= 15) {
      return const Icon(Icons.battery_1_bar, size: kSmallIconSize); // ~20%
    } else {
      return const Icon(Icons.battery_0_bar, size: kSmallIconSize); // <15%
    }
  }
}
