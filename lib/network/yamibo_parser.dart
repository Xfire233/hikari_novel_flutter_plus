import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:hikari_novel_flutter/models/bookshelf.dart';
import 'package:hikari_novel_flutter/models/cat_chapter.dart';
import 'package:hikari_novel_flutter/models/cat_volume.dart';
import 'package:hikari_novel_flutter/models/content.dart';
import 'package:hikari_novel_flutter/models/novel_cover.dart';
import 'package:hikari_novel_flutter/models/novel_detail.dart';
import 'package:hikari_novel_flutter/models/source_id.dart';

import 'yamibo_api.dart';

class YamiboThreadData {
  final NovelDetail detail;
  final String authorId;
  final int maxPage;
  final String updateKey;
  final DateTime? updateTime;

  YamiboThreadData({
    required this.detail,
    required this.authorId,
    required this.maxPage,
    required this.updateKey,
    required this.updateTime,
  });
}

class YamiboFavoritePageData {
  final List<BookshelfNovelInfo> items;
  final int count;
  final int perPage;

  YamiboFavoritePageData({
    required this.items,
    required this.count,
    required this.perPage,
  });
}

class YamiboForumType {
  final String id;
  final String title;

  const YamiboForumType({required this.id, required this.title});
}

class YamiboForumThread {
  final String tid;
  final String title;
  final String author;
  final String lastPoster;
  final String typeId;
  final int replies;
  final int views;
  final DateTime? lastPostTime;
  final bool isTop;
  final bool isDigest;

  const YamiboForumThread({
    required this.tid,
    required this.title,
    required this.author,
    required this.lastPoster,
    required this.typeId,
    required this.replies,
    required this.views,
    required this.lastPostTime,
    required this.isTop,
    required this.isDigest,
  });

  String get aid => SourceId.yamiboAid(tid);
}

class YamiboForumPageData {
  final String fid;
  final String forumName;
  final int page;
  final int perPage;
  final int threadCount;
  final List<YamiboForumType> types;
  final List<YamiboForumThread> threads;
  final String? message;

  const YamiboForumPageData({
    required this.fid,
    required this.forumName,
    required this.page,
    required this.perPage,
    required this.threadCount,
    required this.types,
    required this.threads,
    this.message,
  });

  bool get hasPermissionError =>
      message?.contains('viewperm_login_nopermission') == true;
}

class YamiboUserThreadPageData {
  const YamiboUserThreadPageData({
    required this.threads,
    required this.hasMore,
  });

  final List<YamiboForumThread> threads;
  final bool hasMore;
}

class YamiboSearchPageData {
  const YamiboSearchPageData({
    required this.items,
    required this.hasMore,
    this.searchId,
  });

  final List<NovelCover> items;
  final bool hasMore;
  final String? searchId;
}

class YamiboParser {
  static List<String> titleTags(String title) {
    final tags = <String>[];
    final seen = <String>{};
    for (final match in RegExp(r'[\[【]([^\]】]{1,24})[\]】]').allMatches(title)) {
      final raw = match.group(1) ?? '';
      for (final part in raw.split(RegExp(r'[/／,，、\s]+'))) {
        final tag = part.trim();
        if (tag.isEmpty) continue;
        final key = tag.toLowerCase();
        if (seen.add(key)) tags.add(tag);
      }
    }
    return tags;
  }

  static String? threadErrorMessage(String jsonText) {
    try {
      final json = jsonDecode(jsonText);
      if (json is! Map) return null;
      final message = json['Message'];
      if (message is! Map) return null;
      final text = _htmlToText(
        '${message['messagestr'] ?? message['message'] ?? message['messageval'] ?? ''}',
      ).trim();
      if (text.isEmpty) return null;
      return text;
    } catch (_) {
      return null;
    }
  }

