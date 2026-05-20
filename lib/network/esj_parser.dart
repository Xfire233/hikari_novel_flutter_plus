import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:hikari_novel_flutter/models/bookshelf.dart';
import 'package:hikari_novel_flutter/models/cat_chapter.dart';
import 'package:hikari_novel_flutter/models/cat_volume.dart';
import 'package:hikari_novel_flutter/models/content.dart';
import 'package:hikari_novel_flutter/models/novel_cover.dart';
import 'package:hikari_novel_flutter/models/novel_detail.dart';
import 'package:hikari_novel_flutter/models/source_id.dart';

import 'esj_api.dart';

class EsjReadHistory {
  const EsjReadHistory({
    required this.aid,
    required this.cid,
    required this.title,
  });

  final String aid;
  final String cid;
  final String title;
}

class EsjParser {
  static String accountName(String html) {
    final document = parse(html);
    final candidates = <String>[
      for (final selector in [
        '.dropdown-menu a[href*="/my"]',
        'a[href*="/my"]',
        '.navbar .dropdown-toggle',
        '.navbar-nav .nav-link',
      ])
        ...document.querySelectorAll(selector).map((item) => item.text),
    ];
    for (final raw in candidates) {
      final text = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (text.isEmpty) continue;
      if (text.contains('登入') ||
          text.contains('登录') ||
          text.contains('收藏') ||
          text.contains('觀看') ||
          text.contains('观看')) {
        continue;
      }
      if (text.length <= 32) return text;
    }
    return '';
  }

  static List<NovelCover> getSearchResults(String html) {
    final document = parse(html);
    final covers = <NovelCover>[];
    final seen = <String>{};
    final bookCards = document.querySelectorAll(
      '.offcanvas-wrapper .row .row > div',
    );
    final roots = bookCards.isNotEmpty
        ? bookCards
        : document.querySelectorAll('.card-title');
    for (final root in roots) {
      final titleElement = root.classes.contains('card-title')
          ? root
          : root.querySelector('.card-title') ?? root;
      final link = titleElement.localName == 'a'
          ? titleElement
          : titleElement.querySelector('a') ?? _firstLink(titleElement);
      final href = link?.attributes['href'] ?? '';
      final bookId = _bookIdFromHref(href);
      final title = titleElement.text.trim();
      if (bookId == null || title.isEmpty || !seen.add(bookId)) continue;
      final card = root.classes.contains('card-title')
          ? _cardRoot(titleElement)
          : root;
      final image = _imageFrom(card) ?? EsjApi.logoUrl;
      covers.add(NovelCover(title, image, SourceId.esjAid(bookId)));
    }
    return covers;
  }

