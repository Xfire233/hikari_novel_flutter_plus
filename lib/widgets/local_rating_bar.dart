import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LocalRatingBar extends StatelessWidget {
  const LocalRatingBar({
    super.key,
    required this.rating,
    this.onChanged,
    this.size = 22,
    this.showValue = true,
    this.enabled = true,
    this.compact = false,
  });

  final double rating;
  final ValueChanged<double>? onChanged;
  final double size;
  final bool showValue;
  final bool enabled;
  final bool compact;

  bool get _canEdit => enabled && onChanged != null;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = enabled ? Colors.amber.shade700 : colorScheme.outline;
    final inactiveColor = colorScheme.outlineVariant;
    final normalized = _normalize(rating);
    final stars = Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        return Padding(
          padding: EdgeInsets.only(right: compact ? 1 : 2),
          child: Icon(
            _starIcon(normalized, starValue),
            size: size,
            color: _starIcon(normalized, starValue) == Icons.star_border
                ? inactiveColor
                : activeColor,
          ),
        );
      }),
    );

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        stars,
        if (showValue) ...[
          SizedBox(width: compact ? 3 : 6),
          Text(
            normalized > 0
                ? normalized.toStringAsFixed(normalized % 1 == 0 ? 0 : 1)
                : 'unrated'.tr,
            style: TextStyle(
              fontSize: compact ? 11 : 13,
              color: normalized > 0
                  ? colorScheme.onSurface
                  : colorScheme.outline,
              fontWeight: normalized > 0 ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ],
    );

    if (!_canEdit) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) =>
          _setWholeRatingFromPosition(details.localPosition.dx),
      onLongPressStart: (details) =>
          _setRatingFromPosition(details.localPosition.dx),
      onLongPressMoveUpdate: (details) =>
          _setRatingFromPosition(details.localPosition.dx),
      child: content,
    );
  }

  IconData _starIcon(double value, int starValue) {
    if (value >= starValue) return Icons.star;
    if (value >= starValue - 0.5) return Icons.star_half;
    return Icons.star_border;
  }

  void _setRatingFromPosition(double dx) {
    final starWidth = size + (compact ? 1 : 2);
    final raw = (dx / starWidth).clamp(0, 5);
    final halfStep = ((raw * 2).ceil() / 2).clamp(0.5, 5.0);
    onChanged?.call(halfStep);
  }

  void _setWholeRatingFromPosition(double dx) {
    final starWidth = size + (compact ? 1 : 2);
    final raw = (dx / starWidth).clamp(0, 5);
    onChanged?.call(raw.ceil().clamp(1, 5).toDouble());
  }

  double _normalize(double value) =>
      ((value.clamp(0, 5) * 2).round() / 2).toDouble();
}
