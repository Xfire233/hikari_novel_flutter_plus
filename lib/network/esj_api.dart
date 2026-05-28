import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hikari_novel_flutter/models/resource.dart';
import 'package:hikari_novel_flutter/service/local_storage_service.dart';

import 'request.dart';

class EsjApi {
  static const baseUrl = 'https://www.esjzone.one';
  static const logoUrl =
      'https://img.kookapp.cn/assets/2023-01/rhv1ugUjQw0dd0ef.png';

  static Future<Resource> searchNovel({
    required String keyword,
    required int page,
    int type = 0,
    int sort = 1,
  }) {
    final encodedKeyword = Uri.encodeComponent(keyword.trim());
    return Request.getUtf8(
      '$baseUrl/tags-$type$sort/$encodedKeyword/$page.html',
      headers: _headers(),
      useCookieJar: false,
    );
  }

  static Future<Resource> getNovelList({
    required int type,
    required int sort,
    required int page,
  }) => Request.getUtf8(
    '$baseUrl/list-$type$sort/$page.html',
    headers: _headers(),
    useCookieJar: false,
  );

  static Future<Resource> getNovelDetail({required String id}) =>
      Request.getUtf8(detailUrl(id), headers: _headers(), useCookieJar: false);

  static Future<Resource> getChapter({
    required String bookId,
    required String chapterId,
  }) => Request.getUtf8(
    chapterUrl(bookId, chapterId),
    headers: _headers(),
    useCookieJar: false,
  );

  static Future<Resource> getFavoritePage({int page = 1}) => Request.getUtf8(
    '$baseUrl/my/favorite/udate/$page',
    headers: _headers(),
    useCookieJar: false,
  );

  static Future<Resource> getViewHistory() => Request.getUtf8(
    '$baseUrl/my/view',
    headers: _headers(),
    useCookieJar: false,
  );

  static Future<Resource> toggleFavorite({required String bookId}) async {
    final token = await _getAuthToken(path: '/detail/$bookId');
    if (token == null || token.isEmpty) return Error('ESJ auth token missing');
    try {
      final response = await Request.manualCookieDio.post(
        '$baseUrl/inc/mem_favorite.php',
        options: Options(
          headers: {..._headers(), 'Authorization': token},
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );
      final raw = response.data;
      final text = raw is List<int> ? utf8.decode(raw) : raw.toString();
      final data = jsonDecode(text) as Map<String, dynamic>;
      if (data['status'] == 200) return Success(data);
      return Error('${data['msg'] ?? 'ESJ favorite failed'}');
    } catch (e) {
      return Error(e.toString());
    }
  }

  static Future<String?> _getAuthToken({required String path}) async {
    try {
      final response = await Request.manualCookieDio.post(
        '$baseUrl$path',
        data: FormData.fromMap({'plxf': 'getAuthToken'}),
        options: Options(
          headers: _headers(),
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );
      final raw = response.data;
      final text = raw is List<int> ? utf8.decode(raw) : raw.toString();
      return RegExp(r'<JinJing>(.*?)</JinJing>').firstMatch(text)?.group(1);
    } catch (_) {
      return null;
    }
  }

  static String detailUrl(String id) => '$baseUrl/detail/$id.html';

  static String chapterUrl(String bookId, String chapterId) =>
      '$baseUrl/forum/$bookId/$chapterId.html';

  static String tagUrl(
    String tag, {
    int type = 0,
    int sort = 1,
    int page = 1,
  }) =>
      '$baseUrl/tags-$type$sort/${Uri.encodeComponent(tag.trim())}/$page.html';

  static String? extractBookId(String input) {
    final trimmed = input.trim();
    if (RegExp(r'^\d+$').hasMatch(trimmed)) return trimmed;
    return RegExp(r'/detail/(\d+)\.html').firstMatch(trimmed)?.group(1);
  }

  static bool get hasCookie {
    final storage = LocalStorageService.instance;
    return storage.getEsjLoginVerified() &&
        (storage.getEsjCookie()?.trim().isNotEmpty == true);
  }

  static bool isAuthenticatedCookie(String? cookie) {
    if (cookie == null || cookie.trim().isEmpty) return false;
    final names = cookie
        .split(';')
        .map((part) => part.split('=').first.trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toSet();
    names.removeAll({
      'ews_key',
      'ews_token',
      'msg_alert',
      'hidden',
      '_ga',
      '_gid',
      '_gat',
      '_ga_6n355xr0y6',
    });
    return names.any(
      (name) =>
          name.contains('auth') ||
          name.contains('member') ||
          name.contains('remember') ||
          name.contains('user') ||
          name.contains('login') ||
          name.contains('session'),
    );
  }

  static bool isAuthenticatedAccountUrl(String? url) {
    final uri = Uri.tryParse(url?.trim() ?? '');
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    if (host != 'www.esjzone.one' && host != 'esjzone.one') return false;
    final path = uri.path.toLowerCase();
    return path == '/my/profile' ||
        path == '/my/view' ||
        path.startsWith('/my/favorite/');
  }

  static Map<String, String> _headers() {
    final cookie = LocalStorageService.instance.getEsjCookie();
    return {
      'Referer': baseUrl,
      if (cookie != null && cookie.isNotEmpty) 'Cookie': cookie,
    };
  }
}
