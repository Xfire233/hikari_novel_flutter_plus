import 'dart:io';

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/common/extension.dart';
import 'package:hikari_novel_flutter/service/local_storage_service.dart';
import 'package:hikari_novel_flutter/service/tts_service.dart';
import 'package:hikari_novel_flutter/widgets/custom_tile.dart';
import 'package:hikari_novel_flutter/widgets/inline_color_picker.dart';
import 'package:hikari_novel_flutter/widgets/state_page.dart';

import '../../../models/dual_page_mode.dart';
import '../../../models/reader_direction.dart';
import '../controller.dart';

class ReaderSettingPage extends StatelessWidget {
  ReaderSettingPage({super.key});

  final ReaderController controller = Get.find();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text("setting".tr),
          titleSpacing: 16,
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.settings_outlined), text: "basic".tr),
              Tab(icon: const Icon(Icons.palette_outlined), text: "theme".tr),
              Tab(
                icon: const Icon(Icons.record_voice_over_outlined),
                text: "listen_to_books".tr,
              ),
              Tab(icon: const Icon(Icons.padding), text: "margin".tr),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildBasic(context),
            _buildTheme(context),
            _buildListen(context),
            _buildPadding(),
          ],
        ),
      ),
    );
  }

  Widget _buildBasic(BuildContext context) {
    return ListView(
      children: [
        Obx(
          () => SliderTile(
            title: "font_size".tr,
            leading: const Icon(Icons.format_size),
            min: 7,
            max: 48,
            divisions: 41,
            decimalPlaces: 0,
            value: controller.readerSettingsState.value.fontSize,
            onChanged: (value) => controller.readerSettingsState.value =
                controller.readerSettingsState.value.copyWith(fontSize: value),
            onChangeEnd: (value) => controller.changeFontSize(value),
          ),
        ),
        Obx(
          () => SliderTile(
            title: "line_spacing".tr,
            leading: const Icon(Icons.format_line_spacing_outlined),
            min: 0.1,
            max: 3,
            divisions: 29,
            decimalPlaces: 1,
            value: controller.readerSettingsState.value.lineSpacing,
            onChanged: (value) =>
                controller.readerSettingsState.value = controller
                    .readerSettingsState
                    .value
                    .copyWith(lineSpacing: value),
            onChangeEnd: (value) => controller.changeLineSpacing(value),
          ),
        ),
        Obx(
          () => SliderTile(
            title: "para_indent".tr,
            leading: const Icon(Icons.format_indent_increase),
            min: 0,
            max: 10,
            divisions: 10,
            decimalPlaces: 0,
            value: controller.readerSettingsState.value.readerParaIndent,
            onChanged: (value) =>
                controller.readerSettingsState.value = controller
                    .readerSettingsState
                    .value
                    .copyWith(readerParaIndent: value.toInt()),
            onChangeEnd: (value) =>
                controller.changeReaderParaIndent(value.toInt()),
          ),
        ),
        Obx(
          () => SliderTile(
            title: "para_spacing".tr,
            leading: const Icon(Icons.expand),
            min: 0,
            max: 50,
            divisions: 50,
            decimalPlaces: 0,
            value: controller.readerSettingsState.value.readerParaSpacing,
            onChanged: (value) =>
                controller.readerSettingsState.value = controller
                    .readerSettingsState
                    .value
                    .copyWith(readerParaSpacing: value.toInt()),
            onChangeEnd: (value) =>
                controller.changeReaderParaSpacing(value.toInt()),
          ),
        ),
        Obx(() {
          final sub = switch (controller.readerSettingsState.value.direction) {
            ReaderDirection.leftToRight => "left_to_right".tr,
            ReaderDirection.rightToLeft => "right_to_left".tr,
            ReaderDirection.upToDown => "scroll".tr,
          };
          return NormalTile(
            title: "reading_direction".tr,
            subtitle: sub,
            leading: const Icon(Icons.chrome_reader_mode_outlined),
            trailing: const Icon(Icons.keyboard_arrow_down),
            onTap: () =>
                Get.dialog(
                  RadioListDialog(
                    value: controller.readerSettingsState.value.direction,
                    values: [
                      (ReaderDirection.upToDown, "scroll".tr),
                      (ReaderDirection.leftToRight, "left_to_right".tr),
                      (ReaderDirection.rightToLeft, "right_to_left".tr),
                    ],
                    title: "reading_direction".tr,
                  ),
                ).then((value) {
                  if (value != null) controller.changeReaderDirection(value);
                }),
          );
        }),
        Obx(
          () => SwitchTile(
            title: "eink_mode".tr,
            subtitle: "eink_mode_desc".tr,
            leading: const Icon(Icons.tablet_android_outlined),
            onChanged: (enabled) => controller.changeReaderEInkMode(enabled),
            value: controller.readerSettingsState.value.eInkMode,
          ),
        ),
        Obx(
          () => Offstage(
            offstage: controller.readerSettingsState.value.eInkMode,
            child: SwitchTile(
              title: "page_turning_animation".tr,
              subtitle: "page_turning_animation_desc".tr,
              leading: const Icon(Icons.animation),
              onChanged: (enabled) =>
                  controller.changeReaderPageTurningAnimation(enabled),
              value: controller.readerSettingsState.value.pageTurningAnimation,
            ),
          ),
        ),
        Obx(
          () => SwitchTile(
            title: "screen_stays_on".tr,
            leading: const Icon(Icons.lightbulb_outlined),
            onChanged: (enabled) => controller.changeReaderWakeLock(enabled),
            value: controller.readerSettingsState.value.wakeLock,
          ),
        ),
        Offstage(
          offstage: !(Platform.isAndroid || Platform.isIOS),
          child: Obx(
            () => SwitchTile(
              title: "immersive_mode".tr,
              leading: const Icon(Icons.width_full_outlined),
              onChanged: (enabled) => controller.changeImmersionMode(enabled),
              value: controller.readerSettingsState.value.immersionMode,
            ),
          ),
        ),
        Obx(
          () => SwitchTile(
            title: "show_status_bar".tr,
            leading: const Icon(Icons.call_to_action_outlined),
            onChanged: (enabled) => controller.changeShowStatusBar(enabled),
            value: controller.readerSettingsState.value.showStatusBar,
          ),
        ),
        Offstage(
          offstage: !Platform.isAndroid,
          child: Obx(
            () => SwitchTile(
              title: "volume_key_turning".tr,
              subtitle: "volume_key_turning_desc".tr,
              leading: const Icon(Icons.volume_up_outlined),
              onChanged: (enabled) =>
                  controller.changeVolumeKeyTurning(enabled),
              value: controller.readerSettingsState.value.volumeKeyTurning,
            ),
          ),
        ),
        Obx(
          () => Offstage(
            offstage:
                controller.readerSettingsState.value.direction ==
                ReaderDirection.upToDown,
            child: NormalTile(
              title: "dual_page".tr,
              subtitle:
                  controller.readerSettingsState.value.dualPageMode.name.tr,
              leading: const Icon(Icons.looks_two_outlined),
              trailing: const Icon(Icons.keyboard_arrow_down),
              onTap: () =>
                  Get.dialog(
                    RadioListDialog(
                      value: controller.readerSettingsState.value.dualPageMode,
                      values: [
                        (DualPageMode.auto, "auto".tr),
                        (DualPageMode.enabled, "enable".tr),
                        (DualPageMode.disabled, "disable".tr),
                      ],
                      title: "dual_page".tr,
                    ),
                  ).then((value) {
                    if (value != null) controller.changeDualPageMode(value);
                  }),
            ),
          ),
        ),
        Obx(() {
          final dualPageMode =
              switch (controller.readerSettingsState.value.dualPageMode) {
                DualPageMode.auto => Get.context!.shouldAutoUseDualPage(),
                DualPageMode.enabled => true,
                DualPageMode.disabled => false,
              };
          return Offstage(
            offstage:
                !dualPageMode ||
                controller.readerSettingsState.value.direction ==
                    ReaderDirection.upToDown,
            child: SliderTile(
              title: "dual_page_spacing".tr,
              leading: const Icon(Icons.space_bar_outlined),
              min: 0,
              max: 60,
              divisions: 120,
              decimalPlaces: 1,
              value: controller.readerSettingsState.value.dualPageSpacing,
              onChanged: (value) =>
                  controller.readerSettingsState.value = controller
                      .readerSettingsState
                      .value
                      .copyWith(dualPageSpacing: value),
              onChangeEnd: (value) => controller.changeDualPageSpacing(value),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTheme(BuildContext context) {
    return ListView(
      children: [
        Obx(
          () => NormalTile(
            title: "font".tr,
            subtitle: controller.isFontFileAvailable.value
                ? controller.readerSettingsState.value.textFamily.toString()
                : "system_font".tr,
            leading: const Icon(Icons.format_shapes_outlined),
            trailing: const Icon(Icons.keyboard_arrow_down),
            onTap: () =>
                Get.dialog(
                  NormalListDialog(
                    values: [(0, "system_font".tr), (1, "custom_font".tr)],
                    title: "font".tr,
                  ),
                ).then((value) async {
                  if (value == 0) {
                    await controller.deleteFontDir();
                    controller.changeReaderTextStyleFilePath(null);
                    controller.changeReaderTextFamily(null);
                    controller.checkFontFile(false);
                    showSnackBar(
                      message: "set_system_font_successfully".tr,
                      context: Get.context!,
                    );
                  } else if (value == 1) {
                    final result = await controller.pickTextStyleFile();
                    switch (result) {
                      case null:
                        return;
                      case true:
                        {
                          showSnackBar(
                            message: "set_font_successfully".tr,
                            context: Get.context!,
                          );
                          controller.checkFontFile(false);
                        }
                      case false:
                        showSnackBar(
                          message: "set_font_failed".tr,
                          context: Get.context!,
                        );
                    }
                  }
                }),
          ),
        ),
        Obx(() => _buildReaderColorTile(context, isTextColor: true)),
        Obx(() => _buildReaderColorTile(context, isTextColor: false)),
        Obx(() => _buildBackgroundImageTile(context)),
      ],
    );
  }

  Widget _buildReaderColorTile(
    BuildContext context, {
    required bool isTextColor,
  }) {
    final currentColor = isTextColor
        ? controller.currentTextColor.value
        : controller.currentBgColor.value;
    final fallbackColor = isTextColor
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).colorScheme.surface;
    return ExpansionTile(
      leading: Icon(
        isTextColor
            ? Icons.format_color_text_outlined
            : Icons.format_color_fill_rounded,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(isTextColor ? "font_color".tr : "background_color".tr),
          ),
          if (currentColor != null)
            ColorIndicator(
              width: 22,
              height: 22,
              borderRadius: 100,
              color: currentColor,
            ),
        ],
      ),
      children: [
        InlineColorPicker(
          color: currentColor ?? fallbackColor,
          recentColors: isTextColor
              ? LocalStorageService.instance.getRecentReaderTextColors()
              : LocalStorageService.instance.getRecentReaderBgColors(),
          resetLabel: isTextColor
              ? "reset_font_color".tr
              : "reset_background_color".tr,
          onChanged: (color) => _setReaderColor(color, isTextColor),
          onCommitted: (color) {
            if (isTextColor) {
              LocalStorageService.instance.addRecentReaderTextColor(color);
            } else {
              LocalStorageService.instance.addRecentReaderBgColor(color);
            }
          },
          onReset: () {
            _setReaderColor(null, isTextColor);
            showSnackBar(
              message: isTextColor
                  ? "reset_font_color_successfully".tr
                  : "reset_background_color_successfully".tr,
              context: context,
            );
          },
        ),
      ],
    );
  }

  Widget _buildBackgroundImageTile(BuildContext context) {
    final imagePath = controller.currentBgImagePath.value;
    return ExpansionTile(
      leading: const Icon(Icons.image_outlined),
      title: Text("background_image".tr),
      subtitle: imagePath == null || imagePath.isEmpty
          ? null
          : Text(
              File(imagePath).uri.pathSegments.last,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _pickBackgroundImage,
              icon: const Icon(Icons.image_search_outlined),
              label: Text("change_background_image".tr),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Get.context!.isDarkMode
                    ? controller.changeReaderNightBgImage(null)
                    : controller.changeReaderDayBgImage(null);
                showSnackBar(
                  message: "reset_background_image_successfully".tr,
                  context: context,
                );
              },
              icon: const Icon(Icons.restart_alt),
              label: Text("reset_background_image".tr),
            ),
          ),
        ),
      ],
    );
  }

  void _setReaderColor(Color? color, bool isTextColor) {
    if (Get.context!.isDarkMode) {
      isTextColor
          ? controller.changeReaderNightTextColor(color)
          : controller.changeReaderNightBgColor(color);
    } else {
      isTextColor
          ? controller.changeReaderDayTextColor(color)
          : controller.changeReaderDayBgColor(color);
    }
  }

  void _pickBackgroundImage() {
    controller.pickBgImageFile(Get.context!.isDarkMode).then((result) {
      switch (result) {
        case null:
          return;
        case true:
          _showReaderSnack("set_background_successfully".tr);
        case false:
          _showReaderSnack("set_background_failed".tr);
      }
    });
  }

  void _showReaderSnack(String message) {
    final context = Get.context;
    if (context == null) return;
    showSnackBar(message: message, context: context);
  }

  Widget _buildListen(BuildContext context) {
    final tts = TtsService.instance;
    return ListView(
      children: [
        Obx(
          () => SwitchTile(
            title: "enabled_listening".tr,
            leading: const Icon(Icons.record_voice_over_outlined),
            onChanged: (v) => tts.setEnabled(v),
            value: tts.enabled.value,
          ),
        ),
        NormalTile(
          title: "open_tts_system_setting".tr,
          leading: const Icon(Icons.settings_applications_outlined),
          trailing: const Icon(Icons.open_in_new),
          onTap: tts.openAndroidTtsSettings,
        ),
        Obx(
          () => Offstage(
            offstage: !tts.enabled.value,
            child: Column(
              children: [
                Obx(
                  () => NormalTile(
                    title: "tts_engine".tr,
                    subtitle: tts.engine.value == null
                        ? (Platform.isAndroid
                              ? "auto".tr
                              : "unsupportable_os_tip".tr)
                        : tts.displayEngineName(tts.engine.value!),
                    leading: const Icon(Icons.settings_outlined),
                    trailing: const Icon(Icons.keyboard_arrow_down),
                    onTap: () async {
                      await tts.refreshEngines();
                      Get.dialog(
                        NormalListDialog(
                          values: [
                            (null, "auto".tr),
                            ...tts.engines.map(
                              (value) => (value, tts.displayEngineName(value)),
                            ),
                          ],
                          title: "tts_engine".tr,
                        ),
                      ).then((value) async {
                        if (value == null) {
                          tts.applyEngine(null);
                        } else {
                          await tts.applyEngine(value);
                          await tts.refreshVoices();
                        }
                      });
                    },
                  ),
                ),
                Obx(
                  () => NormalTile(
                    title: "timbre".tr,
                    subtitle: tts.voice.value == null
                        ? "auto".tr
                        : "${tts.voice.value!["name"]}(${tts.voice.value!["locale"]})",
                    leading: const Icon(Icons.surround_sound_outlined),
                    trailing: const Icon(Icons.keyboard_arrow_down),
                    onTap: () async {
                      await tts.refreshVoices();
                      Get.dialog(
                        NormalListDialog(
                          values: [
                            (null, "auto".tr),
                            ...tts.voices.map(
                              (value) => (
                                value,
                                "${value["name"]}(${value["locale"]})",
                              ),
                            ),
                          ],
                          title: "timbre".tr,
                        ),
                      ).then((value) async {
                        if (value == null) {
                          tts.applyVoice(null);
                        } else {
                          await tts.applyVoice(value);
                        }
                      });
                    },
                  ),
                ),
                const Divider(height: 1),
                Obx(
                  () => SliderTile(
                    title: "speech_rate".tr,
                    leading: const Icon(Icons.speed),
                    min: 0.1,
                    max: 1.0,
                    divisions: 18,
                    decimalPlaces: 1,
                    value: tts.rate.value,
                    onChanged: (v) => tts.rate.value = v,
                    onChangeEnd: (v) => tts.setRate(v),
                  ),
                ),
                Obx(
                  () => SliderTile(
                    title: "tone".tr,
                    leading: const Icon(Icons.graphic_eq),
                    min: 0.5,
                    max: 2.0,
                    divisions: 15,
                    decimalPlaces: 1,
                    value: tts.pitch.value,
                    onChanged: (v) => tts.pitch.value = v,
                    onChangeEnd: (v) => tts.setPitch(v),
                  ),
                ),
                Obx(
                  () => SliderTile(
                    title: "volume".tr,
                    leading: const Icon(Icons.volume_up_outlined),
                    min: 0,
                    max: 1,
                    divisions: 20,
                    decimalPlaces: 2,
                    value: tts.volume.value,
                    onChanged: (v) => tts.volume.value = v,
                    onChangeEnd: (v) => tts.setVolume(v),
                  ),
                ),
                const Divider(height: 1),
                NormalTile(
                  title: "refresh_setting".tr,
                  subtitle: "refresh_tts_setting_tip".tr,
                  leading: const Icon(Icons.refresh),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          tts.refreshSettings(restartIfPlaying: true),
                      icon: const Icon(Icons.refresh),
                      label: Text("refresh_setting".tr),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPadding() {
    return ListView(
      children: [
        Obx(
          () => SliderTile(
            title: "left_margin".tr,
            leading: const Icon(Icons.border_left),
            min: 0,
            max: 100,
            divisions: 100,
            decimalPlaces: 0,
            value: controller.readerSettingsState.value.leftMargin,
            onChanged: (value) =>
                controller.readerSettingsState.value = controller
                    .readerSettingsState
                    .value
                    .copyWith(leftMargin: value),
            onChangeEnd: (value) => controller.changeLeftMargin(value),
          ),
        ),
        Obx(
          () => SliderTile(
            title: "top_margin".tr,
            leading: const Icon(Icons.border_top),
            min: 0,
            max: 100,
            divisions: 100,
            decimalPlaces: 0,
            value: controller.readerSettingsState.value.topMargin,
            onChanged: (value) => controller.readerSettingsState.value =
                controller.readerSettingsState.value.copyWith(topMargin: value),
            onChangeEnd: (value) => controller.changeTopMargin(value),
          ),
        ),
        Obx(
          () => SliderTile(
            title: "right_margin".tr,
            leading: const Icon(Icons.border_right),
            min: 0,
            max: 100,
            divisions: 100,
            decimalPlaces: 0,
            value: controller.readerSettingsState.value.rightMargin,
            onChanged: (value) =>
                controller.readerSettingsState.value = controller
                    .readerSettingsState
                    .value
                    .copyWith(rightMargin: value),
            onChangeEnd: (value) => controller.changeRightMargin(value),
          ),
        ),
        Obx(
          () => SliderTile(
            title: "bottom_margin".tr,
            leading: const Icon(Icons.border_bottom),
            min: 0,
            max: 100,
            divisions: 100,
            decimalPlaces: 0,
            value: controller.readerSettingsState.value.bottomMargin,
            onChanged: (value) =>
                controller.readerSettingsState.value = controller
                    .readerSettingsState
                    .value
                    .copyWith(bottomMargin: value),
            onChangeEnd: (value) => controller.changeBottomMargin(value),
          ),
        ),
        Obx(
          () => SliderTile(
            title: "bottomStatusBarHorizontalSpacing".tr,
            leading: const Icon(Icons.swap_horiz),
            min: 0,
            max: 100,
            divisions: 100,
            decimalPlaces: 0,
            value: controller
                .readerSettingsState
                .value
                .readerBottomStatusBarHorizontalSpacing,
            onChanged: (value) => controller.readerSettingsState.value =
                controller.readerSettingsState.value.copyWith(
                  readerBottomStatusBarHorizontalSpacing: value.toInt(),
                ),
            onChangeEnd: (value) => controller
                .changeReaderBottomStatusBarHorizontalSpacing(value.toInt()),
          ),
        ),
      ],
    );
  }
}
