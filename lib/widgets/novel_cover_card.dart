import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/common/constants.dart';
import 'package:hikari_novel_flutter/models/bookshelf.dart';
import 'package:hikari_novel_flutter/models/novel_cover.dart';
import 'package:hikari_novel_flutter/models/source_config.dart';
import 'package:hikari_novel_flutter/network/request.dart';
import 'package:hikari_novel_flutter/router/app_sub_router.dart';
import 'package:hikari_novel_flutter/service/source_favorite_adapter.dart';
import 'package:hikari_novel_flutter/widgets/local_rating_bar.dart';
import 'package:hikari_novel_flutter/widgets/source_backdrop.dart';

class NovelCoverCard extends StatelessWidget {
  final NovelCover novelCover;

  const NovelCoverCard({super.key, required this.novelCover});

  @override
  Widget build(BuildContext context) {
    final imageUrl = novelCover.imageUrl?.trim();
    return RepaintBoundary(
      child: InkWell(
        borderRadius: BorderRadius.circular(kCardBorderRadius),
        onTap: () =>
            AppSubRouter.toNovelDetail(aid: novelCover.aid, cover: novelCover),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kCardBorderRadius),
          ),
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 9 / 13.5,
                child: _CoverImage(
                  imageUrl: imageUrl,
                  title: novelCover.title,
                  source: SourceFavoriteAdapter.sourceOfAid(novelCover.aid),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter, // 渐变到图片一半
                      colors: [
                        Colors.black.withValues(alpha: 0),
                        Colors.black.withValues(alpha: 1),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                alignment: Alignment.bottomLeft,
                width: double.infinity, //充满父组件宽度
                child: Padding(
                  padding: EdgeInsets.all(6),
                  child: Text(
                    novelCover.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.start,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BookshelfCoverCard extends StatelessWidget {
  final BookshelfNovelInfo bookshelfNovelInfo;
  final Function() onTap;
  final Function() onLongPress;
  final ValueChanged<double>? onRatingChanged;

  const BookshelfCoverCard({
    super.key,
    required this.bookshelfNovelInfo,
    required this.onTap,
    required this.onLongPress,
    this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kCardBorderRadius),
              ),
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 9 / 13.5,
                    child: _CoverImage(
                      imageUrl: bookshelfNovelInfo.img,
                      title: bookshelfNovelInfo.title,
                      source: SourceFavoriteAdapter.sourceOfAid(
                        bookshelfNovelInfo.aid,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.center,
                          end: Alignment.bottomCenter, // 渐变到图片一半
                          colors: [
                            Colors.black.withValues(alpha: 0),
                            Colors.black.withValues(alpha: 1),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 6,
                    right: 6,
                    bottom: 30,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.50),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          child: LocalRatingBar(
                            rating: bookshelfNovelInfo.rating,
                            onChanged: onRatingChanged,
                            size: 14,
                            showValue: false,
                            compact: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    alignment: Alignment.bottomLeft,
                    width: double.infinity, //充满父组件宽度
                    child: Padding(
                      padding: EdgeInsets.all(6),
                      child: Text(
                        bookshelfNovelInfo.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.start,
                        style: TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (bookshelfNovelInfo.hasUpdate ||
                bookshelfNovelInfo.isReadComplete)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: bookshelfNovelInfo.hasUpdate
                        ? colorScheme.primary
                        : colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    bookshelfNovelInfo.hasUpdate
                        ? "updated".tr
                        : "read_complete".tr,
                    style: TextStyle(
                      color: bookshelfNovelInfo.hasUpdate
                          ? colorScheme.onPrimary
                          : colorScheme.onSecondaryContainer,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            Obx(
              () => Offstage(
                offstage: !bookshelfNovelInfo.isSelected.value,
                child: Container(
                  decoration: ShapeDecoration(
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(kCardBorderRadius),
                      side: BorderSide(color: colorScheme.primary, width: 5),
                    ),
                    color: Colors.grey.withAlpha(128),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({
    required this.imageUrl,
    required this.title,
    required this.source,
  });

  final String? imageUrl;
  final String title;
  final NovelSource source;

  @override
  Widget build(BuildContext context) {
    if (source == NovelSource.yamibo) {
      return _CoverPlaceholder(title: title, source: source);
    }
    final url = imageUrl?.trim() ?? '';
    if (!_isUsableNetworkUrl(url) || _isPlaceholderOnlyUrl(url)) {
      return _CoverPlaceholder(title: title, source: source);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final width = constraints.maxWidth.isFinite
            ? (constraints.maxWidth * dpr).round().clamp(1, 1600)
            : null;
        final height = constraints.maxHeight.isFinite
            ? (constraints.maxHeight * dpr).round().clamp(1, 2400)
            : null;
        return CachedNetworkImage(
          imageUrl: url,
          httpHeaders: Request.userAgent,
          fit: BoxFit.cover,
          memCacheWidth: width,
          memCacheHeight: height,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          placeholderFadeInDuration: Duration.zero,
          progressIndicatorBuilder: (context, url, downloadProgress) => Center(
            child: CircularProgressIndicator(value: downloadProgress.progress),
          ),
          errorWidget: (context, url, error) =>
              _CoverPlaceholder(title: title, source: source),
        );
      },
    );
  }

  bool _isPlaceholderOnlyUrl(String url) {
    if (source != NovelSource.yamibo) return false;
    final lower = url.toLowerCase();
    return lower.contains('/static/image/common/logo') ||
        lower.contains('discuz') ||
        lower.contains('community');
  }

  bool _isUsableNetworkUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.title, required this.source});

  final String title;
  final NovelSource source;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = SourceBackdropPalette.of(context, source);
    return ColoredBox(
      color: Color.lerp(
        colorScheme.surfaceContainerHighest,
        palette.backgroundStart,
        0.5,
      )!,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -18,
            bottom: -12,
            child: SourceMark(
              source: source,
              size: 96,
              color: palette.mark,
              opacity: 0.16,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Center(
              child: Text(
                title,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
