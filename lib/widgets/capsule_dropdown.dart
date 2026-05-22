import 'package:flutter/material.dart';

class CapsuleDropdown<T> extends StatelessWidget {
  const CapsuleDropdown({
    super.key,
    required this.label,
    required this.items,
    required this.onSelected,
    this.width,
    this.emphasized = false,
    this.tooltip,
  });

  final String label;
  final List<PopupMenuEntry<T>> items;
  final ValueChanged<T> onSelected;
  final double? width;
  final bool emphasized;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = emphasized
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;
    final background = emphasized
        ? scheme.secondaryContainer.withValues(alpha: 0.86)
        : scheme.surface.withValues(alpha: 0.72);
    final arrowBackground = emphasized
        ? scheme.secondaryContainer.withValues(alpha: 0.1)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.45);

    final button = Builder(
      builder: (buttonContext) => Material(
        color: background,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showMenu(buttonContext),
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
              Tooltip(
                message: tooltip ?? label,
                child: Material(
                  color: arrowBackground,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(18),
                  ),
                  child: InkWell(
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(18),
                    ),
                    onTap: () => _showMenu(buttonContext),
                    child: SizedBox(
                      width: 42,
                      height: double.infinity,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 26,
                        color: foreground,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return SizedBox(width: width, height: 52, child: button);
  }

  void _showMenu(BuildContext context) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final box = context.findRenderObject() as RenderBox?;
    final topLeft = box?.localToGlobal(Offset.zero, ancestor: overlay);
    final size = box?.size ?? Size.zero;
    final position = topLeft == null
        ? RelativeRect.fill
        : RelativeRect.fromRect(topLeft & size, Offset.zero & overlay.size);
    showMenu<T>(context: context, position: position, items: items).then((
      value,
    ) {
      if (value != null) onSelected(value);
    });
  }
}
