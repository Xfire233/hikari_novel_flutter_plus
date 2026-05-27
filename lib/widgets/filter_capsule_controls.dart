import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/pages/home/controller.dart';

class FilterCapsuleOption<T> {
  const FilterCapsuleOption({required this.value, required this.label});

  final T value;
  final String label;
}

class FilterCapsuleButton extends StatelessWidget {
  const FilterCapsuleButton({
    super.key,
    required this.label,
    required this.expanded,
    required this.onTap,
    this.tooltip,
    this.emphasized = false,
    this.width,
  });

  final String label;
  final bool expanded;
  final VoidCallback onTap;
  final String? tooltip;
  final bool emphasized;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = emphasized
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;
    final background = emphasized
        ? scheme.secondaryContainer.withValues(alpha: 0.86)
        : scheme.surface.withValues(alpha: 0.54);
    return SizedBox(
      width: width,
      height: 52,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 6),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              FilterCapsuleArrow(
                tooltip: tooltip ?? label,
                foreground: foreground,
                background: emphasized
                    ? scheme.secondaryContainer.withValues(alpha: 0.1)
                    : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                expanded: expanded,
                onTap: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FilterCapsuleOptionRow<T> extends StatelessWidget {
  const FilterCapsuleOptionRow({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onSelected,
    this.tooltip,
  });

  final List<FilterCapsuleOption<T>> options;
  final T selectedValue;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<T> onSelected;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visibleOptions = _orderedOptions();
    return SizedBox(
      height: 52,
      child: Material(
        color: scheme.surface.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(18),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
                child: Row(
                  children: [
                    for (var i = 0; i < visibleOptions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      FilterCapsuleChip(
                        label: visibleOptions[i].label,
                        selected: visibleOptions[i].value == selectedValue,
                        onTap: () => onSelected(visibleOptions[i].value),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            FilterCapsuleArrow(
              tooltip: tooltip,
              foreground: scheme.onSurfaceVariant,
              background: scheme.surfaceContainerHighest.withValues(
                alpha: 0.45,
              ),
              expanded: expanded,
              onTap: onToggleExpanded,
            ),
          ],
        ),
      ),
    );
  }

  List<FilterCapsuleOption<T>> _orderedOptions() {
    final visible = <FilterCapsuleOption<T>>[];
    for (final option in options) {
      if (option.value == selectedValue) {
        visible.add(option);
        break;
      }
    }
    for (final option in options) {
      if (visible.any((item) => item.value == option.value)) continue;
      visible.add(option);
    }
    return visible;
  }
}

class FilterCapsulePanel<T> extends StatefulWidget {
  const FilterCapsulePanel({
    super.key,
    required this.expanded,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    this.maxHeight = 210,
  });

  final bool expanded;
  final List<FilterCapsuleOption<T>> options;
  final T selectedValue;
  final ValueChanged<T> onSelected;
  final double maxHeight;

  @override
  State<FilterCapsulePanel<T>> createState() => _FilterCapsulePanelState<T>();
}

class _FilterCapsulePanelState<T> extends State<FilterCapsulePanel<T>> {
  bool _blockingHomeChromeGesture = false;

  @override
  void didUpdateWidget(covariant FilterCapsulePanel<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.expanded) _endHomeChromeGestureBlock();
  }

  @override
  void dispose() {
    _endHomeChromeGestureBlock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRect(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: widget.expanded
            ? Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Listener(
                  onPointerDown: (_) => _beginHomeChromeGestureBlock(),
                  onPointerUp: (_) => _endHomeChromeGestureBlock(),
                  onPointerCancel: (_) => _endHomeChromeGestureBlock(),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) =>
                        notification.metrics.axis == Axis.vertical,
                    child: Material(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.62,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: widget.maxHeight,
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(10),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final option in widget.options)
                                  FilterCapsuleChip(
                                    label: option.label,
                                    selected:
                                        option.value == widget.selectedValue,
                                    showCheck: true,
                                    onTap: () =>
                                        widget.onSelected(option.value),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : const SizedBox(width: double.infinity),
      ),
    );
  }

  void _beginHomeChromeGestureBlock() {
    if (_blockingHomeChromeGesture ||
        !widget.expanded ||
        !Get.isRegistered<HomeController>()) {
      return;
    }
    Get.find<HomeController>().beginHomeChromeGestureBlock();
    _blockingHomeChromeGesture = true;
  }

  void _endHomeChromeGestureBlock() {
    if (!_blockingHomeChromeGesture) return;
    if (Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().endHomeChromeGestureBlock();
    }
    _blockingHomeChromeGesture = false;
  }
}

class FilterCapsuleChip extends StatelessWidget {
  const FilterCapsuleChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.showCheck = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool showCheck;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 32,
      child: ActionChip(
        avatar: showCheck && selected
            ? const Icon(Icons.check, size: 18)
            : null,
        label: Text(label),
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        backgroundColor: selected
            ? scheme.primaryContainer.withValues(alpha: 0.92)
            : scheme.surface.withValues(alpha: 0.82),
        side: BorderSide(
          color: selected
              ? scheme.primary.withValues(alpha: 0.38)
              : scheme.outlineVariant.withValues(alpha: 0.5),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class FilterCapsuleArrow extends StatelessWidget {
  const FilterCapsuleArrow({
    super.key,
    required this.foreground,
    required this.background,
    required this.expanded,
    required this.onTap,
    this.tooltip,
  });

  final Color foreground;
  final Color background;
  final bool expanded;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: SizedBox(
        width: 42,
        height: double.infinity,
        child: Material(
          color: background,
          borderRadius: const BorderRadius.horizontal(
            right: Radius.circular(18),
          ),
          child: InkWell(
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(18),
            ),
            onTap: onTap,
            child: AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 26,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