  static String accountNameFromMobileJson(String jsonText) {
    try {
      final variables = _variables(jsonText);
      for (final key in [
        'member_username',
        'member_username_encode',
        'username',
      ]) {
        final value = _htmlToText('${variables[key] ?? ''}').trim();
        if (value.isNotEmpty && value != 'null') return value;
      }
      final member = variables['member'];
      if (member is Map) {
        for (final key in ['username', 'member_username']) {
          final value = _htmlToText('${member[key] ?? ''}').trim();
          if (value.isNotEmpty && value != 'null') return value;
        }
      }
    } catch (_) {
      return '';
    }
    return '';
  }

  static bool isUserThreadPermissionPage(String html) {
    final text = _htmlToText(html);
    if ((text.contains('提示信息') || text.contains('提示訊息')) &&
        (text.contains('登录') ||
            text.contains('登入') ||
            text.contains('您需要先登录') ||
            text.contains('您需要先登入'))) {
      return true;
    }
    return text.contains('提示信息') &&
        (text.contains('登录') ||
            text.contains('登入') ||
            text.contains('您需要先登录') ||
            text.contains('您需要先登入'));
  }

  static bool isSearchTooQuicklyPage(String html) {
    final text = _htmlToText(html);
    if (text.contains('10 秒') ||
        text.contains('10秒') ||
        text.contains('搜索间隔') ||
        text.contains('搜尋間隔') ||
        text.contains('两次搜索') ||
        text.contains('兩次搜尋')) {
      return true;
    }
    return text.contains('10 秒') ||
        text.contains('10秒') ||
        text.contains('搜索间隔') ||
        text.contains('搜尋間隔') ||
        text.contains('两次搜索') ||
        text.contains('兩次搜尋');
  }

  static YamiboThreadData getThreadDetail(String jsonText) {
    final variables = _variables(jsonText);
    final thread = variables['thread'] as Map<String, dynamic>? ?? {};
    final postList = _postList(variables);
    final authorId = '${thread['authorid'] ?? ''}';
    final subject = '${thread['subject'] ?? 'Yamibo'}'.trim();
    final tags = ['Yamibo', '论坛主题', ...titleTags(subject)];
    final author = '${thread['author'] ?? ''}'.trim();
    final replies = int.tryParse('${thread['replies'] ?? 0}') ?? 0;
    final views = '${thread['views'] ?? 0}';
    final ppp = int.tryParse('${variables['ppp'] ?? 20}') ?? 20;
    final maxPage = _threadMaxPage(variables, replies, ppp);
    final updateTime = getLatestAuthorPostTime(jsonText, authorId: authorId);
    final updateKey =
        '$authorId:$maxPage:${updateTime?.millisecondsSinceEpoch ?? ''}';

    final firstAuthorPost = postList
        .cast<Map<String, dynamic>?>()
        .whereType<Map<String, dynamic>>()
        .firstWhere(
          (post) => authorId.isEmpty || '${post['authorid'] ?? ''}' == authorId,
          orElse: () => postList.isNotEmpty
              ? postList.first as Map<String, dynamic>
              : <String, dynamic>{},
        );
    final intro = _htmlToText('${firstAuthorPost['message'] ?? ''}');
    final cover =
        _extractImages('${firstAuthorPost['message'] ?? ''}').firstOrNull ?? '';

    final detail = NovelDetail(
      subject,
      author.isEmpty ? 'Yamibo' : author,
      'Yamibo',
      '${thread['lastpost'] ?? ''}',
      cover,
      intro.length > 240 ? '${intro.substring(0, 240)}...' : intro,
      tags,
      '回复 $replies',
      '浏览 $views',
      false,
    );
    final tid = '${thread['tid'] ?? ''}';
    detail.catalogue.add(
      CatVolume(
        title: 'Yamibo',
        chapters: List.generate(
          maxPage,
          (index) => CatChapter(
            title: '第 ${index + 1} 页',
            cid: SourceId.yamiboCid(tid, index + 1),
          ),
        ),
      ),
    );

    return YamiboThreadData(
      detail: detail,
      authorId: authorId,
      maxPage: maxPage,
      updateKey: updateKey,
      updateTime: updateTime,
    );
  }

