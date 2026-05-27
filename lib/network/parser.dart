import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/book_tags.dart';
import 'package:hikari_novel_flutter/models/common/wenku8_node.dart';
import 'package:hikari_novel_flutter/models/novel_detail.dart';
import 'package:hikari_novel_flutter/models/recommend_block.dart';
import 'package:hikari_novel_flutter/models/reply_item.dart';
import 'package:hikari_novel_flutter/network/api.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';

import 'image_url_helper.dart';

import '../common/log.dart';
import '../common/util.dart';
import '../models/bookshelf.dart';
import '../models/cat_chapter.dart';
import '../models/cat_volume.dart';
import '../models/comment_item.dart';
import '../models/content.dart';
import '../models/novel_cover.dart';
import '../models/user_info.dart';

///此部分的代码基本都是沿用之前的逻辑，然后用AI转化了下
class Parser {
  static List<NovelCover> parseToList(String htmlContent) {
    final node = _currentWenku8Host();
    final List<NovelCover> result = [];
    final Document document = parse(htmlContent);

    final Element? contentElement =
        document.getElementById("content") ?? document.querySelector('body');
    if (contentElement == null) {
      return result;
    }
    final List<Element> bookItems = contentElement
        .querySelectorAll('div')
        .where(_isWenku8ListBookItem)
        .toList(growable: false);

    for (final Element novelItem in bookItems) {
      try {
        final Element? imgElement = novelItem.querySelector("img");
        String img = imgElement?.attributes['src'] ?? '';
        img = ImageUrlHelper.normalize(img);

        final matchingLinks = novelItem
            .querySelectorAll("a")
            .where((element) {
              final href = element.attributes['href'] ?? '';
              return href.contains('/book/') ||
                  href.startsWith('book/') ||
                  href.contains('articleinfo.php');
            })
            .toList(growable: false);
        final Element? titleLinkElement =
            matchingLinks.firstWhereOrNull(_hasVisibleTitle) ??
            (matchingLinks.isEmpty ? null : matchingLinks.first);
        final String title =
            titleLinkElement?.attributes['title']?.trim().isNotEmpty == true
            ? titleLinkElement!.attributes['title']!.trim()
            : titleLinkElement?.text.trim() ?? "";

        final String href = titleLinkElement?.attributes['href'] ?? '';
        final String detailUrl = href.isEmpty
            ? ''
            : href.startsWith('http')
            ? href
            : href.startsWith('/')
            ? "https://$node$href"
            : "https://$node/$href";

        if (detailUrl.isEmpty) {
          continue;
        }

        if (img == "/images/noimg.jpg") {
          img = "https://$node/modules/article/images/nocover.jpg";
        } else if (img.isEmpty) {
          img = "https://$node/modules/article/images/nocover.jpg";
        }

        String aid = "";

        final bookIndex = detailUrl.indexOf("book/");
        final htmIndex = detailUrl.indexOf(".htm");
        if (bookIndex != -1 && htmIndex != -1 && htmIndex > bookIndex + 5) {
          aid = detailUrl.substring(bookIndex + 5, htmIndex);
        } else {
          aid =
              Uri.tryParse(detailUrl)?.queryParameters['id'] ??
              Uri.tryParse(detailUrl)?.queryParameters['aid'] ??
              Uri.tryParse(detailUrl)?.queryParameters['bid'] ??
              '';
        }

        if (title != "" && detailUrl.isNotEmpty) {
          result.add(NovelCover(title, img, aid));
        } else {}
      } catch (e, stackTrace) {
        Log.e(stackTrace);
      }
    }

    return result;
  }

  static String _currentWenku8Host() {
    try {
      return Api.wenku8Node.node.replaceFirst(RegExp(r'^https?://'), '');
    } catch (_) {
      return Wenku8Node.wwwWenku8Cc.node.replaceFirst(
        RegExp(r'^https?://'),
        '',
      );
    }
  }

  static bool _isWenku8ListBookItem(Element element) {
    final style = (element.attributes['style'] ?? '').toLowerCase().replaceAll(
      ' ',
      '',
    );
    final isWideListCard =
        style.contains('width:373px') && style.contains('height:136px');
    final isCompactListCard =
        style.contains('width:95px') && style.contains('height:155px');
    if (!isWideListCard && !isCompactListCard) {
      return false;
    }
    return element.querySelector('img') != null &&
        element.querySelectorAll('a').any((link) {
          final href = link.attributes['href'] ?? '';
          return href.contains('/book/') ||
              href.startsWith('book/') ||
              href.contains('articleinfo.php');
        });
  }

  static bool _hasVisibleTitle(Element element) {
    final title = element.attributes['title']?.trim();
    if (title != null && title.isNotEmpty) return true;
    return element.text.trim().isNotEmpty;
  }

