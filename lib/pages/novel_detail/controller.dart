import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/common/constants.dart';
import 'package:hikari_novel_flutter/common/extension.dart';
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
import '../../service/source_config_service.dart';
import '../../service/source_favorite_adapter.dart';

class NovelDetailController extends GetxController
    with GetSingleTickerProviderStateMixin {
  final String aid;

  bool get isYamibo => SourceId.isYamibo(aid);

  bool get isEsj => SourceId.isEsj(aid);

  String get yamiboTid => SourceId.yamiboTid(aid);

  String get esjBookId => SourceId.esjBookId(aid);

  NovelDetailController({required this.aid});

  Rx<PageState> pageState = PageState.loading.obs;
  String errorMsg = "";
  Rxn<NovelDetail> novelDetail = Rxn();

  RxSet<String> cachedChapter = RxSet();

  RxBool isInBookshelf = false.obs;
  RxDouble localRating = 0.0.obs;
  RxList<String> localTags = RxList();

  RxBool isChapterOrderReversed = false.obs;

  RxBool isSelectionMode = false.obs;
  String yamiboAuthorId = "";

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

  //切换某个章节的选中状态（假设 chapter.isSelected 是 RxBool）
  void toggleChapterSelection(int volumeIndex, int chapterIndex) {
    final chapter =
        novelDetail.value!.catalogue[volumeIndex].chapters[chapterIndex];
    chapter.isSelected.toggle();
    _syncVolumeSelection(volumeIndex);
  }

  //切换某卷（全部选中或全部取消）
  void toggleVolumeSelection(int volumeIndex) {
    final volume = novelDetail.value!.catalogue[volumeIndex];
    final allSelected = volume.chapters.every((c) => c.isSelected.value);
    for (final c in volume.chapters) {
      c.isSelected.value = !allSelected;
    }
    volume.isSelected.value = !allSelected;
  }

  //根据章节选中数同步卷状态
  void _syncVolumeSelection(int volumeIndex) {
    final volume = novelDetail.value!.catalogue[volumeIndex];
    final total = volume.chapters.length;
    final selected = volume.chapters.where((c) => c.isSelected.value).length;
    if (selected == 0) {
      volume.isSelected.value = false;
    } else if (selected == total) {
      volume.isSelected.value = true;
    } else {
      //部分选中：你可以用单独字段或在 UI 用 selected数判断
      volume.isSelected.value = false;
    }
  }

  //获取选中的章节列表
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
    if (await File(
      "${_supportDir.path}/cached_chapter/${SourceId.safeFilePart(aid)}_${SourceId.safeFilePart(cid)}.txt",
    ).exists()) {
      cachedChapter.add(cid);
    } else {
      cachedChapter.remove(cid);
    }
  }

  Future<void> getNovelDetail() async {
    if (isEsj) {
      await _getEsjNovelDetail();
      return;
    }

    if (isYamibo) {
      await _getYamiboNovelDetail();
      return;
    }

    late NovelDetail data;

    final nd = await Api.getNovelDetail(aid: aid);

    switch (nd) {
      case Success():
        data = Parser.getNovelDetail(nd.data);
        final cat = await Api.getCatalogue(aid: aid);
        switch (cat) {
          case Success():
            {
              data.catalogue.addAll(Parser.getCatalogue(cat.data));
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
              ); //缓存小说详情
            }
          case Error():
            {
              //检测本地是否有缓存
              if (await _getNovelDetailByLocal()) return;
              errorMsg = cat.error.toString();
              pageState.value = PageState.error;
            }
        }
      case Error():
        {
          //检测本地是否有缓存
          if (await _getNovelDetailByLocal()) return;
          errorMsg = nd.error.toString();
          pageState.value = PageState.error;
        }
    }
  }

  Future<void> _getYamiboNovelDetail() async {
    final firstPage = await YamiboApi.getThreadPage(tid: yamiboTid);
    switch (firstPage) {
      case Success():
        {
          final firstPageData = YamiboParser.getThreadDetail(firstPage.data);
          final authorPage = await YamiboApi.getThreadPage(
            tid: yamiboTid,
            authorId: firstPageData.authorId,
          );
          final data = switch (authorPage) {
            Success() => YamiboParser.getThreadDetail(authorPage.data),
            Error() => firstPageData,
          };
          final ownerChapters = <CatChapter>[];
          if (data.authorId.isNotEmpty) {
            final maxPage = data.maxPage.clamp(1, 80);
            for (var page = 1; page <= maxPage; page++) {
              final pageResult = page == 1 && authorPage is Success
                  ? authorPage
                  : await YamiboApi.getThreadPage(
                      tid: yamiboTid,
                      page: page,
                      authorId: data.authorId,
                    );
              if (pageResult is! Success) break;
              ownerChapters.addAll(
                YamiboParser.getOwnerPostChapters(pageResult.data),
              );
            }
          }
          if (ownerChapters.isNotEmpty) {
            data.detail.catalogue
              ..clear()
              ..add(CatVolume(title: '楼主楼层', chapters: ownerChapters));
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
          errorMsg = firstPage.error.toString();
          if (await _getNovelDetailByLocal()) return;
          pageState.value = PageState.error;
        }
    }
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

  bool _isAdding = false; //防抖
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
    localTags.assignAll(BookTags.decode(item?.localTagsJson));
    final detail = novelDetail.value;
    if (item != null && detail != null) {
      await DBService.instance.setBookshelfRemoteTags(
        aid,
        BookTags.encode(detail.tags),
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

  bool _isRemoving = false; //防抖
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

  ///检测阅读记录是否适用于当前设置（是否双页，阅读方向）
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
    // 1为滚动模式，2为翻页模式，翻页模式的左右方向不影响阅读记录的使用
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