  static NovelCover getThreadCover(String jsonText) {
    final variables = _variables(jsonText);
    final thread = variables['thread'] as Map<String, dynamic>? ?? {};
    final data = getThreadDetail(jsonText);
    final tid = '${thread['tid'] ?? ''}';
    return NovelCover(
      data.detail.title,
      data.detail.imgUrl,
      SourceId.yamiboAid(tid),
    );
  }

  static int? getCurrentPage(String jsonText) {
    final variables = _variables(jsonText);
    return int.tryParse('${variables['page'] ?? ''}')?.clamp(1, 99999).toInt();
  }

  static DateTime? getLatestAuthorPostTime(
    String jsonText, {
    String? authorId,
  }) {
    final variables = _variables(jsonText);
    final thread = variables['thread'] as Map<String, dynamic>? ?? {};
    final ownerId = authorId?.isNotEmpty == true
        ? authorId!
        : '${thread['authorid'] ?? ''}';
    DateTime? latest;
    for (final post in _postList(
      variables,
    ).cast<Map<String, dynamic>?>().whereType<Map<String, dynamic>>()) {
      if (ownerId.isNotEmpty && '${post['authorid'] ?? ''}' != ownerId) {
        continue;
      }
      final time = _parseUnixSeconds(post['dateline']);
      if (time != null && (latest == null || time.isAfter(latest))) {
        latest = time;
      }
    }
    return latest;
  }

  static int _threadMaxPage(
    Map<String, dynamic> variables,
    int replies,
    int perPage,
  ) {
    for (final key in ['totalpage', 'totalPage', 'total_page', 'maxpage']) {
      final value = int.tryParse('${variables[key] ?? ''}');
      if (value != null && value > 0) return value.clamp(1, 99999).toInt();
    }
    return ((replies + 1) / perPage).ceil().clamp(1, 99999).toInt();
  }

  static List<CatChapter> getOwnerPostChapters(String jsonText) {
    final variables = _variables(jsonText);
    final thread = variables['thread'] as Map<String, dynamic>? ?? {};
    final tid = '${thread['tid'] ?? ''}';
    final ownerId = '${thread['authorid'] ?? ''}';
    final page = int.tryParse('${variables['page'] ?? 1}') ?? 1;
    final chapters = <CatChapter>[];
    var ownerIndex = 0;
    for (final post in _postList(
      variables,
    ).cast<Map<String, dynamic>?>().whereType<Map<String, dynamic>>()) {
      if (ownerId.isNotEmpty && '${post['authorid'] ?? ''}' != ownerId) {
        continue;
      }
      final message = '${post['message'] ?? ''}';
      if (_htmlToText(message).isEmpty && _extractImages(message).isEmpty) {
        continue;
      }
      ownerIndex += 1;
      final number = int.tryParse(
        '${post['number'] ?? post['position'] ?? ''}',
      );
      chapters.add(
        CatChapter(
          title: number == null ? '第 $page 页 · 楼主 $ownerIndex' : '第 $number 楼',
          cid: SourceId.yamiboCid(tid, page, ownerIndex),
        ),
      );
    }
    return chapters;
  }

  static Content getThreadContent(
    String jsonText, {
    String? authorId,
    int? postIndex,
  }) {
    final variables = _variables(jsonText);
    final thread = variables['thread'] as Map<String, dynamic>? ?? {};
    final ownerId = authorId?.isNotEmpty == true
        ? authorId!
        : '${thread['authorid'] ?? ''}';
    final posts = _postList(
      variables,
    ).cast<Map<String, dynamic>?>().whereType<Map<String, dynamic>>();
    final authorPosts = posts.where(
      (post) => ownerId.isEmpty || '${post['authorid'] ?? ''}' == ownerId,
    );

    final texts = <String>[];
    final images = <String>[];
    var ownerIndex = 0;
    for (final post in authorPosts) {
      final message = '${post['message'] ?? ''}';
      ownerIndex += 1;
      if (postIndex != null && ownerIndex != postIndex) continue;
      final text = _htmlToText(message);
      if (text.isNotEmpty) texts.add(text);
      images.addAll(_extractImages(message));
    }

    if (postIndex != null && texts.isEmpty && images.isEmpty) {
      return getThreadContent(jsonText, authorId: authorId);
    }

    return Content(text: texts.join('\n\n'), images: images);
  }

