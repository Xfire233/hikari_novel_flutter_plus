import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:hikari_novel_flutter/network/api.dart';
import 'package:hikari_novel_flutter/network/esj_api.dart';
import 'package:hikari_novel_flutter/network/request.dart';
import 'package:hikari_novel_flutter/network/yamibo_api.dart';
import 'package:hikari_novel_flutter/network/yamibo_parser.dart';
import 'package:path_provider/path_provider.dart';

import '../common/log.dart';
import '../models/resource.dart';
import '../models/source_id.dart';
import '../service/local_storage_service.dart';

class ChapterDownloader {
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, bool> _downloadingStatus = {};

  void cancel(String taskId) {
    final token = _cancelTokens[taskId];
    if (token != null && !token.isCancelled) {
      try {
        token.cancel('canceled');
        Log.d('Cache task $taskId canceled');
      } catch (e) {
        Log.e('Cancel cache task $taskId failed: $e');
      }
    }
    _cancelTokens.remove(taskId);
    _downloadingStatus.remove(taskId);
  }

  void clearCancel(String taskId) {
    _cancelTokens.remove(taskId);
    _downloadingStatus.remove(taskId);
  }

  bool isDownloading(String taskId) => _downloadingStatus[taskId] ?? false;

  bool isCanceled(String taskId) => _cancelTokens[taskId]?.isCancelled ?? false;

  Future<String> download({
    required String taskId,
    required String aid,
    required String cid,
    Function(int received, int total)? onProgress,
  }) async {
    if (isDownloading(taskId)) {
      throw Exception('Task $taskId is already downloading');
    }
    if (isCanceled(taskId)) {
      throw Exception('canceled');
    }

    _downloadingStatus[taskId] = true;
    final cancelToken = CancelToken();
    _cancelTokens[taskId] = cancelToken;

    try {
      final dir = await getApplicationSupportDirectory();
      final cacheDir = Directory('${dir.path}/cached_chapter');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      final savePath =
          '${cacheDir.path}/${SourceId.safeFilePart(aid)}_${SourceId.safeFilePart(cid)}.txt';
      final file = File(savePath);
      if (await file.exists() && await file.length() > 0) {
        Log.d('Chapter $aid-$cid already cached: $savePath');
        return savePath;
      }

      final content = SourceId.isYamibo(aid)
          ? await _downloadYamiboChapter(
              aid: aid,
              cid: cid,
              cancelToken: cancelToken,
              onProgress: onProgress,
            )
          : SourceId.isEsj(aid)
          ? await _downloadEsjChapter(
              aid: aid,
              cid: cid,
              cancelToken: cancelToken,
              onProgress: onProgress,
            )
          : await _downloadWenku8Chapter(
              aid: aid,
              cid: cid,
              cancelToken: cancelToken,
              onProgress: onProgress,
            );

      if (cancelToken.isCancelled) throw Exception('canceled');
      await file.writeAsString(content, flush: true);
      onProgress?.call(1, 1);
      Log.d('Chapter $aid-$cid cached: $savePath');
      return savePath;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        Log.e('Cache task $taskId canceled: ${e.message}');
        throw Exception('canceled');
      }
      Log.e('Cache task $taskId failed: ${e.message}');
      rethrow;
    } catch (e) {
      Log.e('Cache task $taskId failed: $e');
      rethrow;
    } finally {
      _downloadingStatus.remove(taskId);
      _cancelTokens.remove(taskId);
    }
  }

  void cancelAll() {
    _cancelTokens.keys.toList().forEach(cancel);
    _cancelTokens.clear();
    _downloadingStatus.clear();
  }

  void dispose() {
    cancelAll();
  }

  Future<String> _downloadWenku8Chapter({
    required String aid,
    required String cid,
    required CancelToken cancelToken,
    Function(int received, int total)? onProgress,
  }) async {
    if (cancelToken.isCancelled) throw Exception('canceled');
    onProgress?.call(0, 1);
    final result = await Api.getNovelContent(
      aid: aid,
      cid: cid,
      cancelToken: cancelToken,
    );
    if (cancelToken.isCancelled) throw Exception('canceled');
    return switch (result) {
      Success() => result.data as String,
      Error() => throw Exception(result.error.toString()),
    };
  }

  Future<String> _downloadEsjChapter({
    required String aid,
    required String cid,
    required CancelToken cancelToken,
    Function(int received, int total)? onProgress,
  }) async {
    final headers = {...Request.userAgent, 'Referer': EsjApi.baseUrl};
    final cookie = LocalStorageService.instance.getEsjCookie();
    if (cookie != null && cookie.isNotEmpty) headers['Cookie'] = cookie;
    final response = await Request.manualCookieDio.get(
      EsjApi.chapterUrl(SourceId.esjBookId(aid), SourceId.esjChapterId(cid)),
      cancelToken: cancelToken,
      options: Options(headers: headers, responseType: ResponseType.plain),
      onReceiveProgress: onProgress,
    );
    if (cancelToken.isCancelled) {
      throw DioException(
        requestOptions: response.requestOptions,
        type: DioExceptionType.cancel,
        message: 'canceled',
      );
    }
    return response.data as String;
  }

  Future<String> _downloadYamiboChapter({
    required String aid,
    required String cid,
    required CancelToken cancelToken,
    Function(int received, int total)? onProgress,
  }) async {
    final tid = SourceId.yamiboTid(aid);
    String? authorId;

    final firstPage = await _downloadYamiboThreadPage(
      tid: tid,
      page: 1,
      cancelToken: cancelToken,
    );
    if (cancelToken.isCancelled) throw Exception('canceled');

    try {
      authorId = YamiboParser.getThreadDetail(firstPage).authorId;
    } catch (e) {
      Log.e('Yamibo author id parse failed: $e');
    }

    return _downloadYamiboThreadPage(
      tid: tid,
      page: SourceId.yamiboPage(cid),
      authorId: authorId,
      cancelToken: cancelToken,
      onProgress: onProgress,
    );
  }

  Future<String> _downloadYamiboThreadPage({
    required String tid,
    required int page,
    String? authorId,
    required CancelToken cancelToken,
    Function(int received, int total)? onProgress,
  }) async {
    final params = {
      'module': 'viewthread',
      'version': '1',
      'tid': tid,
      'page': '$page',
      if (authorId != null && authorId.isNotEmpty) 'authorid': authorId,
    };
    final uri = Uri.parse(
      '${YamiboApi.baseUrl}/api/mobile/index.php',
    ).replace(queryParameters: params);
    final headers = {...Request.userAgent, 'Referer': YamiboApi.baseUrl};
    final cookie = LocalStorageService.instance.getYamiboCookie();
    if (cookie != null && cookie.isNotEmpty) headers['Cookie'] = cookie;

    final response = await Request.manualCookieDio.get(
      uri.toString(),
      cancelToken: cancelToken,
      options: Options(
        headers: headers,
        responseType: ResponseType.bytes,
        followRedirects: true,
      ),
      onReceiveProgress: onProgress,
    );
    if (cancelToken.isCancelled) {
      throw DioException(
        requestOptions: response.requestOptions,
        type: DioExceptionType.cancel,
        message: 'canceled',
      );
    }
    return utf8.decode(response.data as List<int>);
  }
}
