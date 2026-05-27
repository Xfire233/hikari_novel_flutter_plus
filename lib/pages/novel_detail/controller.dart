import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/common/constants.dart';
import 'package:hikari_novel_flutter/common/extension.dart';
import 'package:hikari_novel_flutter/common/log.dart';
import 'package:hikari_novel_flutter/models/book_tags.dart';
import 'package:hikari_novel_flutter/models/chapter_cache_task.dart';
import 'package:hikari_novel_flutter/models/common/wenku8_node.dart';
import 'package:hikari_novel_flutter/models/novel_detail.dart';
import 'package:hikari_novel_flutter/models/reader_direction.dart';
import 'package:hikari_novel_flutter/models/source_config.dart';
import 'package:hikari_novel_flutter/models/source_id.dart';
import 'package:hikari_novel_flutter/network/esj_api.dart';
import 'package:hikari_novel_flutter/network/esj_parser.dart';
import 'package:hikari_novel_flutter/network/parser.dart';
import 'package:hikari_novel_flutter/network/yamibo_api.dart';
import 'package:hikari_novel_flutter/network/yamibo_parser.dart';
import 'package:hikari_novel_flutter/pages/bookshelf/controller.dart';
import 'package:hikari_novel_flutter/pages/cache_queue/controller.dart';
import 'package:hikari_novel_flutter/router/app_sub_router.dart';
import 'package:hikari_novel_flutter/widgets/state_page.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../common/database/database.dart';
import '../../models/cat_chapter.dart';
import '../../models/cat_volume.dart';
import '../../models/dual_page_mode.dart';
import '../../models/page_state.dart';
import '../../models/resource.dart';
import '../../network/api.dart';
import '../../service/db_service.dart';
import '../../service/local_storage_service.dart';
import '../../service/source_auth_guard.dart';
import '../../service/source_config_service.dart';
import '../../service/source_favorite_adapter.dart';