  static YamiboFavoritePageData getFavoritePageData(String jsonText) {
    final variables = _variables(jsonText);
    final list = variables['list'];
    final count = int.tryParse('${variables['count'] ?? 0}') ?? 0;
    final perPage = int.tryParse('${variables['perpage'] ?? 0}') ?? 0;
    if (list is! List) {
      return YamiboFavoritePageData(items: [], count: count, perPage: perPage);
    }

    final items = list
        .whereType<Map<String, dynamic>>()
        .map((item) {
          final tid = '${item['id'] ?? item['tid'] ?? ''}';
          final title = '${item['title'] ?? item['subject'] ?? 'Yamibo'}'
              .trim();
          final favId =
              '${item['favid'] ?? item['favId'] ?? SourceId.yamiboAid(tid)}';
          final updateKey =
              '${item['lastpost'] ?? item['dateline'] ?? item['time'] ?? ''}';
          return BookshelfNovelInfo(
            bid: favId,
            aid: SourceId.yamiboAid(tid),
            url: YamiboApi.threadUrl(tid),
            title: title.isEmpty ? 'Yamibo $tid' : title,
            img: '',
            updateKey: updateKey,
            updateTime:
                _parseUnixSeconds(item['lastpost']) ??
                _parseUnixSeconds(item['dateline']),
            remoteTags: ['Yamibo', ...titleTags(title)],
          );
        })
        .where((item) => SourceId.yamiboTid(item.aid).isNotEmpty)
        .toList();
    return YamiboFavoritePageData(items: items, count: count, perPage: perPage);
  }

  static List<BookshelfNovelInfo> getFavorites(String jsonText) {
    return getFavoritePageData(jsonText).items;
  }

  static YamiboForumPageData getForumPageData(String jsonText) {
    final json = jsonDecode(jsonText) as Map<String, dynamic>;
    final variables = json['Variables'] as Map<String, dynamic>? ?? {};
    final forum = variables['forum'] as Map<String, dynamic>? ?? {};
    final threadTypes = variables['threadtypes'] as Map<String, dynamic>? ?? {};
    final message = json['Message'] is Map<String, dynamic>
        ? '${(json['Message'] as Map<String, dynamic>)['messageval'] ?? ''}'
        : null;

    final typesRaw = threadTypes['types'];
    final typeEntries = typesRaw is Map
        ? typesRaw.entries
        : const Iterable<MapEntry<dynamic, dynamic>>.empty();
    final types = typeEntries
        .map(
          (entry) => YamiboForumType(
            id: '${entry.key}',
            title: _htmlToText('${entry.value}'),
          ),
        )
        .where((item) => item.id.isNotEmpty && item.title.isNotEmpty)
        .toList();

    final threadList = variables['forum_threadlist'];
    final threads = threadList is List
        ? threadList
              .whereType<Map<String, dynamic>>()
              .map(_forumThread)
              .where((item) => item.tid.isNotEmpty)
              .toList()
        : <YamiboForumThread>[];

    return YamiboForumPageData(
      fid: '${forum['fid'] ?? ''}',
      forumName: '${forum['name'] ?? 'Yamibo'}'.trim(),
      page: int.tryParse('${variables['page'] ?? 1}') ?? 1,
      perPage: int.tryParse('${variables['tpp'] ?? 20}') ?? 20,
      threadCount: int.tryParse('${forum['threads'] ?? 0}') ?? 0,
      types: types,
      threads: threads,
      message: message?.isEmpty == true ? null : message,
    );
  }