  static NovelDetail getNovelDetail(String html, String aid) {
    final document = parse(html);
    final root = document.querySelector('.container>.row') ?? document.body;
    final title = _firstText([
      root?.querySelector('h2'),
      root?.querySelector('h1'),
      root?.querySelector('.card-title'),
      document.querySelector('title'),
    ], fallback: 'ESJZone');
    final fields = _detailFields(document);
    final author = _field(fields, ['作者', '作者：', 'Author'], fallback: 'ESJZone');
    final status = _field(fields, ['狀態', '状态', 'Status'], fallback: 'ESJZone');
    final update = _field(fields, [
      '更新日期',
      '最近更新',
      '更新',
      'Update',
    ], fallback: '');
    final image =
        _imageFrom(root?.querySelector('.product-gallery')) ??
        _imageFrom(root) ??
        _imageFrom(document.body) ??
        EsjApi.logoUrl;
    final tags = document
        .querySelectorAll('.widget-tags a')
        .map((e) => e.text.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final intro = _introText(document);
    final detail = NovelDetail(
      title,
      author,
      status,
      update,
      image,
      intro,
      tags,
      '',
      '',
      false,
    );
    detail.catalogue.addAll(getCatalogue(html, SourceId.esjBookId(aid)));
    return detail;
  }

  static List<CatVolume> getCatalogue(String html, String bookId) {
    final document = parse(html);
    final chapterList = document.querySelector('#chapterList');
    if (chapterList == null) return [];
    final volumes = <CatVolume>[];
    var currentTitle = 'ESJZone';
    var chapters = <CatChapter>[];

    void flush() {
      if (chapters.isEmpty) return;
      volumes.add(CatVolume(title: currentTitle, chapters: chapters));
      chapters = <CatChapter>[];
    }

    void addLink(Element link) {
      final chapterId = _chapterIdFromHref(
        link.attributes['href'] ?? '',
        bookId,
      );
      final title = _chapterTitle(link);
      if (chapterId == null || title.isEmpty) return;
      chapters.add(CatChapter(title: title, cid: SourceId.esjCid(chapterId)));
    }

    for (final node in chapterList.children) {
      if (node.localName == 'details') {
        flush();
        currentTitle = _firstText([
          node.querySelector('summary'),
        ], fallback: 'ESJZone');
        for (final link in node.querySelectorAll('a')) {
          addLink(link);
        }
        continue;
      }
      if (_looksLikeVolume(node)) {
        flush();
        currentTitle = node.text.trim().isEmpty ? 'ESJZone' : node.text.trim();
        continue;
      }
      if (node.localName == 'a') {
        addLink(node);
      } else {
        for (final link in node.querySelectorAll('a')) {
          addLink(link);
        }
      }
    }
    flush();
    return volumes;
  }

  static Content getContent(String html) {
    final document = parse(html);
    final content = document.querySelector('.forum-content') ?? document.body;
    if (content == null) return Content(text: '', images: []);
    final images = content
        .querySelectorAll('img')
        .map(_imageUrl)
        .whereType<String>()
        .map(_absoluteUrl)
        .toList();
    final text = _nodeText(
      content,
    ).replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    return Content(text: text, images: images);
  }

  static List<BookshelfNovelInfo> getFavoritePage(String html) {
    final document = parse(html);
    final items = <BookshelfNovelInfo>[];
    final seen = <String>{};
    for (final root in [
      ...document.querySelectorAll('.table-responsive .product-info'),
      ...document.querySelectorAll('.card-title'),
    ]) {
      final titleElement =
          root.querySelector('.product-title') ??
          (root.classes.contains('card-title')
              ? root
              : root.querySelector('.card-title')) ??
          root;
      final link =
          titleElement.querySelector('a[href*=detail]') ??
          (titleElement.localName == 'a' ? titleElement : null) ??
          _firstLink(titleElement);
      final href = link?.attributes['href'] ?? '';
      final bookId = _bookIdFromHref(href);
      final title = titleElement.text.trim();
      if (bookId == null || title.isEmpty || !seen.add(bookId)) continue;
      final aid = SourceId.esjAid(bookId);
      final card = root.classes.contains('product-info')
          ? root
          : _cardRoot(titleElement);
      final updateKey = _favoriteUpdateKey(card, href);
      items.add(
        BookshelfNovelInfo(
          bid: aid,
          aid: aid,
          url: EsjApi.detailUrl(bookId),
          title: title,
          img: _imageFrom(card) ?? EsjApi.logoUrl,
          updateKey: updateKey,
          remoteTags: const ['ESJZone'],
        ),
      );
    }
    return items;
  }

  static List<EsjReadHistory> getViewHistory(String html) {
    final document = parse(html);
    final items = <EsjReadHistory>[];
    final seen = <String>{};
    for (final row in document.querySelectorAll('.table-responsive tr')) {
      final detailLink =
          row.querySelector('.product-title a[href*=detail]') ??
          row.querySelector('a[href*=detail]');
      final chapterLink =
          row.querySelector('.book-ep a[href*=forum]') ??
          row.querySelector('a[href*=forum]');
      final bookId = _bookIdFromHref(detailLink?.attributes['href'] ?? '');
      final chapterId = _chapterIdFromHref(
        chapterLink?.attributes['href'] ?? '',
        bookId ?? '',
      );
      final title = (row.querySelector('.product-title') ?? detailLink)?.text
          .trim();
      if (bookId == null ||
          chapterId == null ||
          title == null ||
          title.isEmpty) {
        continue;
      }
      final aid = SourceId.esjAid(bookId);
      final cid = SourceId.esjCid(chapterId);
      if (!seen.add('$aid/$cid')) continue;
      items.add(EsjReadHistory(aid: aid, cid: cid, title: title));
    }
    return items;
  }

  static String? latestChapterCid(NovelDetail detail) {
    for (final volume in detail.catalogue.reversed) {
      if (volume.chapters.isNotEmpty) return volume.chapters.last.cid;
    }
    return null;
  }

  static Map<String, String> _detailFields(Document document) {
    final fields = <String, String>{};
    for (final label in document.querySelectorAll('.book-detail label')) {
      final key = label.text.trim().replaceAll(':', '').replaceAll('：', '');
      final parentText = label.parent?.text.trim() ?? '';
      final value = parentText
          .replaceFirst(label.text, '')
          .replaceFirst(':', '')
          .replaceFirst('：', '')
          .trim();
      if (key.isNotEmpty && value.isNotEmpty) fields[key] = value;
    }
    for (final item in document.querySelectorAll('ul.book-detail li')) {
      final text = item.text.trim();
      final parts = text.split(RegExp(r'[:：]'));
      if (parts.length >= 2) {
        fields[parts.first.trim()] = parts.sublist(1).join(':').trim();
      }
    }
    return fields;
  }

  static String _field(
    Map<String, String> fields,
    List<String> names, {
    required String fallback,
  }) {
    for (final name in names) {
      final normalized = name.replaceAll(':', '').replaceAll('：', '');
      final value = fields[normalized];
      if (value != null && value.isNotEmpty) return value;
    }
    return fallback;
  }

  static String _introText(Document document) {
    final candidates = [
      document.querySelector('.description'),
      document.querySelector('.book-intro'),
      document.querySelector('.card-text'),
    ];
    for (final candidate in candidates) {
      final text = candidate?.text.trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    final row = document.querySelector('.container>.row');
    if (row == null) return '';
    final paragraphs = row
        .querySelectorAll('p')
        .map((e) => e.text.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return paragraphs.join('\n\n');
  }

  static String _firstText(
    List<Element?> elements, {
    required String fallback,
  }) {
    for (final element in elements) {
      final text = element?.text.trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  static Element? _firstLink(Element element) {
    var current = element.parent;
    while (current != null) {
      final link = current.querySelector('a[href*=detail]');
      if (link != null) return link;
      current = current.parent;
    }
    return null;
  }

  static Element? _cardRoot(Element element) {
    var current = element;
    while (current.parent != null) {
      if (current.classes.any((className) => className.contains('card'))) {
        return current;
      }
      current = current.parent!;
    }
    return element.parent;
  }

  static String? _bookIdFromHref(String href) =>
      RegExp(r'/detail/(\d+)\.html').firstMatch(href)?.group(1) ??
      RegExp(r'detail/(\d+)').firstMatch(href)?.group(1);

  static String? _chapterIdFromHref(String href, String bookId) =>
      RegExp('/forum/$bookId/(\\d+)\\.html').firstMatch(href)?.group(1) ??
      RegExp(r'/forum/\d+/(\d+)\.html').firstMatch(href)?.group(1) ??
      RegExp(r'/(\d+)\.html').firstMatch(href)?.group(1);

  static String _chapterTitle(Element link) {
    final dataTitle = link.attributes['data-title']?.trim() ?? '';
    if (dataTitle.isNotEmpty) return dataTitle;
    return link.text.trim();
  }

  static bool _looksLikeVolume(Element element) {
    if (element.querySelector('a') != null) return false;
    final name = element.localName ?? '';
    return name.startsWith('h') ||
        element.classes.any((className) => className.contains('volume'));
  }

  static String? _imageFrom(Element? root) {
    if (root == null) return null;
    final image = root.querySelector('.lazyload') ?? root.querySelector('img');
    return _imageUrl(image);
  }

  static String? _imageUrl(Element? image) {
    if (image == null) return null;
    final raw =
        image.attributes['data-src'] ??
        image.attributes['data-lazy-src'] ??
        image.attributes['data-original'] ??
        image.attributes['data-url'] ??
        image.attributes['src'];
    if (raw == null) return null;
    final trimmed = raw.trim().replaceAll('&amp;', '&');
    if (trimmed.isEmpty || trimmed.startsWith('data:')) return null;
    return _normalizeImageUrl(trimmed);
  }

  static String _absoluteUrl(String url) {
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('/')) return '${EsjApi.baseUrl}$url';
    return url;
  }

  static String? _normalizeImageUrl(String raw) {
    final absolute = _absoluteUrl(raw);
    final encoded = Uri.encodeFull(absolute);
    final uri = Uri.tryParse(encoded);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return uri.toString();
  }

  static String _favoriteUpdateKey(Element? card, String href) {
    final text = card?.text.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
    return text.isEmpty ? href : '$href|$text';
  }

  static String _nodeText(Node node) {
    if (node is Text) return node.text;
    if (node is! Element) return '';
    final name = node.localName;
    if (name == 'script' || name == 'style') return '';
    if (name == 'br') return '\n';
    if (name == 'img') return '';
    final buffer = StringBuffer();
    for (final child in node.nodes) {
      buffer.write(_nodeText(child));
    }
    if (name == 'p' || name == 'div' || name == 'li') buffer.write('\n');
    return buffer.toString();
  }
}
