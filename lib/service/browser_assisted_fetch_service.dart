import 'package:hikari_novel_flutter/service/local_storage_service.dart';
import 'package:html/parser.dart';

class BrowserAssistedFetchService {
  const BrowserAssistedFetchService._();

  static List<String> cacheAliasesFor(String url) => _lookupCacheKeys(url);

  static String? getCachedHtml(String url) {
    for (final key in _lookupCacheKeys(url)) {
      final html = LocalStorageService.instance.getAssistedHtml(key);
      if (html != null && isUsableHtmlForUrl(url, html)) return html;
    }
    return null;
  }

  static void saveHtml({
    required String requestedUrl,
    required String currentUrl,
    required String html,
  }) {
    final current = currentUrl.trim();
    final requested = requestedUrl.trim();
    final savedKeys = <String>{};

    void saveFor(String url) {
      if (url.isEmpty || !isUsableHtmlForUrl(url, html)) return;
      final key = _primaryCacheKey(url);
      if (key.isEmpty || !savedKeys.add(key)) {
        return;
      }
      LocalStorageService.instance.setAssistedHtml(key, html);
    }

    saveFor(current);
    saveFor(requested);
  }

  static List<String> _lookupCacheKeys(String url) {
    final clean = url.trim();
    if (clean.isEmpty) return const [];
    return <String>{
      _primaryCacheKey(clean),
      ..._legacyCacheKeys(clean),
    }.where((key) => key.isNotEmpty).toList(growable: false);
  }

  static String _primaryCacheKey(String url) {
    final clean = url.trim();
    if (clean.isEmpty) return '';
    final uri = Uri.tryParse(clean);
    if (uri == null || !uri.host.toLowerCase().contains('wenku8.')) {
      return clean;
    }
    var host = uri.host.toLowerCase();
    if (host.endsWith('wenku8.net')) {
      host = host.replaceFirst('wenku8.net', 'wenku8.cc');
    }
    var path = uri.path.isEmpty ? '/' : uri.path;
    if (path == '/index.php') path = '/';
    final query = _queryWithoutCharset(uri);
    return uri
        .replace(host: host, path: path, query: query, fragment: '')
        .toString();
  }

  static String? _queryWithoutCharset(Uri uri) {
    final parts = uri.query.split('&').where((part) {
      if (part.trim().isEmpty) return false;
      final key = part.split('=').first.trim().toLowerCase();
      return key != 'charset';
    }).toList();
    return parts.isEmpty ? null : parts.join('&');
  }

  static List<String> _legacyCacheKeys(String url) {
    final clean = url.trim();
    if (clean.isEmpty) return const [];
    final keys = <String>{clean};
    for (var index = 0; index < keys.length; index++) {
      final current = keys.elementAt(index);
      keys.add(_withoutCharsetQuery(current));
      keys.addAll(_wenku8HostAliases(current));
      keys.addAll(_wenku8HomeAliases(current));
    }
    return keys.where((key) => key.isNotEmpty).toList(growable: false);
  }

  static String _withoutCharsetQuery(String url) {
    final queryStart = url.indexOf('?');
    if (queryStart < 0) return url;
    final fragmentStart = url.indexOf('#', queryStart);
    final base = url.substring(0, queryStart);
    final fragment = fragmentStart >= 0 ? url.substring(fragmentStart) : '';
    final query = url.substring(
      queryStart + 1,
      fragmentStart >= 0 ? fragmentStart : url.length,
    );
    final parts = query.split('&').where((part) {
      if (part.trim().isEmpty) return false;
      final key = part.split('=').first.trim().toLowerCase();
      return key != 'charset';
    }).toList();
    if (parts.isEmpty) return '$base$fragment';
    return '$base?${parts.join('&')}$fragment';
  }

  static Iterable<String> _wenku8HostAliases(String url) sync* {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final host = uri.host.toLowerCase();
    if (!host.contains('wenku8.')) return;
    if (host.endsWith('wenku8.cc')) {
      yield uri
          .replace(host: host.replaceFirst('wenku8.cc', 'wenku8.net'))
          .toString();
    } else if (host.endsWith('wenku8.net')) {
      yield uri
          .replace(host: host.replaceFirst('wenku8.net', 'wenku8.cc'))
          .toString();
    }
  }