  static YamiboUserThreadPageData getUserThreadPageData(
    String html, {
    required String authorName,
  }) {
    final document = parse(html);
    final threads = <YamiboForumThread>[];
    final seen = <String>{};

    final links = document.querySelectorAll(
      'a[href*="thread-"], a[href*="mod=viewthread"], a[href*="tid="]',
    );
    for (final link in links) {
      final href = link.attributes['href'] ?? '';
      final tid = YamiboApi.extractTid(href);
      final title = _htmlToText(link.text);
      if (tid == null || title.isEmpty || !seen.add(tid)) continue;
      if (_isNavigationLink(title)) continue;

      final row = _threadRow(link);
      threads.add(
        YamiboForumThread(
          tid: tid,
          title: title,
          author: authorName,
          lastPoster: '',
          typeId: '',
          replies: _firstNumber(row, const ['回复', '回覆', 'reply']) ?? 0,
          views: _firstNumber(row, const ['查看', '浏览', '瀏覽', 'view']) ?? 0,
          lastPostTime: _parseDateText(row?.text ?? ''),
          isTop: false,
          isDigest: row?.text.contains('精华') == true,
        ),
      );
    }

    return YamiboUserThreadPageData(
      threads: threads,
      hasMore: _hasNextPage(document),
    );
  }

  static YamiboSearchPageData getSearchPageData(
    String html, {
    Set<String>? allowedForumIds,
  }) {
    final document = parse(html);
    final items = <NovelCover>[];
    final seen = <String>{};

    final links = document.querySelectorAll(
      'a[href*="thread-"], a[href*="mod=viewthread"], a[href*="tid="]',
    );
    for (final link in links) {
      final href = link.attributes['href'] ?? '';
      final tid = YamiboApi.extractTid(href);
      final title = _htmlToText(link.text);
      if (tid == null || title.isEmpty || !seen.add(tid)) continue;
      if (_isNavigationLink(title) || _isSearchNoiseTitle(title)) continue;
      final row = _threadRow(link);
      if (allowedForumIds != null &&
          allowedForumIds.isNotEmpty &&
          !_rowHasForumId(row, allowedForumIds)) {
        continue;
      }

      items.add(NovelCover(title, '', SourceId.yamiboAid(tid)));
    }

    return YamiboSearchPageData(
      items: items,
      hasMore: _hasNextPage(document),
      searchId: _extractSearchId(document),
    );
  }

  static bool _isNavigationLink(String title) {
    final normalized = title.trim().toLowerCase();
    return normalized.isEmpty ||
        normalized == '下一页' ||
        normalized == '下一頁' ||
        normalized == '上一页' ||
        normalized == '上一頁' ||
        normalized == '返回列表' ||
        normalized == 'next' ||
        normalized == 'prev';
  }

  static bool _isSearchNoiseTitle(String title) {
    final normalized = title.trim().toLowerCase();
    return normalized == '查看完整版本' ||
        normalized == 'forum' ||
        normalized == 'yamibo' ||
        normalized.contains('搜索') ||
        normalized.contains('搜尋');
  }

  static Element? _threadRow(Element link) {
    Element? current = link;
    for (var i = 0; i < 5 && current != null; i++) {
      if (current.localName == 'li' || current.localName == 'tr') {
        return current;
      }
      current = current.parent;
    }
    return link.parent;
  }

  static bool _rowHasForumId(Element? row, Set<String> allowedForumIds) {
    if (row == null) return false;
    final links = row.querySelectorAll('a[href*="fid="], a[href*="forum-"]');
    for (final link in links) {
      final href = link.attributes['href'] ?? '';
      final fid =
          RegExp(r'[?&]fid=(\d+)').firstMatch(href)?.group(1) ??
          RegExp(r'forum-(\d+)-').firstMatch(href)?.group(1);
      if (fid != null && allowedForumIds.contains(fid)) return true;
    }
    return false;
  }

  static int? _firstNumber(Element? root, List<String> labels) {
    if (root == null) return null;
    final text = root.text;
    for (final label in labels) {
      final match = RegExp('$label\\D*(\\d+)').firstMatch(text);
      final value = int.tryParse(match?.group(1) ?? '');
      if (value != null) return value;
    }
    return null;
  }