  static List<NovelCover> parseOtherBookshelfToList(String html) {
    final List<NovelCover> list = [];
    final Document document = parse(html);
    final Element? content = document.getElementById('centerm');
    if (content != null) {
      final List<Element> trElements = content.getElementsByTagName('tr');
      for (int index = 1; index < trElements.length; index++) {
        final Element element = trElements[index];
        final List<Element> anchorElements = element.getElementsByTagName('a');
        if (anchorElements.length >= 2) {
          final String title = anchorElements[0].text.trim();
          final String href = anchorElements[1].attributes['href'] ?? '';
          final String aid = Uri.parse(href).queryParameters['bid'] ?? '';
          list.add(NovelCover(title, null, aid));
        }
      }
    }
    return list;
  }

  static NovelDetail getNovelDetail(String html) {
    final Document document = parse(html);
    final legacyDetail = _parseWenku8LegacyDetail(document);
    final Element root =
        document.getElementById('content') ??
        document.querySelector('body') ??
        document.documentElement!;

    final String title = _extractWenku8DetailTitle(document, root);
    final String author = _wenku8FieldValue(root, _wenku8AuthorLabels);
    final String status = _wenku8FieldValue(root, _wenku8StatusLabels);
    final String updateValue = _wenku8FieldValue(root, _wenku8UpdateLabels);
    final String finUpdate = _formatWenku8Update(updateValue);
    String imgUrl = root.querySelector('img')?.attributes['src'] ?? '';
    imgUrl = ImageUrlHelper.normalize(imgUrl);
    final introduce = _extractWenku8Introduce(root);
    final tags = BookTags.normalize([
      ..._extractWenku8Tags(document, root),
      ...BookTags.statusTags(status, finUpdate),
    ]);
    final heatValue = _wenku8FieldValue(root, _wenku8HeatLabels);
    final heat = heatValue.isEmpty ? '' : "heat".tr + heatValue;
    final trending = '';
    final isAnimated =
        root.querySelector('img[src*="anime"], img[src*="animated"]') != null ||
        root.text.toLowerCase().contains('animated');

    final flexibleDetail = NovelDetail(
      title,
      author,
      status,
      finUpdate,
      imgUrl,
      introduce,
      tags,
      heat,
      trending,
      isAnimated,
    );
    if (legacyDetail != null && _hasUsefulWenku8Detail(legacyDetail)) {
      return _mergeWenku8ParsedDetail(legacyDetail, flexibleDetail);
    }
    return flexibleDetail;
  }

  static NovelDetail _mergeWenku8ParsedDetail(
    NovelDetail primary,
    NovelDetail fallback,
  ) {
    return NovelDetail(
      _preferNonEmpty(primary.title, fallback.title),
      _preferNonEmpty(primary.author, fallback.author),
      _preferNonEmpty(primary.status, fallback.status),
      _preferNonEmpty(primary.finUpdate, fallback.finUpdate),
      _preferNonEmpty(primary.imgUrl, fallback.imgUrl),
      _preferNonEmpty(primary.introduce, fallback.introduce),
      BookTags.merge(primary.tags, fallback.tags),
      _preferNonEmpty(primary.heat, fallback.heat),
      _preferNonEmpty(primary.trending, fallback.trending),
      primary.isAnimated || fallback.isAnimated,
    );
  }

  static String _preferNonEmpty(String primary, String fallback) {
    final value = primary.trim();
    return value.isNotEmpty ? primary : fallback;
  }

  static NovelDetail? _parseWenku8LegacyDetail(Document document) {
    try {
      final Element? content = document.getElementById('content');
      if (content == null) return null;
      final tables = content.getElementsByTagName('table');
      if (tables.length < 3) return null;

      final headerTable = tables[0];
      final String title = _extractWenku8DetailTitle(document, headerTable);
      final rows = headerTable.getElementsByTagName('tr');
      final infoCells = rows.length > 2
          ? rows[2].getElementsByTagName('td')
          : const <Element>[];
      final String author = infoCells.length > 1
          ? _stripWenku8FieldPrefix(infoCells[1].text, _wenku8AuthorLabels)
          : '';
      final String status = infoCells.length > 2
          ? _stripWenku8FieldPrefix(infoCells[2].text, _wenku8StatusLabels)
          : '';
      final String updateValue = infoCells.length > 3
          ? _stripWenku8FieldPrefix(infoCells[3].text, _wenku8UpdateLabels)
          : '';
      final String finUpdate = _formatWenku8Update(updateValue);

      String imgUrl = content.getElementsByTagName('img').isNotEmpty
          ? content.getElementsByTagName('img')[0].attributes['src'] ?? ''
          : '';
      imgUrl = ImageUrlHelper.normalize(imgUrl);

      final detailTable = tables[2];
      final detailCells = detailTable.getElementsByTagName('td');
      final rightCell = detailCells.length > 1 ? detailCells[1] : detailTable;
      final spans = rightCell.getElementsByTagName('span');
      final tagText = spans.isNotEmpty ? spans[0].text : '';
      final heatText = spans.length > 1 ? spans[1].text : '';
      final introduce = spans.length > 5
          ? _cleanWenku8IntroduceHtml(spans[5].innerHtml)
          : _extractWenku8Introduce(rightCell);
      final isAnimated =
          detailCells.isNotEmpty &&
          detailCells[0].getElementsByTagName('span').isNotEmpty;
      final tags = BookTags.normalize([
        ..._extractWenku8TagsFromLabelText(tagText),
        ...BookTags.statusTags(status, finUpdate),
      ]);

      final heatValue = _stripWenku8FieldPrefix(heatText, _wenku8HeatLabels);
      final heat = heatValue.isEmpty ? '' : "heat".tr + heatValue;
      final trending = _extractWenku8Trending(heatText);

      return NovelDetail(
        title,
        author,
        status,
        finUpdate,
        imgUrl,
        introduce,
        tags,
        heat,
        trending,
        isAnimated,
      );
    } catch (_) {
      return null;
    }
  }

