import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hikari_novel_flutter/models/resource.dart';
import 'package:hikari_novel_flutter/service/local_storage_service.dart';

import 'request.dart';

class YamiboSearchPageResponse {
  const YamiboSearchPageResponse({
    required this.html,
    required this.page,
    this.searchId,
  });

  final String html;
  final int page;
  final String? searchId;
}

class YamiboApi {
  static const baseUrl = 'https://bbs.yamibo.com';
  static const logoUrl = '$baseUrl/static/image/common/logo.png';
  static const literatureFid = '49';
  static const lightNovelFid = '55';
  static const txtNovelFid = '60';

  static Future<Resource> getForumPage({
    String fid = literatureFid,
    int page = 1,
    String? typeId,
  }) {
    final params = {
      'module': 'forumdisplay',
      'version': '1',
      'fid': fid,
      'page': '$page',
      if (typeId != null && typeId.isNotEmpty) ...{
        'filter': 'typeid',
        'typeid': typeId,
      },
    };
    final uri = Uri.parse(
      '$baseUrl/api/mobile/index.php',
    ).replace(queryParameters: params);
    return Request.getUtf8(uri.toString(), headers: _headers());
  }

  static Future<Resource> getThreadPage({
    required String tid,
    int page = 1,
    String? authorId,
  }) {
    final params = {
      'module': 'viewthread',
      'version': '1',
      'tid': tid,
      'page': '$page',
      if (authorId != null && authorId.isNotEmpty) 'authorid': authorId,
    };
    final uri = Uri.parse(
      '$baseUrl/api/mobile/index.php',
    ).replace(queryParameters: params);
    return Request.getUtf8(uri.toString(), headers: _headers());
  }

  static Future<Resource> getFavoritePage({int page = 1}) {
    final uri = Uri.parse('$baseUrl/api/mobile/index.php').replace(
      queryParameters: {
        'module': 'myfavthread',
        'version': '1',
        'page': '$page',
      },
    );
    return Request.getUtf8(uri.toString(), headers: _headers());
  }

  static Future<Resource> getUserThreadPage({
    required String uid,
    int page = 1,
  }) {
    final uri = Uri.parse('$baseUrl/home.php').replace(
      queryParameters: {
        'mod': 'space',
        'uid': uid,
        'do': 'thread',
        'view': 'me',
        'from': 'space',
        'mobile': '2',
        'page': '$page',
      },
    );
    return Request.getUtf8(uri.toString(), headers: _headers());
  }

  static Future<Resource> searchThreads({
    required String keyword,
    int page = 1,
    String? searchId,
    List<String> forumIds = const [literatureFid, lightNovelFid, txtNovelFid],
    String orderBy = 'dateline',
    String ascDesc = 'desc',
    String searchFrom = '0',
    bool titleOnly = false,
  }) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return const Success('');

    if (searchId != null && searchId.isNotEmpty) {
      return _getSearchResultPage(
        keyword: trimmed,
        searchId: searchId,
        page: page,
        orderBy: orderBy,
        ascDesc: ascDesc,
      );
    }

    if (page > 1) return const Success('');

    try {
      final form = await Request.dio.get<List<int>>(
        '$baseUrl/search.php?mod=forum',
        options: Options(headers: _headers(), responseType: ResponseType.bytes),
      );
      final formHtml = utf8.decode(form.data ?? const <int>[]);
      final formhash = _extractFormhash(formHtml);
      final searchForm = {
        'mod': 'forum',
        'srchtxt': trimmed,
        'searchsubmit': 'yes',
        'srchfid[]': forumIds.isEmpty
            ? const [literatureFid, lightNovelFid, txtNovelFid]
            : forumIds,
        'srchfrom': searchFrom,
        'orderby': orderBy,
        'ascdesc': ascDesc,
      };
      if (titleOnly) searchForm['srchtype'] = 'title';
      if (formhash != null) searchForm['formhash'] = formhash;
      final uri = Uri.parse(
        '$baseUrl/search.php',
      ).replace(queryParameters: searchForm);

      final response = await Request.dio.get<List<int>>(
        uri.toString(),
        options: Options(
          headers: _headers(),
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );
      final html = utf8.decode(response.data ?? const <int>[]);
      final id =
          response.realUri.queryParameters['searchid'] ??
          _extractSearchId(response.realUri.toString()) ??
          _extractSearchId(html);
      return Success(
        YamiboSearchPageResponse(html: html, page: 1, searchId: id),
      );
    } catch (e) {
      return Error(e.toString());
    }
  }

  static bool get hasCookie {
    return isAuthenticatedCookie(
      LocalStorageService.instance.getYamiboCookie(),
    );
  }

  static bool isAuthenticatedCookie(String? cookie) {
    return cookie != null && cookie.contains('EeqY_2132_auth=');
  }

  static String threadUrl(String tid) =>
      '$baseUrl/forum.php?mod=viewthread&tid=$tid&mobile=2';

  static Future<Resource> _getSearchResultPage({
    required String keyword,
    required String searchId,
    required int page,
    required String orderBy,
    required String ascDesc,
  }) async {
    final uri = Uri.parse('$baseUrl/search.php').replace(
      queryParameters: {
        'mod': 'forum',
        'searchid': searchId,
        'orderby': orderBy,
        'ascdesc': ascDesc,
        'searchsubmit': 'yes',
        'kw': keyword,
        if (page > 1) 'page': '$page',
      },
    );
    final result = await Request.getUtf8(uri.toString(), headers: _headers());
    return switch (result) {
      Success() => Success(
        YamiboSearchPageResponse(
          html: result.data,
          page: page,
          searchId: searchId,
        ),
      ),
      Error() => result,
    };
  }

  static Map<String, String> _headers() {
    final cookie = LocalStorageService.instance.getYamiboCookie();
    return {
      'Referer': baseUrl,
      if (cookie != null && cookie.isNotEmpty) 'Cookie': cookie,
    };
  }

  static String? _extractFormhash(String html) {
    return RegExp(
          r'''name=["']formhash["']\s+value=["']([^"']+)["']''',
          caseSensitive: false,
        ).firstMatch(html)?.group(1) ??
        RegExp(
          r'''value=["']([^"']+)["']\s+name=["']formhash["']''',
          caseSensitive: false,
        ).firstMatch(html)?.group(1) ??
        RegExp(r'formhash=([a-zA-Z0-9]+)').firstMatch(html)?.group(1);
  }

  static String? _extractSearchId(String text) =>
      RegExp(r'[?&]searchid=(\d+)').firstMatch(text)?.group(1);

  static String? extractTid(String input) {
    final trimmed = input.trim();
    if (RegExp(r'^\d+$').hasMatch(trimmed)) return trimmed;

    final tidFromQuery = RegExp(r'[?&]tid=(\d+)').firstMatch(trimmed)?.group(1);
    if (tidFromQuery != null) return tidFromQuery;

    return RegExp(r'thread-(\d+)-').firstMatch(trimmed)?.group(1);
  }
}