  static DateTime? _parseDateText(String text) {
    final match = RegExp(
      r'(\d{4})[-/](\d{1,2})[-/](\d{1,2})(?:\s+(\d{1,2}):(\d{1,2}))?',
    ).firstMatch(text);
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.tryParse(match.group(4) ?? '') ?? 0,
      int.tryParse(match.group(5) ?? '') ?? 0,
    );
  }

  static bool _hasNextPage(Document document) {
    return document
        .querySelectorAll('a')
        .any((link) => link.text.trim().contains(RegExp(r'下一[页頁]|next')));
  }

  static String? _extractSearchId(Document document) {
    for (final link in document.querySelectorAll('a[href*="searchid="]')) {
      final href = link.attributes['href'] ?? '';
      final id = RegExp(r'[?&]searchid=(\d+)').firstMatch(href)?.group(1);
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  static YamiboForumThread _forumThread(Map<String, dynamic> item) {
    final tid = '${item['tid'] ?? ''}';
    final title = _htmlToText(
      '${item['subject'] ?? item['title'] ?? 'Yamibo $tid'}',
    );
    final displayOrder = int.tryParse('${item['displayorder'] ?? 0}') ?? 0;
    final digest = int.tryParse('${item['digest'] ?? 0}') ?? 0;
    return YamiboForumThread(
      tid: tid,
      title: title.isEmpty ? 'Yamibo $tid' : title,
      author: '${item['author'] ?? ''}'.trim(),
      lastPoster: '${item['lastposter'] ?? ''}'.trim(),
      typeId: '${item['typeid'] ?? ''}',
      replies: int.tryParse('${item['replies'] ?? 0}') ?? 0,
      views: int.tryParse('${item['views'] ?? 0}') ?? 0,
      lastPostTime:
          _parseUnixSeconds(item['lastpost']) ??
          _parseUnixSeconds(item['dateline']) ??
          _parseUnixSeconds(item['dbdateline']),
      isTop: displayOrder > 0,
      isDigest: digest > 0,
    );
  }

  static Map<String, dynamic> _variables(String jsonText) {
    final json = jsonDecode(jsonText) as Map<String, dynamic>;
    return json['Variables'] as Map<String, dynamic>? ?? {};
  }

  static List<dynamic> _postList(Map<String, dynamic> variables) =>
      variables['postlist'] as List<dynamic>? ?? [];

  static DateTime? _parseUnixSeconds(Object? value) {
    final seconds = int.tryParse('$value');
    if (seconds == null || seconds <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }

  static String _htmlToText(String html) {
    final doc = parse('<div>$html</div>');
    doc.querySelectorAll('i, script, style').forEach((e) => e.remove());
    final normalized =
        doc.body?.innerHtml
            .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
            .replaceAll(RegExp(r'</(p|div)>', caseSensitive: false), '\n\n') ??
        '';
    return parse(normalized).documentElement?.text
            .replaceAll('\u00a0', ' ')
            .replaceAll(RegExp(r'\n{3,}'), '\n\n')
            .trim() ??
        '';
  }

  static List<String> _extractImages(String html) {
    final doc = parse('<div>$html</div>');
    return doc.querySelectorAll('img').map(_imageUrl).where((url) {
      if (url.isEmpty) return false;
      final lower = url.toLowerCase();
      return !lower.contains('smiley/') &&
          !lower.contains('static/image/smiley') &&
          !lower.contains('avatar') &&
          !lower.contains('/static/image/common/logo') &&
          !lower.contains('discuz') &&
          !lower.contains('community');
    }).toList();
  }

  static String _imageUrl(Element element) {
    var src =
        element.attributes['zoomfile'] ??
        element.attributes['file'] ??
        element.attributes['src'] ??
        '';
    if (src.isEmpty) return '';
    src = src.replaceAll('&amp;', '&');
    if (src.startsWith('//')) return 'https:$src';
    if (src.startsWith('http://') || src.startsWith('https://')) return src;
    return '${YamiboApi.baseUrl}/${src.replaceFirst(RegExp(r'^/+'), '')}';
  }
}