class NovelDetailController extends GetxController
    with GetSingleTickerProviderStateMixin {
  static const _yamiboOwnerVolumeTitle = '楼主楼层';
  static const _yamiboOwnerUpdateSeparator = '\nowner:';

  final String aid;
  final String seedTitle;
  final String? seedImageUrl;

  bool get isYamibo => SourceId.isYamibo(aid);

  bool get isEsj => SourceId.isEsj(aid);

  String get yamiboTid => SourceId.yamiboTid(aid);

  String get esjBookId => SourceId.esjBookId(aid);

  NovelDetailController({
    required this.aid,
    this.seedTitle = '',
    this.seedImageUrl,
  });

  Rx<PageState> pageState = PageState.loading.obs;
  String errorMsg = "";
  RxString loadingMessage = ''.obs;
  Rxn<NovelDetail> novelDetail = Rxn();

  RxSet<String> cachedChapter = RxSet();

  RxBool isInBookshelf = false.obs;
  RxDouble localRating = 0.0.obs;
  RxList<String> remoteTags = RxList();
  RxList<String> localTags = RxList();

  RxBool isChapterOrderReversed = false.obs;

  RxBool isSelectionMode = false.obs;
  String yamiboAuthorId = "";
  RxBool yamiboCatalogueBuilding = false.obs;
  RxString yamiboCatalogueStatus = ''.obs;

  bool _isFabVisible = true;
  late final AnimationController _fabAnimationCtr;
  late final Animation<Offset> animation;

  final bookshelfController = Get.find<BookshelfController>();
  final cacheQueueController = Get.findOrPut(() => CacheQueueController());

  late final Directory _supportDir;

  @override
  void onInit() {
    super.onInit();
    _fabAnimationCtr = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..forward();
    animation = _fabAnimationCtr.drive(
      Tween<Offset>(
        begin: const Offset(0.0, 2.0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeInOut)),
    );
  }

  @override
  void onReady() async {
    super.onReady();
    _supportDir = await getApplicationSupportDirectory();
    getNovelDetail();
  }

  @override
  void onClose() {
    _fabAnimationCtr.dispose();
    super.onClose();
  }

  void showFab() {
    if (!_isFabVisible) {
      _isFabVisible = true;
      _fabAnimationCtr.forward();
    }
  }

  void hideFab() {
    if (_isFabVisible) {
      _isFabVisible = false;
      _fabAnimationCtr.reverse();
    }
  }

  void enterSelectionMode() => isSelectionMode.value = true;

  void exitSelectionMode() {
    isSelectionMode.value = false;
    deselect();
  }

  void toggleChapterSelection(int volumeIndex, int chapterIndex) {
    final chapter =
        novelDetail.value!.catalogue[volumeIndex].chapters[chapterIndex];
    chapter.isSelected.toggle();
    _syncVolumeSelection(volumeIndex);
  }

  //鍒囨崲鏌愬嵎锛堝叏閮ㄩ€変腑鎴栧叏閮ㄥ彇娑堬級
  void toggleVolumeSelection(int volumeIndex) {
    final volume = novelDetail.value!.catalogue[volumeIndex];
    final allSelected = volume.chapters.every((c) => c.isSelected.value);
    for (final c in volume.chapters) {
      c.isSelected.value = !allSelected;
    }
    volume.isSelected.value = !allSelected;
  }

  void _syncVolumeSelection(int volumeIndex) {
    final volume = novelDetail.value!.catalogue[volumeIndex];
    final total = volume.chapters.length;
    final selected = volume.chapters.where((c) => c.isSelected.value).length;
    if (selected == 0) {
      volume.isSelected.value = false;
    } else if (selected == total) {
      volume.isSelected.value = true;
    } else {
      volume.isSelected.value = false;
    }
  }

  List<CatChapter> getSelectedChapters() {
    final out = <CatChapter>[];
    final detail = novelDetail.value;
    if (detail == null) return out;
    for (final vol in detail.catalogue) {
      for (final ch in vol.chapters) {
        if (ch.isSelected.value) out.add(ch);
      }
    }
    return out;
  }

  int getSelectedCount() => getSelectedChapters().length;

  void deselect() {
    final detail = novelDetail.value;
    if (detail == null) return;
    for (final vol in detail.catalogue) {
      vol.isSelected.value = false;
      for (final ch in vol.chapters) {
        ch.isSelected.value = false;
      }
    }
  }

  void selectAll() {
    final detail = novelDetail.value;
    if (detail == null) return;
    for (final vol in detail.catalogue) {
      vol.isSelected.value = true;
      for (final ch in vol.chapters) {
        ch.isSelected.value = true;
      }
    }
  }

  Future<void> startCache() async {
    for (var chap in getSelectedChapters()) {
      final cacheFile = _chapterCacheFile(chap.cid);
      if (await cacheFile.exists() && await cacheFile.length() > 0) {
        cachedChapter.add(chap.cid);
        continue;
      }
      await cacheQueueController.addTask(
        ChapterCacheTask(
          uuid: "${aid}_${chap.cid}",
          aid: aid,
          cid: chap.cid,
          title: chap.title,
          onCompleted: (cid) {
            cachedChapter.add(cid);
          },
        ),
      );
    }
  }

  Future<void> deleteCache() async {
    final asd = await getApplicationSupportDirectory();
    final dir = Directory("${asd.path}/cached_chapter");

    if (!await dir.exists()) {
      return;
    }

    final aidPart = SourceId.safeFilePart(aid);
    await for (var entity in dir.list()) {
      if (entity is File) {
        final fileName = entity.uri.pathSegments.last;
        if (!fileName.startsWith('${aidPart}_')) continue;
        try {
          await entity.delete();
        } catch (e) {
          continue;
        }
        final cidPart = fileName.substring(aidPart.length + 1);
        final cachedCidPart = cidPart.replaceFirst(RegExp(r'\.txt$'), '');
        cachedChapter.removeWhere(
          (cid) => SourceId.safeFilePart(cid) == cachedCidPart,
        );
      }
    }
  }

  void checkIsChapterCached(String cid) async {
    final cacheFile = _chapterCacheFile(cid);
    if (await cacheFile.exists() && await cacheFile.length() > 0) {
      cachedChapter.add(cid);
    } else {
      cachedChapter.remove(cid);
    }
  }

  File _chapterCacheFile(String cid) => File(
    "${_supportDir.path}/cached_chapter/${SourceId.safeFilePart(aid)}_${SourceId.safeFilePart(cid)}.txt",
  );

  Future<void> getNovelDetail() async {
    if (isEsj) {
      await _getEsjNovelDetail();
      return;
    }

    if (isYamibo) {
      await _getYamiboNovelDetail();
      return;
    }

    NovelDetail? data;
    Object? detailError;

    final nd = await Api.getNovelDetail(aid: aid);

    switch (nd) {
      case Success():
        try {
          data = Parser.getNovelDetail(nd.data);
          if (!_hasUsefulWenku8Metadata(data)) {
            detailError = 'Wenku8 articleinfo metadata is empty';
            data = null;
          }
        } catch (e, stackTrace) {
          detailError = e;
          Log.e('HIKARI_WENKU8 detail articleinfo parse failed aid=$aid $e');
          Log.e(stackTrace);
        }
        data ??= await _getWenku8StaticDetail();
        if (data == null && await _getNovelDetailByLocal()) {
          unawaited(_refreshWenku8CatalogueInBackground());
          return;
        }
        data ??= _fallbackNovelDetail();
        await _loadWenku8CatalogueIntoDetail(data, detailError: detailError);
        return;
      case Error():
        {
          //妫€娴嬫湰鍦版槸鍚︽湁缂撳瓨
          data = await _getWenku8StaticDetail();
          if (data != null) {
            await _loadWenku8CatalogueIntoDetail(data, detailError: nd.error);
            return;
          }
          if (await _getNovelDetailByLocal()) {
            unawaited(_refreshWenku8CatalogueInBackground());
            return;
          }
          await _loadWenku8CatalogueIntoDetail(
            _fallbackNovelDetail(),
            detailError: nd.error,
          );
        }
    }
  }

  Future<NovelDetail?> _getWenku8StaticDetail() async {
    final result = await Api.getNovelStaticDetail(aid: aid);
    switch (result) {
      case Success():
        try {
          final data = Parser.getNovelDetail(result.data);
          if (_hasUsefulWenku8Metadata(data)) return data;
        } catch (e, stackTrace) {
          Log.e('Wenku8 static detail parse failed aid=$aid $e');
          Log.e(stackTrace);
        }
      case Error():
        Log.w('Wenku8 static detail failed aid=$aid: ${result.error}');
    }
    return null;
  }

  bool _hasUsefulWenku8Metadata(NovelDetail data) {
    return data.author.trim().isNotEmpty ||
        data.status.trim().isNotEmpty ||
        data.introduce.trim().isNotEmpty ||
        data.tags.isNotEmpty;
  }

  Future<NovelDetail> _mergeCachedWenku8Metadata(NovelDetail data) async {
    if (isEsj || isYamibo) return data;
    final local = (await DBService.instance.getNovelDetail(aid))?.json;
    if (local == null) return data;

    try {
      final cached = NovelDetail.fromString(local);
      final merged = NovelDetail(
        _preferNonEmpty(data.title, cached.title),
        _preferNonEmpty(data.author, cached.author),
        _preferNonEmpty(data.status, cached.status),
        _preferNonEmpty(data.finUpdate, cached.finUpdate),
        _preferNonEmpty(data.imgUrl, cached.imgUrl),
        _preferNonEmpty(data.introduce, cached.introduce),
        BookTags.merge(data.tags, cached.tags),
        _preferNonEmpty(data.heat, cached.heat),
        _preferNonEmpty(data.trending, cached.trending),
        data.isAnimated || cached.isAnimated,
      );
      merged.catalogue
        ..clear()
        ..addAll(data.catalogue);
      return merged;
    } catch (_) {
      return data;
    }
  }

  String _preferNonEmpty(String primary, String fallback) {
    final value = primary.trim();
    return value.isNotEmpty ? primary : fallback;
  }

  Future<void> _loadWenku8CatalogueIntoDetail(
    NovelDetail data, {
    Object? detailError,
  }) async {
    final cat = await Api.getCatalogue(aid: aid);
    switch (cat) {
      case Success():
        try {
          final catalogue = Parser.getCatalogue(cat.data);
          final chapterCount = catalogue.fold<int>(
            0,
            (total, volume) => total + volume.chapters.length,
          );
          if (chapterCount == 0) {
            Log.w(
              'HIKARI_WENKU8 detail catalogue parsed empty aid=$aid '
              'length=${cat.data.length} preview=${_htmlPreview(cat.data)}',
            );
            if (await _getNovelDetailByLocal()) return;
            errorMsg = 'Wenku8 catalogue is empty';
            pageState.value = PageState.error;
            return;
          }
          data.catalogue
            ..clear()
            ..addAll(catalogue);
          data = await _mergeCachedWenku8Metadata(data);
          novelDetail.value = data;

          DBService.instance.upsertBrowsingHistory(
            BrowsingHistoryEntityData(
              aid: aid,
              title: data.title,
              img: data.imgUrl,
              time: DateTime.now(),
            ),
          );

          await _syncLocalBookshelfState();
          if (isInBookshelf.value) {
            await DBService.instance.clearBookshelfUpdate(aid);
          }

          pageState.value = PageState.success;
          await DBService.instance.upsertNovelDetail(
            NovelDetailEntityData(
              aid: aid,
              json: novelDetail.value!.toString(),
            ),
          );
          if (detailError != null) {
            Log.w(
              'Wenku8 detail used fallback metadata aid=$aid: $detailError',
            );
          }
        } catch (e, stackTrace) {
          Log.e('HIKARI_WENKU8 detail catalogue parse failed aid=$aid $e');
          Log.e(stackTrace);
          if (await _getNovelDetailByLocal()) return;
          errorMsg = e.toString();
          pageState.value = PageState.error;
        }
      case Error():
        if (await _getNovelDetailByLocal()) return;
        errorMsg = cat.error.toString();
        pageState.value = PageState.error;
    }
  }

  Future<void> _refreshWenku8CatalogueInBackground() async {
    try {
      await _loadWenku8CatalogueIntoDetail(_fallbackNovelDetail());
    } catch (e, stackTrace) {
      Log.e('HIKARI_WENKU8 detail background refresh failed aid=$aid $e');
      Log.e(stackTrace);
    }
  }

  NovelDetail _fallbackNovelDetail() {
    final title = seedTitle.trim().isNotEmpty
        ? seedTitle.trim()
        : 'Wenku8 #$aid';
    return NovelDetail(
      title,
      '',
      '',
      '',
      seedImageUrl?.trim() ?? '',
      '',
      const [],
      '',
      '',
      false,
    );
  }

  Future<void> _getYamiboNovelDetail() async {
    loadingMessage.value = 'yamibo_detail_loading'.tr;
    if (!YamiboApi.hasCookie) {
      SourceAuthGuard.clearLogin(NovelSource.yamibo);
      SourceAuthGuard.showLoginRequired(NovelSource.yamibo);
      errorMsg = 'source_login_required'.tr;
      pageState.value = PageState.error;
      return;
    }
    final firstPage = await YamiboApi.getThreadPage(tid: yamiboTid);
    switch (firstPage) {
      case Success():
        {
          if (!SourceAuthGuard.checkHtml(NovelSource.yamibo, firstPage.data)) {
            errorMsg = 'source_login_required'.tr;
            pageState.value = PageState.error;
            return;
          }
          if (YamiboParser.isUnavailableDuringDailyBackup(firstPage.data)) {
            errorMsg = 'yamibo_backup_window'.tr;
            if (await _getNovelDetailByLocal()) return;
            pageState.value = PageState.error;
            return;
          }
          if (!YamiboParser.isMobileApiJson(firstPage.data)) {
            errorMsg = 'yamibo_api_html_response'.tr;
            if (await _getNovelDetailByLocal()) return;
            pageState.value = PageState.error;
            return;
          }
          final threadError = YamiboParser.threadErrorMessage(firstPage.data);
          if (threadError != null) {
            errorMsg = threadError;
            pageState.value = PageState.error;
            return;
          }
          late final YamiboThreadData data;
          try {
            data = YamiboParser.getThreadDetail(firstPage.data);
          } catch (e) {
            errorMsg = 'yamibo_detail_parse_failed'.trParams({'error': '$e'});
            if (await _getNovelDetailByLocal()) return;
            pageState.value = PageState.error;
            return;
          }
          final cachedOwnerVolume = await _getCachedYamiboOwnerVolume(
            data.updateKey,
          );
          if (cachedOwnerVolume != null) {
            data.detail.catalogue
              ..removeWhere((volume) => volume.title == _yamiboOwnerVolumeTitle)
              ..insert(0, cachedOwnerVolume);
          }
          yamiboAuthorId = data.authorId;
          novelDetail.value = data.detail;
          await DBService.instance.upsertBrowsingHistory(
            BrowsingHistoryEntityData(
              aid: aid,
              title: data.detail.title,
              img: data.detail.imgUrl,
              time: DateTime.now(),
            ),
          );
          await _syncLocalBookshelfState();
          await _syncYamiboBookshelfFromDetail(data);
          if (isInBookshelf.value) {
            await DBService.instance.clearBookshelfUpdate(aid);
          }
          pageState.value = PageState.success;
          await DBService.instance.upsertNovelDetail(
            NovelDetailEntityData(
              aid: aid,
              json: novelDetail.value!.toString(),
            ),
          );
          if (LocalStorageService.instance.getYamiboOwnerCatalogue() &&
              cachedOwnerVolume == null) {
            unawaited(_buildYamiboOwnerCatalogue(data));
          }
        }
      case Error():
        {
          errorMsg = firstPage.error.toString();
          if (await _getNovelDetailByLocal()) return;
          pageState.value = PageState.error;
        }
    }
  }

  Future<CatVolume?> _getCachedYamiboOwnerVolume(String updateKey) async {
    if (!LocalStorageService.instance.getYamiboOwnerCatalogue()) return null;
    final cachedKey = LocalStorageService.instance.getYamiboOwnerCatalogueKey(
      yamiboTid,
    );
    if (cachedKey != updateKey) return null;
    final local = (await DBService.instance.getNovelDetail(aid))?.json;
    if (local == null) return null;
    try {
      final detail = NovelDetail.fromString(local);
      return detail.catalogue.firstWhereOrNull(
        (volume) => volume.title == _yamiboOwnerVolumeTitle,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _buildYamiboOwnerCatalogue(YamiboThreadData data) async {
    if (data.authorId.isEmpty || novelDetail.value == null) return;
    yamiboCatalogueBuilding.value = true;
    yamiboCatalogueStatus.value = 'yamibo_catalogue_building'.tr;
    final chapters = <CatChapter>[];
    final maxPage = data.maxPage.clamp(1, 80);
    try {
      for (var page = 1; page <= maxPage; page++) {
        yamiboCatalogueStatus.value = 'yamibo_catalogue_building_page'.trParams(
          {'page': '$page', 'total': '$maxPage'},
        );
        final pageResult = await YamiboApi.getThreadPage(
          tid: yamiboTid,
          page: page,
          authorId: data.authorId,
        );
        if (pageResult is! Success) break;
        if (!SourceAuthGuard.checkHtml(NovelSource.yamibo, pageResult.data)) {
          break;
        }
        final threadError = YamiboParser.threadErrorMessage(pageResult.data);
        if (threadError != null) {
          yamiboCatalogueStatus.value = threadError;
          break;
        }
        chapters.addAll(YamiboParser.getOwnerPostChapters(pageResult.data));
      }
      if (chapters.isNotEmpty && novelDetail.value != null) {
        final detail = novelDetail.value!;
        detail.catalogue.removeWhere(
          (volume) => volume.title == _yamiboOwnerVolumeTitle,
        );
        detail.catalogue.insert(
          0,
          CatVolume(title: _yamiboOwnerVolumeTitle, chapters: chapters),
        );
        novelDetail.refresh();
        update(["customScrollView"]);
        await DBService.instance.upsertNovelDetail(
          NovelDetailEntityData(aid: aid, json: detail.toString()),
        );
        LocalStorageService.instance.setYamiboOwnerCatalogueKey(
          yamiboTid,
          data.updateKey,
        );
        yamiboCatalogueStatus.value = 'yamibo_catalogue_ready'.trParams({
          'count': '${chapters.length}',
        });
      }
    } finally {
      yamiboCatalogueBuilding.value = false;
    }
  }

  Future<void> _syncYamiboBookshelfFromDetail(YamiboThreadData data) async {
    final items = await DBService.instance.getAllBookshelf();
    final item = items.firstWhereOrNull((entry) => entry.aid == aid);
    if (item == null) return;
    final currentImg = _isYamiboPlaceholderImage(item.img) ? '' : item.img;
    await DBService.instance.upsertBookshelf(
      BookshelfEntityData(
        aid: item.aid,
        bid: item.bid,
        url: item.url,
        title: data.detail.title,
        img: data.detail.imgUrl.isNotEmpty ? data.detail.imgUrl : currentImg,
        classId: item.classId,
        updateKey: _yamiboDetailUpdateKey(item.updateKey, data.updateKey),
        updateTime: data.updateTime,
        hasUpdate: item.hasUpdate,
        rating: item.rating,
        remoteTagsJson: BookTags.encode(
          BookTags.merge(
            BookTags.decode(item.remoteTagsJson),
            data.detail.tags,
          ),
        ),
        localTagsJson: item.localTagsJson,
      ),
    );
    isInBookshelf.value = true;
    bookshelfController.loadFolders();
  }

  String _yamiboDetailUpdateKey(String currentKey, String detailKey) {
    if (!currentKey.contains(_yamiboOwnerUpdateSeparator)) return detailKey;
    final parts = currentKey.split(_yamiboOwnerUpdateSeparator);
    final ownerKey = parts.skip(1).join(_yamiboOwnerUpdateSeparator);
    if (ownerKey.isEmpty) return detailKey;
    return '$detailKey$_yamiboOwnerUpdateSeparator$ownerKey';
  }

  bool _isYamiboPlaceholderImage(String url) {
    final lower = url.trim().toLowerCase();
    if (lower.isEmpty) return false;
    return lower == YamiboApi.logoUrl.toLowerCase() ||
        lower.contains('/static/image/common/logo') ||
        lower.contains('discuz') ||
        lower.contains('community');
  }

  Future<void> _getEsjNovelDetail() async {
    final result = await EsjApi.getNovelDetail(id: esjBookId);
    switch (result) {
      case Success():
        {
          final data = EsjParser.getNovelDetail(result.data, aid);
          novelDetail.value = data;
          await DBService.instance.upsertBrowsingHistory(
            BrowsingHistoryEntityData(
              aid: aid,
              title: data.title,
              img: data.imgUrl,
              time: DateTime.now(),
            ),
          );
          await _syncLocalBookshelfState();
          if (isInBookshelf.value) {
            await DBService.instance.clearBookshelfUpdate(aid);
          }
          pageState.value = PageState.success;
          await DBService.instance.upsertNovelDetail(
            NovelDetailEntityData(
              aid: aid,
              json: novelDetail.value!.toString(),
            ),
          );
        }
      case Error():
        {
          if (await _getNovelDetailByLocal()) return;
          errorMsg = result.error.toString();
          pageState.value = PageState.error;
        }
    }
  }

  Future<bool> _getNovelDetailByLocal() async {
    final local = (await DBService.instance.getNovelDetail(aid))?.json;

    if (local == null) {
      return false;
    } else {
      final data = NovelDetail.fromString(local);
      novelDetail.value = data;
      await DBService.instance.upsertBrowsingHistory(
        BrowsingHistoryEntityData(
          aid: aid,
          title: data.title,
          img: data.imgUrl,
          time: DateTime.now(),
        ),
      );
      await _syncLocalBookshelfState();
      if (isInBookshelf.value) {
        await DBService.instance.clearBookshelfUpdate(aid);
      }
      pageState.value = PageState.success;
      return true;
    }
  }

  String _htmlPreview(String html) {
    final compact = html.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 180) return compact;
    return compact.substring(0, 180);
  }

  bool _isAdding = false; //闃叉姈
  Future<void> _syncLocalBookshelfState() async {
    final bs = await DBService.instance.getAllBookshelf();
    BookshelfEntityData? item;
    for (final e in bs) {
      if (e.aid == aid) {
        item = e;
        break;
      }
    }
    isInBookshelf.value = item != null;
    localRating.value = item?.rating ?? 0;
    remoteTags.assignAll(BookTags.decode(item?.remoteTagsJson));
    localTags.assignAll(BookTags.decode(item?.localTagsJson));
    final detail = novelDetail.value;
    if (item != null && detail != null) {
      final merged = BookTags.merge(remoteTags, detail.tags);
      remoteTags.assignAll(merged);
      await DBService.instance.setBookshelfRemoteTags(
        aid,
        BookTags.encode(merged),
      );
    }
  }

  Future<void> setLocalRating(double rating) async {
    if (!isInBookshelf.value) {
      showSnackBar(
        message: 'rating_requires_bookshelf'.tr,
        context: Get.context!,
      );
      return;
    }
    final value = ((rating.clamp(0, 5) * 2).round() / 2).toDouble();
    localRating.value = value;
    await DBService.instance.setBookshelfRating(aid, value);
    bookshelfController.loadFolders();
  }

  Future<void> setLocalTags(Iterable<String> tags) async {
    if (!isInBookshelf.value) {
      showSnackBar(
        message: 'local_tags_requires_bookshelf'.tr,
        context: Get.context!,
      );
      return;
    }
    final normalized = BookTags.normalize(tags);
    localTags.assignAll(normalized);
    await DBService.instance.setBookshelfLocalTags(
      aid,
      BookTags.encode(normalized),
    );
    bookshelfController.loadFolders();
  }

  void addToBookshelf() async {
    if (_isAdding) return;
    _isAdding = true;
    final targetClassId = await _selectBookshelfTarget();
    if (targetClassId == null) {
      _isAdding = false;
      return;
    }
    if (isEsj) {
      final detail = novelDetail.value;
      if (detail != null) {
        if (SourceFavoriteAdapter.shouldPushRemote(NovelSource.esj)) {
          final pushed = await SourceFavoriteAdapter.addRemoteFavorite(
            source: NovelSource.esj,
            aid: aid,
          );
          if (!pushed) {
            showErrorDialog('update_failed'.tr, [
              TextButton(onPressed: Get.back, child: Text("confirm".tr)),
            ]);
            _isAdding = false;
            return;
          }
        }
        await DBService.instance.upsertBookshelf(
          BookshelfEntityData(
            aid: aid,
            bid: aid,
            url: EsjApi.detailUrl(esjBookId),
            title: detail.title,
            img: detail.imgUrl,
            classId: targetClassId,
            updateKey: '',
            updateTime: null,
            hasUpdate: false,
            rating: localRating.value,
            remoteTagsJson: BookTags.encode(detail.tags),
            localTagsJson: BookTags.emptyJson,
          ),
        );
        SourceConfigService.instance.restoreLocalFavorite(NovelSource.esj, aid);
        isInBookshelf.value = true;
        bookshelfController.loadFolders();
      }
      _isAdding = false;
      return;
    }
    if (isYamibo) {
      final detail = novelDetail.value;
      if (detail != null) {
        await DBService.instance.upsertBookshelf(
          BookshelfEntityData(
            aid: aid,
            bid: aid,
            url: YamiboApi.threadUrl(yamiboTid),
            title: detail.title,
            img: detail.imgUrl,
            classId: targetClassId,
            updateKey: '',
            updateTime: null,
            hasUpdate: false,
            rating: localRating.value,
            remoteTagsJson: BookTags.encode(detail.tags),
            localTagsJson: BookTags.emptyJson,
          ),
        );
        SourceConfigService.instance.restoreLocalFavorite(
          NovelSource.yamibo,
          aid,
        );
        isInBookshelf.value = true;
        bookshelfController.loadFolders();
      }
      _isAdding = false;
      return;
    }
    if (!SourceConfigService.instance.shouldPushLocalToRemote(
      NovelSource.wenku8,
    )) {
      final detail = novelDetail.value;
      if (detail != null) {
        await DBService.instance.upsertBookshelf(
          BookshelfEntityData(
            aid: aid,
            bid: aid,
            url:
                '${Api.wenku8Node.node}/modules/article/articleinfo.php?id=$aid',
            title: detail.title,
            img: detail.imgUrl,
            classId: targetClassId,
            updateKey: '',
            updateTime: null,
            hasUpdate: false,
            rating: localRating.value,
            remoteTagsJson: BookTags.encode(detail.tags),
            localTagsJson: BookTags.emptyJson,
          ),
        );
        SourceConfigService.instance.restoreLocalFavorite(
          NovelSource.wenku8,
          aid,
        );
        isInBookshelf.value = true;
        bookshelfController.loadFolders();
      }
      _isAdding = false;
      return;
    }
    final result = await Api.addNovel(aid: aid);
    switch (result) {
      case Success():
        {
          if (Parser.isError(result.data)) {
            Get.dialog(
              AlertDialog(
                icon: const Icon(Icons.warning_amber_outlined),
                title: Text("warning".tr),
                content: Text("add_to_bookshelf_failed_tip".tr),
                actions: [
                  TextButton(onPressed: Get.back, child: Text("confirm".tr)),
                ],
              ),
            );
            isInBookshelf.value = false;
          } else {
            await _upsertWenku8LocalBookshelf(targetClassId);
            await bookshelfController.refreshDefaultBookshelf();
            await _moveWenku8RemoteFavoriteToConfiguredTarget();
            if (targetClassId != BookshelfController.defaultClassId) {
              await bookshelfController.moveBooksToFolder([aid], targetClassId);
            }
            SourceConfigService.instance.restoreLocalFavorite(
              NovelSource.wenku8,
              aid,
            );
            isInBookshelf.value = true;
          }
        }
      case Error():
        {
          showErrorDialog(result.error.toString(), [
            TextButton(onPressed: Get.back, child: Text("confirm".tr)),
          ]);
        }
    }
    _isAdding = false;
  }

  Future<void> _upsertWenku8LocalBookshelf(String targetClassId) async {
    final detail = novelDetail.value;
    if (detail == null) return;
    await DBService.instance.upsertBookshelf(
      BookshelfEntityData(
        aid: aid,
        bid: aid,
        url: '${Api.wenku8Node.node}/modules/article/articleinfo.php?id=$aid',
        title: detail.title,
        img: detail.imgUrl,
        classId: targetClassId,
        updateKey: '',
        updateTime: null,
        hasUpdate: false,
        rating: localRating.value,
        remoteTagsJson: BookTags.encode(detail.tags),
        localTagsJson: BookTags.emptyJson,
      ),
    );
    isInBookshelf.value = true;
    await bookshelfController.loadFolders();
  }

  Future<void> _moveWenku8RemoteFavoriteToConfiguredTarget() async {
    final target = int.tryParse(
      SourceConfigService.instance
          .configOf(NovelSource.wenku8)
          .targetRemoteFolderId,
    );
    if (target == null || target <= 0) return;
    BookshelfEntityData? item;
    for (final candidate in await DBService.instance.getAllBookshelf()) {
      if (candidate.aid == aid) {
        item = candidate;
        break;
      }
    }
    if (item == null || item.bid.isEmpty) return;
    await Api.moveNovelToOther(
      list: [item.bid],
      classId: 0,
      newClassId: target,
    );
  }

  Future<String?> _selectBookshelfTarget() async {
    await bookshelfController.loadFolders();
    final targets = bookshelfController.getLocalBookshelfTargetFolders();
    return Get.dialog<String>(
      AlertDialog(
        title: Text('select_bookshelf_target'.tr),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: targets.length,
            itemBuilder: (context, index) {
              final folder = targets[index];
              return ListTile(
                title: Text(bookshelfController.folderDisplayName(folder)),
                onTap: () => Get.back(result: folder.id),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: Get.back, child: Text('cancel'.tr))],
      ),
    );
  }

  bool _isRemoving = false; //闃叉姈
  void removeFromBookshelf() async {
    if (_isRemoving) return;
    _isRemoving = true;
    if (isEsj) {
      if (SourceFavoriteAdapter.shouldRemoveRemote(NovelSource.esj)) {
        final removed = await SourceFavoriteAdapter.removeRemoteFavorite(
          source: NovelSource.esj,
          remoteId: aid,
        );
        if (!removed) {
          showErrorDialog('update_failed'.tr, [
            TextButton(onPressed: Get.back, child: Text("confirm".tr)),
          ]);
          _isRemoving = false;
          return;
        }
      } else {
        SourceConfigService.instance.hideLocalFavorite(NovelSource.esj, aid);
      }
      await DBService.instance.deleteBookshelfByAid(aid);
      isInBookshelf.value = false;
      localRating.value = 0;
      bookshelfController.loadFolders();
      _isRemoving = false;
      return;
    }
    if (isYamibo) {
      await DBService.instance.deleteBookshelfByAid(aid);
      SourceConfigService.instance.hideLocalFavorite(NovelSource.yamibo, aid);
      isInBookshelf.value = false;
      localRating.value = 0;
      bookshelfController.loadFolders();
      _isRemoving = false;
      return;
    }
    final bs = await DBService.instance.getAllBookshelf();
    BookshelfEntityData? localItem;
    for (final item in bs) {
      if (item.aid == aid) {
        localItem = item;
        break;
      }
    }
    if (localItem == null) {
      isInBookshelf.value = false;
      localRating.value = 0;
      _isRemoving = false;
      return;
    }
    final delId = localItem.bid;
    if (!SourceFavoriteAdapter.shouldRemoveRemote(NovelSource.wenku8)) {
      await DBService.instance.deleteBookshelfByAid(aid);
      SourceConfigService.instance.hideLocalFavorite(NovelSource.wenku8, aid);
      isInBookshelf.value = false;
      localRating.value = 0;
      bookshelfController.loadFolders();
      _isRemoving = false;
      return;
    }
    final result = await Api.removeNovel(delid: delId);
    switch (result) {
      case Success():
        {
          await DBService.instance.deleteBookshelfByAid(aid);
          isInBookshelf.value = false;
          localRating.value = 0;
          bookshelfController.loadFolders();
        }
      case Error():
        {
          showErrorDialog(result.error.toString(), [
            TextButton(onPressed: Get.back, child: Text("confirm".tr)),
          ]);
        }
    }
    _isRemoving = false;
  }

  void recommendThisNovel() async {
    if (isYamibo || isEsj) {
      await openWithBrowser();
      return;
    }
    final result = await Api.novelVote(aid: aid);
    final string = switch (result) {
      Success() => Parser.novelVote(result.data),
      Error() => result.error.toString(),
    };
    showSnackBar(message: string, context: Get.context!);
  }

  Future<void> openWithBrowser() async {
    if (isEsj) {
      AppSubRouter.toEsjzone(url: EsjApi.detailUrl(esjBookId));
      return;
    }
    final url = isEsj
        ? EsjApi.detailUrl(esjBookId)
        : isYamibo
        ? YamiboApi.threadUrl(yamiboTid)
        : "${Api.wenku8Node.node}/book/$aid.htm";
    if (!await launchUrl(Uri.parse(url))) {
      showSnackBar(
        message: "unable_to_open_external_browser".tr,
        context: Get.context!,
      );
    }
  }

  ///妫€娴嬮槄璇昏褰曟槸鍚﹂€傜敤浜庡綋鍓嶈缃紙鏄惁鍙岄〉锛岄槄璇绘柟鍚戯級
  bool isValidReadHistory(ReadHistoryEntityData? data) {
    if (data == null) {
      return false;
    } else {
      bool isDualPage = switch (LocalStorageService.instance
          .getReaderDualPageMode()) {
        DualPageMode.auto => Get.context!.shouldAutoUseDualPage(),
        DualPageMode.enabled => true,
        DualPageMode.disabled => false,
      };
      bool isSameReaderMode = switch (LocalStorageService.instance
          .getReaderDirection()) {
        ReaderDirection.leftToRight => data.readerMode == kPageReadMode,
        ReaderDirection.rightToLeft => data.readerMode == kPageReadMode,
        ReaderDirection.upToDown => data.readerMode == kScrollReadMode,
      };
      return data.isDualPage == isDualPage && isSameReaderMode;
    }
  }

  String getReadHistoryProgressByCid(ReadHistoryEntityData? result) {
    if (result == null) {
      return "unread".tr;
    }

    bool isDualPage = switch (LocalStorageService.instance
        .getReaderDualPageMode()) {
      DualPageMode.auto => Get.context!.shouldAutoUseDualPage(),
      DualPageMode.enabled => true,
      DualPageMode.disabled => false,
    };

    final currDirection = LocalStorageService.instance.getReaderDirection();
    if (result.isDualPage == isDualPage) {
      if ((result.readerMode == kScrollReadMode &&
              currDirection == ReaderDirection.upToDown) ||
          (result.readerMode == kPageReadMode &&
              (currDirection == ReaderDirection.leftToRight ||
                  currDirection == ReaderDirection.rightToLeft))) {
        return "${result.progress}%";
      }
    }
    return "unable_to_use_read_history_tip".tr;
  }

  String getReadHistoryProgressByVolume(
    List<ReadHistoryEntityData> list,
    int totalNum,
  ) {
    int readCompletedNum = 0;
    int readPartiallyNum = 0;

    if (list.isEmpty) {
      return "unread".tr;
    }

    bool isDualPage = switch (LocalStorageService.instance
        .getReaderDualPageMode()) {
      DualPageMode.auto => Get.context!.shouldAutoUseDualPage(),
      DualPageMode.enabled => true,
      DualPageMode.disabled => false,
    };
    final currDirection = LocalStorageService.instance.getReaderDirection();
    for (ReadHistoryEntityData d in list) {
      if (d.isDualPage == isDualPage) {
        if ((d.readerMode == kScrollReadMode &&
                currDirection == ReaderDirection.upToDown) ||
            (d.readerMode == kPageReadMode &&
                (currDirection == ReaderDirection.leftToRight ||
                    currDirection == ReaderDirection.rightToLeft))) {
          if (d.progress == 100) {
            readCompletedNum++;
          } else {
            readPartiallyNum++;
          }
        }
      }
    }

    if (readCompletedNum == totalNum) {
      return "all_reading_completed".tr;
    } else if (readPartiallyNum > 0 ||
        (readCompletedNum > 0 && readCompletedNum < totalNum)) {
      return "partially_read".tr;
    } else {
      return "unread".tr;
    }
  }

  void deleteAllReadHistory() async =>
      DBService.instance.deleteAllReadHistory();

  Future<void> markAsUnRead() async {
    for (var chapter in getSelectedChapters()) {
      await DBService.instance.deleteReadHistoryByCid(aid, chapter.cid);
    }
  }

  Future<void> markAsRead() async {
    final readerMode =
        LocalStorageService.instance.getReaderDirection() ==
            ReaderDirection.upToDown
        ? kScrollReadMode
        : kPageReadMode;
    bool isDualPage = switch (LocalStorageService.instance
        .getReaderDualPageMode()) {
      DualPageMode.auto => Get.context!.shouldAutoUseDualPage(),
      DualPageMode.enabled => true,
      DualPageMode.disabled => false,
    };

    for (var chapter in getSelectedChapters()) {
      final data = await DBService.instance.getReadHistoryByCid(
        aid,
        chapter.cid,
      );

      if (data == null) {
        DBService.instance.upsertReadHistoryDirectly(
          ReadHistoryEntityData(
            cid: chapter.cid,
            aid: aid,
            readerMode: readerMode,
            isDualPage: isDualPage,
            location: 0,
            progress: 100,
            isLatest: false,
          ),
        );
      } else {
        DBService.instance.upsertReadHistoryDirectly(
          ReadHistoryEntityData(
            cid: data.cid,
            aid: data.aid,
            readerMode: data.readerMode,
            isDualPage: data.isDualPage,
            location: data.location,
            progress: 100,
            isLatest: data.isLatest,
          ),
        );
      }
    }
  }
}