  static bool _hasUsefulWenku8Detail(NovelDetail detail) =>
      detail.title.trim().isNotEmpty ||
      detail.author.trim().isNotEmpty ||
      detail.status.trim().isNotEmpty ||
      detail.introduce.trim().isNotEmpty ||
      detail.tags.isNotEmpty;

  static const _wenku8AuthorLabels = [
    '\u5c0f\u8bf4\u4f5c\u8005',
    '\u6587\u7ae0\u4f5c\u8005',
    '\u4f5c\u8005',
    '\u5c0f\u8aaa\u4f5c\u8005',
    '\u6587\u7ae0\u4f5c\u8005',
  ];
  static const _wenku8StatusLabels = [
    '\u5199\u4f5c\u8fdb\u7a0b',
    '\u6587\u7ae0\u72b6\u6001',
    '\u5c0f\u8bf4\u72b6\u6001',
    '\u72b6\u6001',
    '\u5beb\u4f5c\u9032\u7a0b',
    '\u6587\u7ae0\u72c0\u614b',
    '\u5c0f\u8aaa\u72c0\u614b',
    '\u72c0\u614b',
  ];
  static const _wenku8UpdateLabels = [
    '\u6700\u540e\u66f4\u65b0',
    '\u66f4\u65b0\u65f6\u95f4',
    '\u66f4\u65b0\u65e5\u671f',
    '\u6700\u5f8c\u66f4\u65b0',
    '\u66f4\u65b0\u6642\u9593',
  ];
  static const _wenku8TagLabels = [
    '\u5c0f\u8bf4Tags',
    '\u5c0f\u8bf4\u6807\u7b7e',
    '\u5c0f\u8bf4\u6a19\u7c64',
    '\u6807\u7b7e',
    '\u6a19\u7c64',
    'Tags',
  ];
  static const _wenku8CategoryLabels = [
    '\u5c0f\u8bf4\u7c7b\u522b',
    '\u6587\u7ae0\u7c7b\u522b',
    '\u7c7b\u522b',
    '\u5c0f\u8aaa\u985e\u5225',
    '\u6587\u7ae0\u985e\u5225',
    '\u985e\u5225',
  ];
  static const _wenku8HeatLabels = [
    '\u603b\u70b9\u51fb',
    '\u70b9\u51fb',
    '\u70ed\u5ea6',
    '\u7e3d\u9ede\u64ca',
    '\u9ede\u64ca',
    '\u71b1\u5ea6',
  ];
  static const _wenku8FieldBoundaryLabels = [
    ..._wenku8AuthorLabels,
    ..._wenku8StatusLabels,
    ..._wenku8UpdateLabels,
    ..._wenku8TagLabels,
    ..._wenku8CategoryLabels,
    ..._wenku8HeatLabels,
    '\u5c0f\u8bf4\u6027\u8d28',
    '\u5c0f\u8aaa\u6027\u8cea',
    '\u5b8c\u6210\u5b57\u6570',
    '\u6388\u6743\u72b6\u6001',
    '\u6388\u6b0a\u72c0\u614b',
    '\u603b\u63a8\u8350',
    '\u7e3d\u63a8\u85a6',
    '\u6708\u70b9\u51fb',
    '\u5468\u70b9\u51fb',
    '\u65e5\u70b9\u51fb',
  ];