  static Iterable<String> _wenku8HomeAliases(String url) sync* {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!uri.host.toLowerCase().contains('wenku8.')) return;
    final path = uri.path.isEmpty ? '/' : uri.path;
    if (path != '/' && path != '/index.php') return;
    yield uri.replace(path: '/').toString();
    yield uri.replace(path: '/index.php').toString();
  }

  static bool isUsableHtml(String html) {
    final normalized = html.toLowerCase();
    if (normalized.length < 200) return false;
    if (isWenku8ChallengeOrWaitHtml(html)) {
      return false;
    }
    return true;
  }

  static bool isWenku8ChallengeOrWaitHtml(String html) {
    final normalized = html.toLowerCase();
    return normalized.contains('cf-browser-verification') ||
        normalized.contains('cf_chl') ||
        normalized.contains('_cf_chl_opt') ||
        normalized.contains('__cf_chl_tk') ||
        normalized.contains('cf-mitigated') ||
        normalized.contains('cloudflare challenge') ||
        normalized.contains('challenge-platform') ||
        normalized.contains('challenge-running') ||
        normalized.contains('just a moment') ||
        normalized.contains('attention required') ||
        normalized.contains('access denied') ||
        normalized.contains('<title>\u8bf7\u7a0d\u5019') ||
        normalized.contains('\u8bf7\u7a0d\u5019...</title>');
  }

  static bool isUsableHtmlForUrl(String url, String html) {
    if (!isUsableHtml(html)) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return true;
    final path = uri.path.toLowerCase();
    final normalized = html.toLowerCase();
    if (path.endsWith('/modules/article/toplist.php') ||
        path.endsWith('/modules/article/tags.php') ||
        path.endsWith('/modules/article/articlelist.php')) {
      return _looksLikeWenku8List(normalized);
    }
    if (path == '/' || path.endsWith('/index.php')) {
      return _looksLikeWenku8Home(normalized);
    }
    if (path.endsWith('/modules/article/articleinfo.php') ||
        RegExp(r'/book/\d+\.htm$').hasMatch(path)) {
      return _looksLikeWenku8Detail(normalized, _wenku8DetailAid(uri));
    }
    final staticReader = _wenku8StaticReaderPath(uri);
    if (staticReader != null) {
      if (staticReader.cid == null || staticReader.cid!.isEmpty) {
        return _looksLikeWenku8Catalogue(normalized, aid: staticReader.aid);
      }
      return _looksLikeWenku8ChapterContent(normalized);
    }
    if (path.endsWith('/modules/article/reader.php')) {
      return _looksLikeWenku8Reader(
        normalized,
        aid: uri.queryParameters['aid']?.trim(),
        cid: uri.queryParameters['cid']?.trim(),
      );
    }
    return true;
  }

  static String? wenku8ReaderCatalogueRedirectUrl({
    required String requestedUrl,
    String? currentUrl,
    required String html,
  }) {
    final requestedUri = Uri.tryParse(requestedUrl.trim());
    if (requestedUri == null) return null;
    final reader = _wenku8ReaderPath(requestedUri);
    if (reader == null || reader.cid?.isNotEmpty == true) return null;

    final baseUri =
        Uri.tryParse(
          currentUrl?.trim().isNotEmpty == true
              ? currentUrl!.trim()
              : requestedUrl.trim(),
        ) ??
        requestedUri;
    final current = currentUrl?.trim();
    final requested = requestedUrl.trim();
    for (final candidate in _navigationCandidates(html)) {
      final target = baseUri.resolve(candidate.trim());
      if (!_isWenku8Host(target.host)) continue;
      final targetUrl = target.removeFragment().toString();
      if (targetUrl == current || targetUrl == requested) continue;
      final staticReader = _wenku8StaticReaderPath(target);
      if (staticReader?.aid == reader.aid &&
          (staticReader?.cid == null || staticReader!.cid!.isEmpty)) {
        return targetUrl;
      }
    }
    return null;
  }

  static bool _hasElementId(String html, String id, {String? tag}) {
    final tagPattern = tag == null ? r'[a-z0-9:-]+' : RegExp.escape(tag);
    final escapedId = RegExp.escape(id);
    return RegExp(
      '<$tagPattern\\b[^>]*\\bid\\s*=\\s*'
      '(?:"$escapedId"|\'$escapedId\'|$escapedId(?=\\s|/?>))',
    ).hasMatch(html);
  }

  static bool _hasContentElement(String html) => _hasElementId(html, 'content');

  static bool _hasChapterContentElement(String html) =>
      _hasContentElement(html) ||
      _hasElementId(html, 'contentmain') ||
      _hasElementId(html, 'content', tag: 'td') ||
      RegExp(
        r'''<div[^>]+\bclass\s*=\s*["'][^"']*\bcontent\b[^"']*["']''',
      ).hasMatch(html);

  static bool _hasCentersElement(String html) => _hasElementId(html, 'centers');

  static bool _hasBlockClass(String html) =>
      html.contains('class="block"') ||
      html.contains("class='block'") ||
      html.contains('blocktitle') ||
      html.contains('blockcontent');

  static bool _looksLikeWenku8Home(String html) =>
      _hasCentersElement(html) ||
      _hasBlockClass(html) ||
      (html.contains('/book/') && html.contains('width: 95px')) ||
      (html.contains('/book/') && html.contains('width:95px'));

  static bool _looksLikeWenku8List(String html) {
    if (_hasElementId(html, 'contentmain') ||
        _hasElementId(html, 'content', tag: 'td')) {
      return false;
    }
    if (_hasCentersElement(html)) return false;
    if (!_hasWenku8ListBookLink(html)) return false;
    final hasListShell = _hasContentElement(html) || _hasListPageMarker(html);
    if (!hasListShell) return false;
    return html.contains('articleinfo.php?id=') ||
        _hasListCardSize(html) ||
        html.contains('gridtop') ||
        _hasListPageMarker(html) ||
        _wenku8ListBookLinkCount(html) >= 2;
  }

  static bool _looksLikeWenku8Detail(String html, String? aid) {
    if (!_hasContentElement(html)) return false;

    // The detail page is the only Wenku8 page type that contains BOTH
    // add-to-bookshelf (addbookcase.php?bid=) AND vote (uservote.php?id=)
    // form-action URLs.  List, home, and catalogue pages never have these
    // forms.  When both are present the page is unambiguously a detail
    // page, regardless of cross-links, recommended-book cards, chapter
    // links, or nav elements that may confuse the other detection helpers.
    final hasAddBookcase = html.contains('addbookcase.php?bid=');
    final hasUserVote = html.contains('uservote.php?id=');
    if (hasAddBookcase && hasUserVote) return true;

    if (aid == null || aid.isEmpty) return false;
    if (!html.contains('reviews.php?aid=$aid') &&
        !html.contains('addbookcase.php?bid=$aid')) {
      return false;
    }

    if (_hasCentersElement(html)) return false;

    final catalogueCss = _looksLikeWenku8CatalogueTable(html);
    final readerCount = _readerChapterLinkCount(html);
    final hasStatic = _hasStaticChapterLinks(html);
    if (catalogueCss || readerCount >= 4 || (hasStatic && readerCount >= 2)) {
      return false;
    }

    if (_hasListCardSize(html)) return false;

    return true;
  }

  static bool _looksLikeWenku8Reader(
    String html, {
    required String? aid,
    required String? cid,
  }) {
    if (cid == null || cid.isEmpty) {
      return _looksLikeWenku8Catalogue(html, aid: aid);
    }
    if (!_hasChapterContentElement(html)) return false;
    return _looksLikeWenku8ChapterContent(html);
  }

  static bool _looksLikeWenku8Catalogue(String html, {required String? aid}) {
    final hasCatalogueTable = _looksLikeWenku8CatalogueTable(html);
    final readerChapterLinkCount = _readerChapterLinkCount(html);
    final hasReaderChapterLinks = readerChapterLinkCount > 0;
    final hasStaticChapterLinks = _hasStaticChapterLinks(html);
    if (!hasCatalogueTable &&
        !hasReaderChapterLinks &&
        !hasStaticChapterLinks) {
      return false;
    }
    if (aid == null || aid.isEmpty) {
      return hasCatalogueTable ||
          hasStaticChapterLinks ||
          readerChapterLinkCount >= 3;
    }
    final hasRequestedReaderLinks =
        html.contains('reader.php?aid=$aid&amp;cid=') ||
        html.contains('reader.php?aid=$aid&cid=');
    if (hasCatalogueTable) {
      return hasRequestedReaderLinks ||
          hasStaticChapterLinks ||
          (hasReaderChapterLinks && !html.contains('reader.php?aid='));
    }
    return (hasRequestedReaderLinks && readerChapterLinkCount >= 3) ||
        hasStaticChapterLinks;
  }

  static bool _looksLikeWenku8ChapterContent(String html) {
    if (_looksLikeWenku8CatalogueTable(html)) return false;
    if (_looksLikeWenku8List(html) || _looksLikeWenku8Home(html)) return false;
    final withoutTags = html
        .replaceAll(RegExp(r'<script\b[^>]*>.*?</script>', dotAll: true), ' ')
        .replaceAll(RegExp(r'<style\b[^>]*>.*?</style>', dotAll: true), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), '');
    return withoutTags.length >= 60;
  }

  static bool _looksLikeWenku8CatalogueTable(String html) =>
      html.contains('class="ccss"') ||
      html.contains("class='ccss'") ||
      html.contains('class="vcss"') ||
      html.contains("class='vcss'");

  static Iterable<String> _navigationCandidates(String html) sync* {
    final document = parse(html);
    for (final element in document.querySelectorAll(
      'a[href], frame[src], iframe[src]',
    )) {
      final value =
          element.attributes['href']?.trim() ??
          element.attributes['src']?.trim();
      if (value != null && value.isNotEmpty) yield value;
    }
    for (final meta in document.querySelectorAll('meta[http-equiv]')) {
      final httpEquiv = meta.attributes['http-equiv']?.toLowerCase().trim();
      if (httpEquiv != 'refresh') continue;
      final content = meta.attributes['content'] ?? '';
      final match = RegExp(
        r'''url\s*=\s*['"]?([^'";]+)''',
        caseSensitive: false,
      ).firstMatch(content);
      final value = match?.group(1)?.trim();
      if (value != null && value.isNotEmpty) yield value;
    }
    for (final script in document.querySelectorAll('script')) {
      final text = script.text;
      final patterns = [
        RegExp(
          r'''(?:window\.)?location(?:\.href)?\s*=\s*['"]([^'"]+)['"]''',
          caseSensitive: false,
        ),
        RegExp(
          r'''location\.replace\(\s*['"]([^'"]+)['"]''',
          caseSensitive: false,
        ),
      ];
      for (final pattern in patterns) {
        for (final match in pattern.allMatches(text)) {
          final value = match.group(1)?.trim();
          if (value != null && value.isNotEmpty) yield value;
        }
      }
    }
  }

  static bool _hasWenku8ListBookLink(String html) =>
      html.contains('articleinfo.php?id=') ||
      _wenku8ListBookLinkCount(html) > 0;

  static int _wenku8ListBookLinkCount(String html) {
    final bookLinks = RegExp(
      r'''href\s*=\s*["'](?:[^"']*/)?book/\d+\.htm''',
    ).allMatches(html).length;
    final articleInfoLinks = RegExp(
      r'''href\s*=\s*["'][^"']*articleinfo\.php\?id=\d+''',
    ).allMatches(html).length;
    return bookLinks + articleInfoLinks;
  }

  static bool _hasListPageMarker(String html) =>
      html.contains('tags含有') ||
      html.contains('小说列表') ||
      html.contains('轻小说') ||
      html.contains('toplist.php') ||
      html.contains('articlelist.php') ||
      html.contains('tags.php') ||
      html.contains('gridtop');

  static bool _hasListCardSize(String html) {
    final compact = html.replaceAll(RegExp(r'\s+'), '');
    return compact.contains('width:373px') ||
        compact.contains('height:136px') ||
        compact.contains('width:95px') ||
        compact.contains('height:155px');
  }

  static String? _wenku8DetailAid(Uri uri) {
    final id = uri.queryParameters['id'];
    if (id != null && id.trim().isNotEmpty) return id.trim();
    final match = RegExp(r'/book/(\d+)\.htm$').firstMatch(uri.path);
    return match?.group(1);
  }

  static bool _hasStaticChapterLinks(String html) {
    final matches = RegExp(
      r'''href=["']([^"']+\.htm(?:[?#][^"']*)?)["']''',
    ).allMatches(html);
    for (final match in matches) {
      final href = match.group(1)?.toLowerCase() ?? '';
      if (href.contains('/book/')) continue;
      final path = href.split('?').first.split('#').first;
      final file = path.split('/').last;
      if (RegExp(r'^\d+\.htm$').hasMatch(file)) return true;
    }
    return false;
  }

  static int _readerChapterLinkCount(String html) {
    return RegExp(
      r'''reader\.php\?(?:cid=|[^"'<>\s]*(?:&amp;|&)cid=)''',
    ).allMatches(html).length;
  }

  static _Wenku8StaticReaderPath? _wenku8StaticReaderPath(Uri uri) {
    final match = RegExp(
      r'^/novel/\d+/(\d+)/(?:$|index\.htm$|(\d+)\.htm$)',
    ).firstMatch(uri.path.toLowerCase());
    if (match == null) return null;
    return _Wenku8StaticReaderPath(aid: match.group(1), cid: match.group(2));
  }

  static _Wenku8StaticReaderPath? _wenku8ReaderPath(Uri uri) {
    if (!uri.path.toLowerCase().endsWith('/modules/article/reader.php')) {
      return null;
    }
    final aid = uri.queryParameters['aid']?.trim();
    if (aid == null || aid.isEmpty) return null;
    return _Wenku8StaticReaderPath(aid: aid, cid: uri.queryParameters['cid']);
  }

  static bool _isWenku8Host(String host) {
    final normalized = host.toLowerCase();
    return normalized.endsWith('wenku8.cc') ||
        normalized.endsWith('wenku8.net');
  }
}

class _Wenku8StaticReaderPath {
  const _Wenku8StaticReaderPath({required this.aid, required this.cid});

  final String? aid;
  final String? cid;
}
