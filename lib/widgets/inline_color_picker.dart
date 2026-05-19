import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class InlineColorPicker extends StatelessWidget {
  const InlineColorPicker({
    super.key,
    required this.color,
    required this.onChanged,
    required this.onCommitted,
    required this.onReset,
    required this.resetLabel,
    this.recentColors = const [],
    this.recommendedColors = recommendedLowSaturationColors,
  });

  static const List<Color> recommendedLowSaturationColors = [
    Color(0xFF9DB7B3),
    Color(0xFFA8B59B),
    Color(0xFFC5B7A4),
    Color(0xFFD0A9A1),
    Color(0xFFC3A5B5),
    Color(0xFFA6A1C7),
    Color(0xFF9FB3CC),
    Color(0xFFB8B0A3),
  ];

  final Color color;
  final ValueChanged<Color> onChanged;
  final ValueChanged<Color> onCommitted;
  final VoidCallback onReset;
  final String resetLabel;
  final List<Color> recentColors;
  final List<Color> recommendedColors;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wheelDiameter = (constraints.maxWidth - 64)
            .clamp(150.0, 220.0)
            .toDouble();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ColorPicker(
                color: color,
                onColorChanged: onChanged,
                onColorChangeEnd: onCommitted,
                showColorCode: true,
                colorCodeTextStyle: textTheme.bodySmall,
                colorCodeReadOnly: false,
                enableShadesSelection: false,
                padding: const EdgeInsets.symmetric(vertical: 8),
                wheelDiameter: wheelDiameter,
                wheelWidth: 18,
                wheelHasBorder: true,
                hasBorder: true,
                pickersEnabled: const <ColorPickerType, bool>{
                  ColorPickerType.both: false,
                  ColorPickerType.primary: false,
                  ColorPickerType.accent: false,
                  ColorPickerType.bw: false,
                  ColorPickerType.custom: false,
                  ColorPickerType.customSecondary: false,
                  ColorPickerType.wheel: true,
                },
                copyPasteBehavior: ColorPickerCopyPasteBehavior().copyWith(
                  copyFormat: ColorPickerCopyFormat.hexRRGGBB,
                ),
              ),
              if (recentColors.isNotEmpty)
                _ColorSwatches(
                  title: "recent_colors".tr,
                  colors: recentColors,
                  onSelect: _selectColor,
                ),
              _ColorSwatches(
                title: "recommended_colors".tr,
                colors: recommendedColors,
                onSelect: _selectColor,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.restart_alt),
                  label: Text(resetLabel),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _selectColor(Color color) {
    onChanged(color);
    onCommitted(color);
  }
}

class _ColorSwatches extends StatelessWidget {
  const _ColorSwatches({
    required this.title,
    required this.colors,
    required this.onSelect,
  });

  final String title;
  final List<Color> colors;
  final ValueChanged<Color> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: colors
                .map(
                  (color) => InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => onSelect(color),
                    child: ColorIndicator(
                      width: 32,
                      height: 32,
                      borderRadius: 18,
                      color: color,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}