  static String _extractWenku8DetailTitle(Document document, Element root) {
    final direct =
        root.querySelector('span > b')?.text.trim() ??
        root.querySelector('h1')?.text.trim() ??
        root.querySelector('h2')?.text.trim() ??
        '';
    if (direct.isNotEmpty) return direct;
    final pageTitle = document.querySelector('title')?.text.trim() ?? '';
    return pageTitle
        .split(RegExp(r'\s[-_]\s|\s-\s|_'))
        .first
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _wenku8FieldValue(Element root, List<String> labels) {
    final candidates = <String>[
      ...root
          .querySelectorAll('span, td, div, p, li')
          .map((element) => element.text),
      root.text,
    ];
    for (final candidate in candidates) {
      final text = candidate.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (text.isEmpty) continue;
      for (final label in labels) {
        final index = text.toLowerCase().indexOf(label.toLowerCase());
        if (index < 0) continue;
        var raw = text.substring(index + label.length);
        var end = raw.length;
        for (final boundary in _wenku8FieldBoundaryLabels) {
          if (boundary == label) continue;
          final boundaryIndex = raw.toLowerCase().indexOf(
            boundary.toLowerCase(),
          );
          if (boundaryIndex > 0 && boundaryIndex < end) end = boundaryIndex;
        }
        raw = raw.substring(0, end);
        final value = _cleanWenku8FieldValue(raw);
        if (value.isNotEmpty) return value;
      }
    }
    return '';
  }

  static String _cleanWenku8FieldValue(String value) => value
      .replaceAll(RegExp('^[\\s:\uFF1A]+'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _stripWenku8FieldPrefix(String value, List<String> labels) {
    var text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    for (final label in labels) {
      final index = text.toLowerCase().indexOf(label.toLowerCase());
      if (index < 0) continue;
      text = text.substring(index + label.length);
      break;
    }
    return _cleanWenku8FieldValue(text);
  }

  static String _formatWenku8Update(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return '';
    final date = RegExp(r'\d{4}-\d{1,2}-\d{1,2}').firstMatch(clean)?.group(0);
    if (date == null) return clean;
    try {
      return '${Util.getDateTime(date)}${"update".tr}'.trim();
    } catch (_) {
      return '$date${"update".tr}'.trim();
    }
  }

  static List<String> _extractWenku8Tags(Document document, Element root) {
    final legacyTags = root
        .getElementsByTagName('span')
        .expand((element) => _extractWenku8TagsFromLabelText(element.text));
    final labelTags = _splitWenku8Tags(
      _wenku8FieldValue(root, _wenku8TagLabels),
    );
    // Query inside #content only — the site-wide nav also contains a
    // tags.php link ("Tags云集") that is not a book tag.
    final linkedTags = root
        .querySelectorAll('a[href*="tags.php"]')
        .map((element) => element.text.trim())
        .where((text) => text.isNotEmpty);
    final category = _wenku8FieldValue(root, _wenku8CategoryLabels);
    return BookTags.normalize([
      ...legacyTags,
      ...labelTags,
      ...linkedTags,
      if (category.isNotEmpty) category,
    ]);
  }

  static List<String> _extractWenku8TagsFromLabelText(String value) {
    final text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return const [];
    for (final label in _wenku8TagLabels) {
      final index = text.toLowerCase().indexOf(label.toLowerCase());
      if (index < 0) continue;
      return _splitWenku8Tags(
        _cleanWenku8FieldValue(text.substring(index + label.length)),
      );
    }
    return const [];
  }

  static List<String> _splitWenku8Tags(String value) => value
      .split(RegExp('[\\s,\uFF0C\u3001/|;\uFF1B]+'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  static String _extractWenku8Trending(String value) {
    final matches = RegExp(r'\d+').allMatches(value).toList(growable: false);
    if (matches.isEmpty) return '';
    final valueText = matches.last.group(0);
    if (valueText == null || valueText.isEmpty) return '';
    return "increase_rate".tr + valueText;
  }

  static String _extractWenku8Introduce(Element root) {
    final explicit = root
        .querySelector('#intro, #bookintro, .intro')
        ?.innerHtml;
    if (explicit != null && explicit.trim().isNotEmpty) {
      return _cleanWenku8IntroduceHtml(explicit);
    }
    final spans = root.getElementsByTagName('span');
    if (spans.length > 5) {
      final legacy = _cleanWenku8IntroduceHtml(spans[5].innerHtml);
      if (legacy.length >= 8 && !_looksLikeWenku8Metadata(legacy)) {
        return legacy;
      }
    }
    final candidates = root
        .querySelectorAll('p, td, div, span')
        .map((element) => _cleanWenku8IntroduceHtml(element.innerHtml))
        .where((text) => text.length >= 20 && !_looksLikeWenku8Metadata(text))
        .toList(growable: false);
    if (candidates.isEmpty) return '';
    candidates.sort((a, b) => b.length.compareTo(a.length));
    return candidates.first;
  }

  static String _cleanWenku8IntroduceHtml(String html) => html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'[ \t\f\r]+'), ' ')
      .replaceAll(RegExp(r'\n\s+'), '\n')
      .trim();

  static bool _looksLikeWenku8Metadata(String text) =>
      _wenku8FieldBoundaryLabels.any(text.contains);

  static int getMaxNum(String html) {
    final document = parse(html);
    var pageCount = 0;
    final candidates = <String>[
      ...document.getElementsByClassName("last").map((e) => e.text),
      ...document
          .querySelectorAll('a[href*="page="]')
          .map((e) => e.attributes['href'] ?? ''),
      ...document
          .querySelectorAll('option[value*="page="]')
          .map((e) => e.attributes['value'] ?? ''),
      ...document
          .querySelectorAll('input[value]')
          .map((e) => e.attributes['value'] ?? ''),
    ];
    for (final candidate in candidates) {
      for (final match in RegExp(
        r'(?:page=|[^\d])(\d{1,5})(?=[^\d]|$)',
      ).allMatches(' $candidate ')) {
        final parsed = int.tryParse(match.group(1) ?? '');
        if (parsed != null && parsed > pageCount) pageCount = parsed;
      }
    }
    return pageCount;
  }

  static List<RecommendBlock> getRecommend(String html) {
    Document document = parse(html);
    Element? a = document.getElementById("centers");
    List<RecommendBlock> recommendBlockList = [];
    final centerBlocks =
        a?.getElementsByClassName("block") ?? const <Element>[];
    for (int i = 1; i <= 3; i++) {
      List<NovelCover> blockList = [];
      if (i >= centerBlocks.length) continue;
      Element block = centerBlocks[i];
      final titleElements = block.getElementsByClassName("blocktitle");
      if (titleElements.isEmpty) continue;
      String blockTitle = titleElements[0].text;
      if (i == 1) {
        blockTitle = blockTitle.split("(")[0];
      }
      List<Element> tempBlock1Content = block.querySelectorAll(
        "div[style='float: left;text-align:center;width: 95px; height:155px;overflow:hidden;']",
      );
      for (var j in tempBlock1Content) {
        final links = j.getElementsByTagName("a");
        final images = j.getElementsByTagName("img");
        if (links.length < 2 || images.isEmpty) continue;
        String title = links[1].text;
        String img = images[0].attributes["src"] ?? "";
        if (!img.startsWith("https")) {
          img = img.replaceFirst("http", "https");
        }
        String url = links[0].attributes["href"] ?? "";
        final bookIndex = url.indexOf("book/");
        final htmIndex = url.indexOf(".htm");
        String aid = bookIndex != -1 && htmIndex > bookIndex + 5
            ? url.substring(url.indexOf("book/") + 5, url.indexOf(".htm"))
            : "";
        blockList.add(NovelCover(title, img, aid));
      }
      recommendBlockList.add(RecommendBlock(blockTitle, blockList));
    }
    RegExp regex = RegExp(r"^(http|https)://[^\s/$.?#].[^\s]*$");
    final mainBlocks = document.querySelectorAll("div.main");
    for (int i = 2; i <= 3; i++) {
      if (i >= mainBlocks.length) continue;
      Element b = mainBlocks[i];
      List<NovelCover> blockList = [];
      String blockTitle = b.querySelector("div.blocktitle")?.text ?? "";
      if (i == 3) {
        blockTitle = blockTitle.split("(")[0];
      }
      List<Element> tempBlock1Content = b.querySelectorAll(
        "div[style='float: left;text-align:center;width: 95px; height:155px;overflow:hidden;']",
      );
      for (var j in tempBlock1Content) {
        try {
          final links = j.getElementsByTagName("a");
          final images = j.getElementsByTagName("img");
          if (links.length < 2 || images.isEmpty) continue;
          String title = links[1].text;
          String img = images[0].attributes["src"] ?? "";
          if (!regex.hasMatch(img)) img = "";
          if (!img.startsWith("https")) {
            img = img.replaceFirst("http", "https");
          }
          String url = links[0].attributes["href"] ?? "";
          final bookIndex = url.indexOf("book/");
          final htmIndex = url.indexOf(".htm");
          String aid = bookIndex != -1 && htmIndex > bookIndex + 5
              ? url.substring(bookIndex + 5, htmIndex)
              : "";
          blockList.add(NovelCover(title, img, aid));
        } catch (e) {
          continue;
        }
      }
      recommendBlockList.add(RecommendBlock(blockTitle, blockList));
    }

    return recommendBlockList;
  }

  static List<CatVolume> getCatalogue(String html) {
    final document = parse(html);

    final table = document.querySelector('table.css');
    if (table == null) return _getCatalogueByChapterLinks(document);

    final rows = table.querySelectorAll('tr');
    final List<CatVolume> volumes = [];

    String? currentVolumeTitle;
    List<CatChapter> currentChapters = [];

    for (var row in rows) {
      final volTd = row.querySelector('td.vcss');
      if (volTd != null) {
        if (currentVolumeTitle != null) {
          volumes.add(
            CatVolume(title: currentVolumeTitle, chapters: currentChapters),
          );
          currentChapters = [];
        }
        currentVolumeTitle = volTd.text.trim();
        continue;
      }

      final ccssTds = row.querySelectorAll('td.ccss');
      for (var td in ccssTds) {
        final linkEl = td.querySelector('a');
        if (linkEl == null) continue;

        final title = linkEl.text.trim();
        final href = linkEl.attributes['href']?.trim() ?? '';

        if (title.isEmpty || href.isEmpty) continue;

        final cid = _getWenku8ChapterCidFromHref(href);
        if (cid.isEmpty) continue;

        currentChapters.add(CatChapter(title: title, cid: cid));
      }
    }

    if (currentVolumeTitle != null) {
      volumes.add(
        CatVolume(title: currentVolumeTitle, chapters: currentChapters),
      );
    }

    return volumes;
  }

  static List<CatVolume> _getCatalogueByChapterLinks(Document document) {
    final links = document.querySelectorAll('a[href]').toList(growable: false);
    final chapters = <CatChapter>[];
    final seen = <String>{};
    for (final link in links) {
      final title = link.text.trim();
      final href = link.attributes['href']?.trim() ?? '';
      if (title.isEmpty || href.isEmpty) continue;
      final cid = _getWenku8ChapterCidFromHref(href);
      if (cid.isEmpty || !seen.add(cid)) continue;
      chapters.add(CatChapter(title: title, cid: cid));
    }
    if (chapters.isEmpty) return const [];
    return [CatVolume(title: '正文', chapters: chapters)];
  }

  static String _getWenku8ChapterCidFromHref(String href) {
    final uri = Uri.tryParse(href.replaceAll('&amp;', '&'));
    final queryCid = uri?.queryParameters['cid']?.trim() ?? '';
    if (queryCid.isNotEmpty) return queryCid;

    final regexCid = RegExp(
      r'[?&]cid=([^&#]+)',
    ).firstMatch(href)?.group(1)?.trim();
    if (regexCid != null && regexCid.isNotEmpty) return regexCid;

    final path = href.split('?').first.split('#').first;
    final normalized = path.replaceAll('\\', '/').toLowerCase();
    if (normalized.contains('/book/')) return '';
    final file = normalized.split('/').last;
    return RegExp(r'^(\d+)\.htm$').firstMatch(file)?.group(1) ?? '';
  }

  static List<CommentItem> getComment(String html) {
    final document = parse(html);
    final contentEl = document.getElementById('content');
    if (contentEl == null) {
      throw StateError('Element with id "content" not found');
    }
    final tables = contentEl.getElementsByTagName('table');
    if (tables.length < 3) {
      throw StateError('Expected at least 3 tables inside "content"');
    }
    final targetTable = tables[2];
    final rows = targetTable.getElementsByTagName('tr');
    final comments = <CommentItem>[];
    for (final row in rows) {
      if (row.attributes.containsKey('align')) continue;
      final tds = row.getElementsByTagName('td');
      if (tds.length < 4) continue;
      final a0 = tds[0].querySelector('a');
      var reply = a0?.attributes['href'] ?? '';
      RegExp regExp = RegExp(r"rid=(\d+)");
      RegExpMatch? match = regExp.firstMatch(reply);
      if (match != null) {
        reply = match.group(1)!;
      }
      final contentText = a0?.text.trim() ?? '';
      final viewAndReply = tds[1].text.trim();
      final idx = viewAndReply.indexOf('/');
      final replyCount = idx > 0 ? viewAndReply.substring(0, idx) : '';
      final viewCount = (idx >= 0 && idx + 1 < viewAndReply.length)
          ? viewAndReply.substring(idx + 1)
          : '';
      final a2 = tds[2].querySelector('a');
      final userName = a2?.text.trim() ?? '';
      final href2 = a2?.attributes['href'] ?? '';
      final uid = href2.contains('uid=') ? href2.split('uid=').last : '';
      final timeRaw = tds[3].text.trim();
      final time = Util.getDateTime(timeRaw);

      comments.add(
        CommentItem(
          rid: reply,
          content: contentText,
          replyCount: replyCount,
          viewCount: viewCount,
          userName: userName,
          uid: uid,
          time: time,
        ),
      );
    }

    return comments;
  }

  static List<ReplyItem> getReply(String html) {
    final document = parse(html);
    final Element? a = document.getElementById("content");
    if (a == null) {
      return [];
    }
    final List<Element> b = a.getElementsByTagName("table");
    final List<Element> paddingTables = a.querySelectorAll(
      "table[cellpadding='3']",
    );
    if (paddingTables.length > 1) {
      final Element d = paddingTables[1];
      final Element? lastElement = d.querySelector(".last");
      if (lastElement != null) {}
    }
    final List<ReplyItem> tempR = [];
    int count = 0;
    for (final Element c in b) {
      count++;
      if (count < 4) {
        continue;
      } else if (count == b.length - 1) {
        break;
      }
      final List<Element> tds = c.querySelectorAll("td");
      if (tds.length < 2) {
        continue;
      }
      final Element firstTd = tds[0];
      final Element? userLink = firstTd.querySelector("a");
      String userName = userLink?.text ?? "";
      String uid = "";
      final String? href = userLink?.attributes["href"];
      if (href != null && href.contains("uid=")) {
        final List<String> parts = href.split("uid=");
        if (parts.length > 1) {
          uid = parts[1];
        }
      }
      final Element secondTd = tds[1];
      final List<Element> divsInSecondTd = secondTd.querySelectorAll("div");
      String rawTime = "";
      if (divsInSecondTd.length > 1) {
        final Element timeDiv = divsInSecondTd[1];
        rawTime = timeDiv.text;
        if (rawTime.contains("|")) {
          final int pipeIndex = rawTime.indexOf("|");
          if (pipeIndex > 0) {
            rawTime = rawTime.substring(0, pipeIndex - 1);
          }
        }
      }
      final String time = rawTime;
      String content = "";
      if (divsInSecondTd.length > 2) {
        final Element contentDiv = divsInSecondTd[2];
        content = contentDiv.text;
      }
      final String formattedTime = Util.getDateTime(time.trim());
      tempR.add(
        ReplyItem(
          content: content,
          userName: userName,
          uid: uid,
          time: formattedTime,
        ),
      );
    }
    return tempR;
  }

  static Bookshelf getBookshelf(String html, int classId) {
    final document = parse(html);

    final content = document.getElementById('content');
    if (content == null) {
      throw StateError('Element with id "content" not found');
    }

    final List<BookshelfNovelInfo> novels = [];
    final rows = content.getElementsByTagName('tr');
    for (final row in rows) {
      if (row.attributes.containsKey('align')) continue;
      final cells = row.getElementsByTagName('td');
      if (cells.length < 2) continue;
      final firstTd = cells.first;
      if (firstTd.classes.contains('foot')) continue;

      final bid = cells[0].querySelector('input')?.attributes['value'] ?? '';

      final linkEl = cells[1].querySelector('a');
      final bookUrl = linkEl?.attributes['href'] ?? '';
      final title = linkEl?.text.trim() ?? '';
      if (bookUrl.isEmpty || title.isEmpty) continue;

      final updateCell = cells.length > 2 ? cells[2] : null;
      final updateLink = updateCell?.querySelector('a');
      final updateTitle =
          updateLink?.text.trim() ?? updateCell?.text.trim() ?? '';
      final updateHref = updateLink?.attributes['href'] ?? '';
      final updateKey = updateHref.isNotEmpty ? updateHref : updateTitle;
      final updateTime = _parseBookshelfUpdateTime(row);

      final aidStart = bookUrl.indexOf('aid=') + 4;
      final aidEnd = bookUrl.indexOf('&', aidStart);
      final aid = aidStart >= 4 && aidEnd > aidStart
          ? bookUrl.substring(aidStart, aidEnd)
          : '';
      if (aid.isEmpty) continue;

      String imgUrl;
      if (aid.length <= 3) {
        imgUrl = 'https://img.wenku8.com/image/0/$aid/${aid}s.jpg';
      } else {
        imgUrl = 'https://img.wenku8.com/image/${aid[0]}/$aid/${aid}s.jpg';
      }

      novels.add(
        BookshelfNovelInfo(
          bid: bid,
          aid: aid,
          url: bookUrl,
          title: title,
          img: imgUrl,
          updateKey: updateKey,
          updateTime: updateTime,
        ),
      );
    }

    final gridtop = content.querySelector('div.gridtop')?.text.trim() ?? '';
    var shelfTitle = gridtop.length > 4 ? gridtop.substring(4) : gridtop;
    shelfTitle = shelfTitle.split('。').first.trim();
    shelfTitle = shelfTitle.length > 3 ? shelfTitle.substring(3) : shelfTitle;

    return Bookshelf(list: novels, classId: classId.toString());
  }

  static DateTime? _parseBookshelfUpdateTime(Element row) {
    for (final td in row.getElementsByTagName('td').reversed) {
      final text = td.text.trim();
      final match = RegExp(
        r'(\d{4})[-/](\d{1,2})[-/](\d{1,2})(?:\s+(\d{1,2}):(\d{1,2}))?',
      ).firstMatch(text);
      if (match == null) continue;
      return DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
        int.tryParse(match.group(4) ?? '') ?? 0,
        int.tryParse(match.group(5) ?? '') ?? 0,
      );
    }
    return null;
  }

  static String novelVote(String html) {
    Document document = parse(html);
    var blockContent = document.getElementsByClassName("blockcontent");
    if (blockContent.isNotEmpty) {
      var targetDiv = blockContent[0].querySelector(
        "div[style='padding:10px']",
      );
      return targetDiv!.text;
    }
    return "";
  }

  static UserInfo getUserInfo(String html) {
    final Document document = parse(html);
    final Element? content = document.getElementById('content');
    final List<Element> rows =
        content?.querySelector('tbody')?.querySelectorAll('tr') ?? <Element>[];
    if (rows.isEmpty) {
      throw StateError('Wenku8 user info content not found');
    }

    String cellText(int rowIndex, int cellIndex) {
      if (rowIndex >= rows.length) return "";
      final cells = rows[rowIndex].querySelectorAll('td');
      if (cellIndex >= cells.length) return "";
      return cells[cellIndex].text.trim();
    }

    String linkText(int rowIndex, int cellIndex) {
      if (rowIndex >= rows.length) return "";
      final cells = rows[rowIndex].querySelectorAll('td');
      if (cellIndex >= cells.length) return "";
      return cells[cellIndex].querySelector('a')?.text.trim() ??
          cells[cellIndex].text.trim();
    }

    final row0Cells = rows.first.querySelectorAll('td');
    String avatar = row0Cells.length > 2
        ? row0Cells[2].querySelector('img')?.attributes['src']?.trim() ?? ""
        : "";
    if (avatar.isEmpty) {
      avatar = "${Api.wenku8Node.node}/images/noavatar.jpg";
    } else {
      avatar = ImageUrlHelper.normalize(avatar).replaceAll("https", "http");
    }

    final String userID = cellText(0, 1);
    final String userName = cellText(2, 1);
    if (userID.isEmpty && userName.isEmpty) {
      throw StateError('Wenku8 user info fields not found');
    }

    String userLevel = cellText(4, 1);
    String email = linkText(7, 1);
    String signUpDate = cellText(12, 1);
    String contribution = cellText(13, 1);
    String experience = cellText(14, 1);
    String score = cellText(15, 1);
    String maxBookcase = cellText(18, 1);
    String maxRecommend = cellText(19, 1);
    return UserInfo(
      avatar: avatar,
      uid: userID,
      username: userName,
      userLevel: userLevel,
      email: email,
      registerDate: signUpDate,
      contribution: contribution,
      experience: experience,
      point: score,
      maxBookshelfNum: maxBookcase,
      maxRecommendNum: maxRecommend,
    );
  }

  static bool isError(String html) {
    Document document = parse(html);

    List<Element> elements = document.getElementsByClassName('blocktitle');

    String t;
    try {
      if (elements.isEmpty) throw StateError('No .blocktitle elements found');
      t = elements.first.text;
    } catch (_) {
      return false;
    }

    return t == '出现错误！' || t == '出現錯誤！';
  }

  ///判断搜索结果是否只有一个
  static NovelCover? isSearchResultOnlyOne(String html) {
    try {
      final Document document = parse(html);
      final Element? content = document.getElementById('content');
      if (content == null) return null;
      final List<Element> divs = content
          .getElementsByTagName('div')[0]
          .querySelectorAll('div[style="margin:0px auto;overflow:hidden;"]');
      if (divs.isEmpty) return null;
      final List<Element> spans = divs[0].getElementsByTagName('span');
      if (spans.length < 2) return null;
      final Element span = spans[1];
      final String? bookHref = span.querySelector('a')?.attributes['href'];
      if (bookHref == null) return null;
      final List<Element> tables = content.getElementsByTagName('table');
      if (tables.isEmpty) return null;
      final Element table0 = tables[0];
      final String title =
          table0
              .querySelectorAll('span')
              .first
              .querySelector('b')
              ?.text
              .trim() ??
          '';
      final String imgUrl = ImageUrlHelper.normalize(
        content.querySelectorAll('img').first.attributes['src']?.trim() ?? '',
      );
      final int idx = bookHref.indexOf('bid=');
      if (idx == -1) return null;
      final String aid = bookHref.substring(idx + 4);

      return NovelCover(title, imgUrl, aid);
    } catch (e) {
      return null;
    }
  }

  static Content getContent(String html) {
    // 解析HTML并提取核心内容
    Document document = parse(html);
    Element? contentElement = document.getElementById('content');
    contentElement ??= document.querySelector('div#contentmain');
    contentElement ??= document.querySelector('td#content');
    contentElement ??= document.querySelector('div.content');
    if (contentElement == null) {
      throw StateError('Wenku8 chapter content element not found');
    }

    // 提取所有img标签的src属性到List
    List<String> imgSrcList = [];
    List<Element> imgElements = contentElement.querySelectorAll('img');
    for (var img in imgElements) {
      String? src = img.attributes['src'];
      if (src != null && src.isNotEmpty) {
        imgSrcList.add(ImageUrlHelper.normalize(src));
      }
    }

    // 移除指定元素（比如id=contentdp的ul）
    contentElement.querySelectorAll('ul#contentdp').forEach((e) => e.remove());

    // 去除文本首尾的空行（核心处理）
    // 正则说明：^[\n\s]* 匹配开头的所有换行/空白；[\n\s]*$ 匹配结尾的所有换行/空白
    String trimmedText = contentElement.text.replaceAll(
      RegExp(r'^[\n\s]*|[\n\s]*$'),
      '',
    );

    // 按空行分割成段落列表（兼容含空格的空行）
    List<String> paragraphs = trimmedText.split(RegExp(r'\n\s*\n'));

    // 处理每个段落，仅第一行加缩进
    List<String> processedParagraphs = paragraphs.map((paragraph) {
      String trimmedPara = paragraph.trim();
      if (trimmedPara.isEmpty) {
        return '';
      }
      List<String> lines = paragraph.split('\n');
      if (lines.isNotEmpty) {
        lines[0] = '   ${lines[0]}'; // 仅首行加3个空格
      }
      return lines.join('\n');
    }).toList();

    // 拼接段落，保留段落间空行，确保最终文本无首尾空行
    String finalText = processedParagraphs.join('\n\n').trim();

    // 从纯文本中移除图片链接
    for (var src in imgSrcList) {
      finalText = finalText.replaceAll(src, '');
    }

    return Content(text: finalText, images: imgSrcList);
  }
}
