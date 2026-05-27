import 'package:flutter/material.dart';
import 'package:hikari_novel_flutter/common/constants.dart';
import 'package:hikari_novel_flutter/models/recommend_block.dart';
import 'package:hikari_novel_flutter/widgets/novel_cover_card.dart';
import 'package:responsive_grid_list/responsive_grid_list.dart';

class RecommendBlockView extends StatelessWidget {
  const RecommendBlockView({super.key, required this.block});

  final RecommendBlock block;

  @override
  Widget build(BuildContext context) {
    if (block.list.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(kCardBorderRadius),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.10)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                block.title,
                textAlign: TextAlign.start,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              ResponsiveGridList(
                listViewBuilderOptions: ListViewBuilderOptions(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                ),
                minItemWidth: 100,
                horizontalGridSpacing: 4,
                verticalGridSpacing: 4,
                children: block.list.map((item) {
                  return NovelCoverCard(novelCover: item);
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
