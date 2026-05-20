import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hikari_novel_flutter/models/source_config.dart';

class SourceBackdrop extends StatelessWidget {
  const SourceBackdrop({super.key, required this.source, required this.child});

  final NovelSource source;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = SourceBackdropPalette.of(context, source);
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.backgroundStart,
            scheme.surface,
            palette.backgroundEnd,
          ],
          stops: const [0, 0.46, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.64, 0.64),
                    radius: 0.78,
                    colors: [
                      palette.mark.withValues(alpha: palette.washOpacity),
                      palette.mark.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(child: _SourceBackdropMarks(palette: palette)),
          ),
          child,
        ],
      ),
    );
  }
}

class SourceSurface extends StatelessWidget {
  const SourceSurface({super.key, required this.child, this.opacity = 0.82});

  final Widget child;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: opacity),
      child: child,
    );
  }
}

class SourceMark extends StatelessWidget {
  const SourceMark({
    super.key,
    required this.source,
    this.size = 24,
    this.color,
    this.opacity = 0.9,
  });

  final NovelSource source;
  final double size;
  final Color? color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final markColor = color ?? SourceBackdropPalette.of(context, source).mark;
    final resolvedColor = markColor.withValues(alpha: opacity);
    final icon = SvgPicture.asset(
      _sourceMarkAsset(source),
      colorFilter: ColorFilter.mode(resolvedColor, BlendMode.srcIn),
      fit: BoxFit.contain,
    );

    return SizedBox.square(dimension: size, child: icon);
  }
}

class SourceBackdropPalette {
  const SourceBackdropPalette({
    required this.source,
    required this.backgroundStart,
    required this.backgroundEnd,
    required this.mark,
    required this.primaryOpacity,
    required this.secondaryOpacity,
    required this.washOpacity,
  });

  final NovelSource source;
  final Color backgroundStart;
  final Color backgroundEnd;
  final Color mark;
  final double primaryOpacity;
  final double secondaryOpacity;
  final double washOpacity;

  static SourceBackdropPalette of(BuildContext context, NovelSource source) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final base = switch (source) {
      NovelSource.wenku8 => const Color(0xFFC7834F),
      NovelSource.esj => const Color(0xFF9F4F5B),
      NovelSource.yamibo => const Color(0xFF7E6B92),
    };
    final themedBase = Color.lerp(scheme.primary, base, isDark ? 0.34 : 0.42)!;
    final desaturated = Color.lerp(
      themedBase,
      scheme.surface,
      isDark ? 0.44 : 0.56,
    )!;
    final mark = Color.lerp(
      themedBase,
      isDark ? scheme.onSurface : scheme.primary,
      isDark ? 0.18 : 0.18,
    )!;
    return SourceBackdropPalette(
      source: source,
      backgroundStart: Color.lerp(
        scheme.surface,
        desaturated,
        isDark ? 0.16 : 0.22,
      )!,
      backgroundEnd: Color.lerp(
        scheme.surface,
        desaturated,
        isDark ? 0.1 : 0.15,
      )!,
      mark: mark,
      primaryOpacity: isDark ? 0.12 : 0.105,
      secondaryOpacity: isDark ? 0.055 : 0.05,
      washOpacity: isDark ? 0.18 : 0.16,
    );
  }
}

class _SourceBackdropMarks extends StatelessWidget {
  const _SourceBackdropMarks({required this.palette});

  final SourceBackdropPalette palette;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 0.0;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 0.0;
        final shortSide = math.min(width, height);
        final large = shortSide * 0.58;
        final small = shortSide * 0.32;

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              right: -large * 0.14,
              bottom: -large * 0.12,
              width: large,
              height: large,
              child: Transform.rotate(
                angle: -0.08,
                child: SourceMark(
                  source: palette.source,
                  size: large,
                  color: palette.mark,
                  opacity: palette.primaryOpacity,
                ),
              ),
            ),
            Positioned(
              left: width * 0.06,
              top: height * 0.14,
              width: small,
              height: small,
              child: Transform.flip(
                flipX: true,
                child: Transform.rotate(
                  angle: 0.08,
                  child: SourceMark(
                    source: palette.source,
                    size: small,
                    color: palette.mark,
                    opacity: palette.secondaryOpacity,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

String _sourceMarkAsset(NovelSource source) => switch (source) {
  NovelSource.wenku8 => 'assets/images/source/wenku8.svg',
  NovelSource.esj => 'assets/images/source/esj.svg',
  NovelSource.yamibo => 'assets/images/source/yamibo.svg',
};
