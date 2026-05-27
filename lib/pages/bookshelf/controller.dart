import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/common/constants.dart';
import 'package:hikari_novel_flutter/models/book_tags.dart';
import 'package:hikari_novel_flutter/models/bookshelf.dart';
import 'package:hikari_novel_flutter/models/common/wenku8_node.dart';
import 'package:hikari_novel_flutter/models/content.dart';
import 'package:hikari_novel_flutter/models/custom_exception.dart';
import 'package:hikari_novel_flutter/models/novel_cover.dart';
import 'package:hikari_novel_flutter/models/novel_detail.dart';
import 'package:hikari_novel_flutter/models/page_state.dart';
import 'package:hikari_novel_flutter/models/reader_direction.dart';
import 'package:hikari_novel_flutter/models/resource.dart';
import 'package:hikari_novel_flutter/models/smart_shelf.dart';
import 'package:hikari_novel_flutter/models/source_id.dart';
import 'package:hikari_novel_flutter/models/source_config.dart';
import 'package:hikari_novel_flutter/network/api.dart';
import 'package:hikari_novel_flutter/network/esj_api.dart';
import 'package:hikari_novel_flutter/network/esj_parser.dart';
import 'package:hikari_novel_flutter/network/parser.dart';
import 'package:hikari_novel_flutter/network/yamibo_api.dart';
import 'package:hikari_novel_flutter/network/yamibo_parser.dart';
import 'package:hikari_novel_flutter/pages/main/controller.dart';
import 'package:hikari_novel_flutter/service/local_storage_service.dart';
import 'package:hikari_novel_flutter/service/source_auth_guard.dart';
import 'package:hikari_novel_flutter/service/source_config_service.dart';
import 'package:hikari_novel_flutter/service/source_favorite_adapter.dart';
import 'package:path_provider/path_provider.dart';

import '../../common/database/database.dart';
import '../../service/db_service.dart';

class BookshelfController extends GetxController
    with GetTickerProviderStateMixin {
  static const yamiboClassId = 'yamibo';
  static const esjClassId = 'esj';
  static const defaultClassId = '0';
  static const recentSmartId = 'smart_recent_12';
  static const smartTagPrefix = 'smart_tag_';
  static const smartShelfPrefix = 'smart_filter_';
  static const subscriptionShelfPrefix = 'smart_subscription_';
  static const _rootFolderViewModeKey = '__bookshelf_root__';
  static const _yamiboOwnerUpdateSeparator = '\nowner:';
  static const _localFolderPrefix = 'local_';
  static const _subscriptionCacheClassId = '__smart_subscription_cache__';
  static const _yamiboSubscriptionSearchInterval = Duration(seconds: 10);
  static Future<void> _yamiboSubscriptionSearchQueue = Future.value();
  static DateTime? _lastYamiboSubscriptionSearchAt;

  RxInt tabIndex = 0.obs;

  Rx<PageState> pageState = Rx(PageState.bookshelfContent);

  Rxn<BookshelfFolder> currentFolder = Rxn<BookshelfFolder>();

  RxList<BookshelfFolder> folderStack = RxList();

  RxList<BookshelfFolder> folders = RxList();

  late TabController tabController;
  final List<String> tabs = [defaultClassId, yamiboClassId, esjClassId];

  RxBool useListView = true.obs;

  RxBool useFolderListView = true.obs;

  RxBool isSelectionMode = false.obs;

  RxInt sortRevision = 0.obs;

  final RxMap<String, BookshelfSyncProgress> syncProgress =
      <String, BookshelfSyncProgress>{}.obs;
  final RxMap<String, String> syncErrors = <String, String>{}.obs;
  final RxMap<String, String> syncAssistUrls = <String, String>{}.obs;

  String get currentClassId => currentFolder.value?.id ?? defaultClassId;

  bool get isInFolder => currentFolder.value != null;

  List<BookshelfFolder> get rootFolders => folders
      .where((folder) => folder.parentId == null || folder.parentId!.isEmpty)
      .toList();

  List<BookshelfFolder> get currentChildFolders {
    final parent = currentFolder.value;
    if (parent == null || parent.smartFolder) return [];
    return getChildFolders(parent.id);
  }

  List<BookshelfFolder> getChildFolders(String parentId) =>
      folders.where((folder) => folder.parentId == parentId).toList();

  BookshelfSyncProgress? syncProgressFor(String folderId) =>
      syncProgress[folderId];

  void _setSyncProgress(String folderId, {double? value, String? message}) {
    syncProgress[folderId] = BookshelfSyncProgress(
      value: value,
      message: message,
    );
  }

  void _clearSyncProgress(String folderId) {
    syncProgress.remove(folderId);
  }

  void _setSyncError(String folderId, String message) {
    if (message.trim().isEmpty) return;
    syncErrors[folderId] = message.trim();
  }

  void _clearSyncError(String folderId) {
    syncErrors.remove(folderId);
    syncAssistUrls.remove(folderId);
  }

  void _setSyncAssistUrl(String folderId, String url) {
    if (url.trim().isNotEmpty) syncAssistUrls[folderId] = url.trim();
  }

  String _syncResultMessage(bool ok, String folderId) {
    if (ok) return "update_successfully".tr;
    final reason = syncErrors[folderId]?.trim();
    if (reason == null || reason.isEmpty) return "update_failed".tr;
    return '${"update_failed".tr}: $reason';
  }

  @override
  void onInit() {
    tabController = TabController(
      length: tabs.length,
      vsync: this,
      initialIndex: tabIndex.value,
    );
    super.onInit();
    useFolderListView.value =
        LocalStorageService.instance.getBookshelfUseListViewForClassId(
          _rootFolderViewModeKey,
        ) ??
        true;
    _initFolders();
  }

  Future<void> _initFolders() async {
    await DBService.instance.moveYamiboBookshelfToYamiboClass();
    await DBService.instance.moveEsjBookshelfToEsjClass();
    await loadFolders();
  }

  Future<void> loadFolders() async {
    final recentLimit = LocalStorageService.instance.getBookshelfRecentCount();
    final allBooks = await DBService.instance.getAllBookshelf();
    final covers = LocalStorageService.instance.getBookshelfFolderCovers();
    final result = <BookshelfFolder>[
      BookshelfFolder(
        id: defaultClassId,
        name: "wenku8".tr,
        builtIn: true,
        cover: BookshelfFolderCover.fromJson(covers[defaultClassId]),
        count: allBooks.where((item) => item.classId == defaultClassId).length,
        hasUpdate: allBooks.any(
          (item) => item.classId == defaultClassId && item.hasUpdate,
        ),
      ),
    ];

    final yamiboCount = allBooks
        .where((item) => item.classId == yamiboClassId)
        .length;
    if (yamiboCount > 0) {
      result.add(
        BookshelfFolder(
          id: yamiboClassId,
          name: "Yamibo",
          builtIn: true,
          cover: BookshelfFolderCover.fromJson(covers[yamiboClassId]),
          count: yamiboCount,
          hasUpdate: allBooks.any(
            (item) => item.classId == yamiboClassId && item.hasUpdate,
          ),
        ),
      );
    }

    final esjCount = allBooks
        .where((item) => item.classId == esjClassId)
        .length;
    if (esjCount > 0) {
      result.add(
        BookshelfFolder(
          id: esjClassId,
          name: "esjzone_folder".tr,
          builtIn: true,
          cover: BookshelfFolderCover.fromJson(covers[esjClassId]),
          count: esjCount,
          hasUpdate: allBooks.any(
            (item) => item.classId == esjClassId && item.hasUpdate,
          ),
        ),
      );
    }

    final recentAids = await _getRecentReadAids(recentLimit);
    if (recentAids.isNotEmpty) {
      result.add(
        BookshelfFolder(
          id: recentSmartId,
          name: "recent_read".trParams({"count": "${recentAids.length}"}),
          smartFolder: true,
          builtIn: true,
          cover: BookshelfFolderCover.fromJson(covers[recentSmartId]),
          smartFolderAids: recentAids,
          count: recentAids.length,
          hasUpdate: allBooks.any(
            (item) => recentAids.contains(item.aid) && item.hasUpdate,
          ),
        ),
      );
    }

    final savedFolders = LocalStorageService.instance.getBookshelfFolders();
    final childCounts = <String, int>{};
    for (final folder in savedFolders) {
      final parentId = _storedParentId(folder);
      if (parentId == null) continue;
      childCounts[parentId] = (childCounts[parentId] ?? 0) + 1;
    }
    for (final folder in savedFolders) {
      final id = folder['id'];
      if (id == null || id.isEmpty) continue;
      final parentId = _storedParentId(folder);
      if (id.startsWith(_localFolderPrefix)) {
        final name = folder['name']?.isNotEmpty == true ? folder['name']! : id;
        final descendantIds = _descendantFolderIds(id, savedFolders);
        final folderIds = {id, ...descendantIds};
        result.add(
          BookshelfFolder(
            id: id,
            name: name,
            parentId: parentId,
            cover: BookshelfFolderCover.fromJson(covers[id]),
            childCount: childCounts[id] ?? 0,
            count: allBooks.where((item) => item.classId == id).length,
            hasUpdate: allBooks.any(
              (item) => folderIds.contains(item.classId) && item.hasUpdate,
            ),
          ),
        );
      } else if (id.startsWith(smartTagPrefix)) {
        final tag = folder['tag'] ?? id.substring(smartTagPrefix.length);
        final name = folder['name']?.isNotEmpty == true ? folder['name']! : tag;
        final matchingAids = _existingBookshelfAids(
          await _getBookshelfAidsByTag(tag),
          allBooks,
        );
        result.add(
          BookshelfFolder(
            id: id,
            name: '$name (${matchingAids.length})',
            parentId: parentId,
            cover: BookshelfFolderCover.fromJson(covers[id]),
            childCount: childCounts[id] ?? 0,
            smartFolder: true,
            smartFolderAids: matchingAids,
            count: matchingAids.length,
            hasUpdate: allBooks.any(
              (item) => matchingAids.contains(item.aid) && item.hasUpdate,
            ),
          ),
        );
      } else if (id.startsWith(smartShelfPrefix) ||
          id.startsWith(subscriptionShelfPrefix)) {
        final config = _smartShelfConfigFromFolder(folder);
        final name = folder['name']?.isNotEmpty == true
            ? folder['name']!
            : "smart_bookshelf".tr;
        final membership = _membershipByAid(id);
        final matchingAids = config.isSubscription
            ? await _subscriptionFolderAids(id, config, allBooks)
            : _existingBookshelfAids(
                await _getBookshelfAidsBySmartConfig(config),
                allBooks,
              );
        result.add(
          BookshelfFolder(
            id: id,
            name: '$name (${matchingAids.length})',
            parentId: parentId,
            cover: BookshelfFolderCover.fromJson(covers[id]),
            childCount: childCounts[id] ?? 0,
            smartFolder: true,
            smartFolderAids: matchingAids,
            count: matchingAids.length,
            hasUpdate: allBooks.any(
              (item) => matchingAids.contains(item.aid) && item.hasUpdate,
            ),
            hasNew: membership.values.any((item) => item.isNew),
          ),
        );
      }
    }

    folders.assignAll(result);
    _syncCurrentPathFromFolders();
  }

  void openFolder(BookshelfFolder folder) {
    final existingIndex = folderStack.indexWhere(
      (item) => item.id == folder.id,
    );
    if (existingIndex >= 0) {
      folderStack.removeRange(existingIndex + 1, folderStack.length);
    } else {
      folderStack.add(folder);
    }
    currentFolder.value = folder;
    if (folder.hasNew) {
      LocalStorageService.instance.clearSmartShelfNewMarks(folder.id);
    }
    useListView.value = useListViewForClassId(folder.id);
  }

  void closeFolder() {
    if (folderStack.length > 1) {
      folderStack.removeLast();
      currentFolder.value = folderStack.last;
    } else {
      folderStack.clear();
      currentFolder.value = null;
    }
    isSelectionMode.value = false;
    Get.find<MainController>().showBookshelfBottomActionBar.value = false;
    loadFolders();
  }

  void closeAllFolders() {
    folderStack.clear();
    currentFolder.value = null;
    isSelectionMode.value = false;
    Get.find<MainController>().showBookshelfBottomActionBar.value = false;
    loadFolders();
  }

  Future<BookshelfFolder?> createFolder(
    String name, {
    Iterable<String> aids = const [],
    String? parentId,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final trimmedParentId = parentId?.trim();
    final normalizedParentId = trimmedParentId?.isEmpty == true
        ? null
        : trimmedParentId;
    final folder = BookshelfFolder(
      id: '$_localFolderPrefix${DateTime.now().microsecondsSinceEpoch}',
      name: trimmed,
      parentId: normalizedParentId,
    );
    final saved = LocalStorageService.instance.getBookshelfFolders();
    final folderData = {'id': folder.id, 'name': folder.name};
    if (normalizedParentId != null) {
      folderData['parentId'] = normalizedParentId;
    }
    saved.add(folderData);
    LocalStorageService.instance.setBookshelfFolders(saved);
    await DBService.instance.moveBookshelfItemsToClassId(aids, folder.id);
    loadFolders();
    return folder;
  }

  Future<BookshelfFolder?> createTagSmartFolder(String tag) async {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) return null;
    final config = SmartShelfConfig.tag(trimmed);
    final folder = BookshelfFolder(
      id: '$smartTagPrefix${DateTime.now().microsecondsSinceEpoch}',
      name: trimmed,
      smartFolder: true,
    );
    final saved = LocalStorageService.instance.getBookshelfFolders();
    saved.add({
      'id': folder.id,
      'name': folder.name,
      'tag': trimmed,
      'smartConfig': jsonEncode(config.toJson()),
    });
    LocalStorageService.instance.setBookshelfFolders(saved);
    loadFolders();
    return folder;
  }

  Future<BookshelfFolder?> createSmartShelf({
    required String name,
    required SmartShelfConfig config,
    String? parentId,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final idPrefix = config.isSubscription
        ? subscriptionShelfPrefix
        : smartShelfPrefix;
    final folder = BookshelfFolder(
      id: '$idPrefix${DateTime.now().microsecondsSinceEpoch}',
      name: trimmed,
      parentId: parentId,
      smartFolder: true,
    );
    final saved = LocalStorageService.instance.getBookshelfFolders();
    saved.add({
      'id': folder.id,
      'name': folder.name,
      if (parentId?.isNotEmpty == true) 'parentId': parentId!,
      'smartConfig': jsonEncode(config.toJson()),
    });
    LocalStorageService.instance.setBookshelfFolders(saved);
    loadFolders();
    return folder;
  }

  Future<void> updateSmartShelf({
    required BookshelfFolder folder,
    required String name,
    required SmartShelfConfig config,
  }) async {
    if (folder.builtIn || !folder.smartFolder) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final saved = LocalStorageService.instance.getBookshelfFolders();
    for (final item in saved) {
      if (item['id'] != folder.id) continue;
      item['name'] = trimmed;
      item.remove('tag');
      item['smartConfig'] = jsonEncode(config.toJson());
    }
    LocalStorageService.instance.setBookshelfFolders(saved);
    loadFolders();
  }

  SmartShelfConfig smartConfigForFolder(BookshelfFolder folder) {
    final saved = LocalStorageService.instance.getBookshelfFolders();
    final raw = saved.firstWhereOrNull((item) => item['id'] == folder.id);
    if (raw == null) return const SmartShelfConfig();
    return _smartShelfConfigFromFolder(raw);
  }

  Future<void> renameFolder(BookshelfFolder folder, String name) async {
    if (folder.builtIn) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final saved = LocalStorageService.instance.getBookshelfFolders();
    for (final item in saved) {
      if (item['id'] == folder.id) item['name'] = trimmed;
    }
    LocalStorageService.instance.setBookshelfFolders(saved);
    loadFolders();
  }

  Future<void> deleteFolder(
    BookshelfFolder folder, {
    String? migrateToClassId,
  }) async {
    if (folder.builtIn) return;
    final saved = LocalStorageService.instance.getBookshelfFolders();
    if (folder.smartFolder) {
      saved.removeWhere((item) => item['id'] == folder.id);
      LocalStorageService.instance.setBookshelfFolders(saved);
      await loadFolders();
      return;
    }
    final folderIds = [folder.id, ..._descendantFolderIds(folder.id, saved)];
    saved.removeWhere((item) => folderIds.contains(item['id']));
    LocalStorageService.instance.setBookshelfFolders(saved);
    if (migrateToClassId != null) {
      await DBService.instance.moveBookshelfItemsToClassId(
        await _getFolderAidsByIds(folderIds),
        migrateToClassId,
      );
    } else {
      for (final folderId in folderIds) {
        await DBService.instance.deleteBookshelfByClassId(folderId);
      }
    }
    loadFolders();
  }

  Future<List<String>> getFolderAids(BookshelfFolder folder) =>
      _getFolderAids(folder);

  Future<void> moveBooksToFolder(Iterable<String> aids, String classId) async {
    await DBService.instance.moveBookshelfItemsToClassId(aids, classId);
    loadFolders();
  }

  BookshelfSortType sortTypeForClassId(String classId) {
    final index = LocalStorageService.instance.getBookshelfSortTypeForClassId(
      classId,
    );
    if (index < 0 || index >= BookshelfSortType.values.length) {
      return BookshelfSortType.added;
    }
    return BookshelfSortType.values[index];
  }

  void setSortTypeForClassId(String classId, BookshelfSortType sortType) {
    LocalStorageService.instance.setBookshelfSortTypeForClassId(
      classId,
      sortType.index,
    );
    sortRevision.value++;
  }

  bool useListViewForClassId(String classId) {
    final saved = LocalStorageService.instance
        .getBookshelfUseListViewForClassId(classId);
    if (saved != null) return saved;
    return switch (classId) {
      defaultClassId || esjClassId => false,
      yamiboClassId => true,
      _ => true,
    };
  }

  void toggleCurrentViewMode() {
    final classId = currentClassId;
    final next = !useListView.value;
    useListView.value = next;
    LocalStorageService.instance.setBookshelfUseListViewForClassId(
      classId,
      next,
    );
  }

  void toggleFolderHomeViewMode() {
    final next = !useFolderListView.value;
    useFolderListView.value = next;
    LocalStorageService.instance.setBookshelfUseListViewForClassId(
      _rootFolderViewModeKey,
      next,
    );
  }

  Future<List<BookshelfNovelInfo>> getFolderCoverCandidates(
    BookshelfFolder folder,
  ) async {
    final aids = await _getFolderAids(folder);
    final aidSet = aids.toSet();
    final books = await DBService.instance.getAllBookshelf();
    return books
        .where(
          (item) => aidSet.contains(item.aid) && item.img.trim().isNotEmpty,
        )
        .map(
          (item) => BookshelfNovelInfo(
            bid: item.bid,
            aid: item.aid,
            url: item.url,
            title: item.title,
            img: item.img,
            updateKey: item.updateKey,
            updateTime: item.updateTime,
            hasUpdate: item.hasUpdate,
            rating: item.rating,
          ),
        )
        .toList();
  }

  void setFolderCoverFromBook(BookshelfFolder folder, BookshelfNovelInfo item) {
    LocalStorageService.instance.setBookshelfFolderCover(
      folder.id,
      BookshelfFolderCover.book(item.img).toJson(),
    );
    loadFolders();
  }

  Future<bool> setFolderCoverFromUploadedFile(BookshelfFolder folder) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final path = result?.files.single.path;
    if (path == null || path.isEmpty) return false;
    final source = File(path);
    if (!await source.exists()) return false;

    final dir = await getApplicationSupportDirectory();
    final coverDir = Directory('${dir.path}${Platform.pathSeparator}covers');
    if (!await coverDir.exists()) {
      await coverDir.create(recursive: true);
    }
    final extension = _fileExtension(path);
    final safeId = folder.id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final target = File(
      '${coverDir.path}${Platform.pathSeparator}${safeId}_${DateTime.now().millisecondsSinceEpoch}$extension',
    );
    await source.copy(target.path);
    LocalStorageService.instance.setBookshelfFolderCover(
      folder.id,
      BookshelfFolderCover.file(target.path).toJson(),
    );
    await loadFolders();
    return true;
  }

  void resetFolderCover(BookshelfFolder folder) {
    LocalStorageService.instance.setBookshelfFolderCover(folder.id, null);
    loadFolders();
  }

  static String _fileExtension(String path) {
    final name = path.split(RegExp(r'[\\/]')).last;
    final index = name.lastIndexOf('.');
    if (index < 0 || index == name.length - 1) return '.png';
    final ext = name.substring(index).toLowerCase();
    return RegExp(r'^\.[a-z0-9]{1,8}$').hasMatch(ext) ? ext : '.png';
  }

  Future<List<String>> _getFolderAids(BookshelfFolder folder) async {
    if (folder.smartFolder) return _getSmartFolderAids(folder);
    final saved = LocalStorageService.instance.getBookshelfFolders();
    final folderIds = [folder.id, ..._descendantFolderIds(folder.id, saved)];
    return _getFolderAidsByIds(folderIds);
  }

  Future<List<String>> _getFolderAidsByIds(Iterable<String> folderIds) async {
    final folderIdSet = folderIds.toSet();
    final books = await DBService.instance.getAllBookshelf();
    return books
        .where((item) => folderIdSet.contains(item.classId))
        .map((i) => i.aid)
        .toList();
  }

  List<BookshelfFolder> getMoveTargetFolders({String? excludedFolderId}) {
    return folders.where((folder) {
      if (folder.smartFolder) return false;
      if (excludedFolderId == null) return true;
      if (folder.id == excludedFolderId) return false;
      return !isDescendantOf(folder.id, excludedFolderId);
    }).toList();
  }

  List<BookshelfFolder> getLocalBookshelfTargetFolders() {
    return folders.where((folder) {
      if (folder.smartFolder) return false;
      return folder.id == defaultClassId ||
          folder.id.startsWith(_localFolderPrefix);
    }).toList();
  }

  bool isDescendantOf(String folderId, String ancestorId) {
    final saved = LocalStorageService.instance.getBookshelfFolders();
    final parents = {
      for (final folder in saved)
        if (folder['id'] != null) folder['id']!: _storedParentId(folder),
    };
    var parentId = parents[folderId];
    final seen = <String>{};
    while (parentId != null && parentId.isNotEmpty && seen.add(parentId)) {
      if (parentId == ancestorId) return true;
      parentId = parents[parentId];
    }
    return false;
  }

  String folderDisplayName(BookshelfFolder folder) {
    final byId = {for (final item in folders) item.id: item};
    final parts = <String>[folder.name];
    var parentId = folder.parentId;
    final seen = <String>{folder.id};
    while (parentId != null && parentId.isNotEmpty && seen.add(parentId)) {
      final parent = byId[parentId];
      if (parent == null) break;
      parts.insert(0, parent.name);
      parentId = parent.parentId;
    }
    return parts.join(' / ');
  }

  String? get currentNormalFolderId {
    final folder = currentFolder.value;
    if (folder == null || folder.smartFolder) return null;
    return folder.id;
  }

  static String? _storedParentId(Map<String, String> folder) {
    final parentId = folder['parentId'];
    if (parentId == null || parentId.trim().isEmpty) return null;
    return parentId.trim();
  }

  static List<String> _descendantFolderIds(
    String folderId,
    List<Map<String, String>> savedFolders,
  ) {
    final descendants = <String>[];
    final queue = <String>[folderId];
    final seen = <String>{folderId};
    while (queue.isNotEmpty) {
      final parentId = queue.removeAt(0);
      for (final folder in savedFolders) {
        final id = folder['id'];
        if (id == null || id.isEmpty || seen.contains(id)) continue;
        if (_storedParentId(folder) == parentId) {
          seen.add(id);
          descendants.add(id);
          queue.add(id);
        }
      }
    }
    return descendants;
  }

  void _syncCurrentPathFromFolders() {
    if (folderStack.isEmpty) return;
    final byId = {for (final folder in folders) folder.id: folder};
    final updatedPath = <BookshelfFolder>[];
    for (final folder in folderStack) {
      final updated = byId[folder.id];
      if (updated == null) break;
      updatedPath.add(updated);
    }
    folderStack.assignAll(updatedPath);
    currentFolder.value = updatedPath.isEmpty ? null : updatedPath.last;
  }

  Future<List<String>> _getSmartFolderAids(BookshelfFolder folder) =>
      getSmartFolderAids(folder.id);

  Future<List<String>> getSmartFolderAids(String folderId) async {
    final allBooks = await DBService.instance.getAllBookshelf();
    if (folderId == recentSmartId) {
      return _existingBookshelfAids(
        await _getRecentReadAids(
          LocalStorageService.instance.getBookshelfRecentCount(),
        ),
        allBooks,
      );
    }
    if (folderId.startsWith(smartTagPrefix)) {
      final tag = _getSmartFolderTagById(folderId);
      if (tag.isEmpty) return [];
      return _existingBookshelfAids(
        await _getBookshelfAidsByTag(tag),
        allBooks,
      );
    }
    if (folderId.startsWith(smartShelfPrefix) ||
        folderId.startsWith(subscriptionShelfPrefix)) {
      final saved = LocalStorageService.instance.getBookshelfFolders();
      final folder = saved.firstWhereOrNull((item) => item['id'] == folderId);
      if (folder == null) return [];
      final config = _smartShelfConfigFromFolder(folder);
      if (config.isSubscription) {
        return _subscriptionFolderAids(folderId, config, allBooks);
      }
      final matched = _existingBookshelfAids(
        await _getBookshelfAidsBySmartConfig(config),
        allBooks,
      );
      return matched;
    }
    return [];
  }

  Future<List<String>> _subscriptionFolderAids(
    String folderId,
    SmartShelfConfig config,
    List<BookshelfEntityData> allBooks,
  ) async {
    final membership = _existingBookshelfAids(
      _membershipByAid(folderId).keys,
      allBooks,
    );
    final matched = _existingBookshelfAids(
      await _getBookshelfAidsBySmartConfig(config),
      allBooks,
    );
    if (membership.isEmpty) {
      return matched;
    }
    if (config.isSubscriptionIncremental) {
      return membership;
    }
    final matchedSet = matched.toSet();
    return membership.where(matchedSet.contains).toList();
  }

  static List<String> _existingBookshelfAids(
    Iterable<String> aids,
    List<BookshelfEntityData> books,
  ) {
    final bookAids = books.map((book) => book.aid).toSet();
    final seen = <String>{};
    return [
      for (final aid in aids)
        if (bookAids.contains(aid) && seen.add(aid)) aid,
    ];
  }

  String _getSmartFolderTagById(String folderId) {
    final saved = LocalStorageService.instance.getBookshelfFolders();
    for (final item in saved) {
      if (item['id'] == folderId) {
        return item['tag'] ?? folderId.substring(smartTagPrefix.length);
      }
    }
    if (!folderId.startsWith(smartTagPrefix)) return '';
    return folderId.substring(smartTagPrefix.length);
  }

  SmartShelfConfig _smartShelfConfigFromFolder(Map<String, String> folder) {
    final raw = folder['smartConfig'];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return SmartShelfConfig.fromJson(decoded);
      } catch (_) {
        // Fall through to the legacy single-tag format.
      }
    }
    final tag = folder['tag'] ?? '';
    if (tag.isNotEmpty) return SmartShelfConfig.tag(tag);
    return const SmartShelfConfig();
  }

  Map<String, SmartShelfMembership> _membershipByAid(String folderId) {
    return {
      for (final item in LocalStorageService.instance.getSmartShelfMembership(
        folderId,
      ))
        if ((item['aid'] ?? '').isNotEmpty)
          item['aid']!: SmartShelfMembership.fromJson(item),
    };
  }

  static String _sourceLabelOfAidStatic(String aid) {
    return switch (SourceFavoriteAdapter.sourceOfAid(aid)) {
      NovelSource.wenku8 => 'wenku8'.tr,
      NovelSource.esj => 'esjzone'.tr,
      NovelSource.yamibo => 'yamibo_forum'.tr,
    };
  }

  Future<List<String>> _getBookshelfAidsByTag(String tag) async {
    final books = await DBService.instance.getAllBookshelf();
    final directMatches = books
        .where(
          (book) => BookTags.containsAny(
            BookTags.merge(
              BookTags.decode(book.remoteTagsJson),
              BookTags.decode(book.localTagsJson),
            ),
            [tag],
          ),
        )
        .map((book) => book.aid)
        .toSet();
    final details = await DBService.instance.getAllNovelDetails();
    final aids = <String>[];
    for (final detail in details) {
      try {
        final json = jsonDecode(detail.json) as Map<String, dynamic>;
        final tags =
            (json['tags'] as List<dynamic>?)
                ?.map((t) => t.toString())
                .toList() ??
            [];
        if (BookTags.containsAny(tags, [tag])) aids.add(detail.aid);
      } catch (_) {
        continue;
      }
    }
    return {...directMatches, ...aids}.toList();
  }

  Future<List<String>> _getBookshelfAidsBySmartConfig(
    SmartShelfConfig config,
  ) async {
    final books = await DBService.instance.getAllBookshelf();
    final details = {
      for (final detail in await DBService.instance.getAllNovelDetails())
        detail.aid: detail,
    };
    final items = books.map((book) {
      final detail = details[book.aid];
      final parsedDetail = detail == null
          ? null
          : () {
              try {
                return NovelDetail.fromString(detail.json);
              } catch (_) {
                return null;
              }
            }();
      return BookshelfNovelInfo(
        bid: book.bid,
        aid: book.aid,
        url: book.url,
        title: book.title,
        img: book.img,
        updateKey: book.updateKey,
        updateTime: book.updateTime,
        hasUpdate: book.hasUpdate,
        author: parsedDetail?.author ?? '',
        sourceLabel: _sourceLabelOfAidStatic(book.aid),
        rating: book.rating,
        remoteTags: BookTags.merge(
          BookTags.decode(book.remoteTagsJson),
          parsedDetail?.tags ?? const [],
        ),
        localTags: BookTags.decode(book.localTagsJson),
      );
    });
    return items.where(config.matches).map((item) => item.aid).toSet().toList();
  }

  Future<List<String>> _getRecentReadAids(int limit) async {
    final history = await DBService.instance.getRecentBrowsingHistory(limit);
    return history.map((h) => h.aid).toList();
  }

  static Future<Map<String, DateTime>> _getRecentReadTimes() async {
    final history = await DBService.instance.getRecentBrowsingHistory(1000);
    return {for (final item in history) item.aid: item.time};
  }

  Future<void> refreshDefaultBookshelf() async {
    if (!SourceConfigService.instance.shouldPullOnlineToLocal(
      NovelSource.wenku8,
    )) {
      return;
    }
    await _syncWenku8Shelf(0);
  }

  Future<String> refreshCurrentBookshelf() async {
    final folder = currentFolder.value;
    if (folder == null) return refreshBookshelf();
    return refreshFolder(folder);
  }

  Future<String> refreshFolder(BookshelfFolder folder) async {
    _clearSyncError(folder.id);
    _setSyncProgress(folder.id, message: "refresh_bookshelf_tip".tr);
    try {
      final ok = await _refreshFolder(folder);
      await loadFolders();
      return _syncResultMessage(ok, folder.id);
    } finally {
      _clearSyncProgress(folder.id);
    }
  }

  Future<String> refreshSource(NovelSource source) async {
    final folderId = switch (source) {
      NovelSource.wenku8 => defaultClassId,
      NovelSource.yamibo => yamiboClassId,
      NovelSource.esj => esjClassId,
    };
    _clearSyncError(folderId);
    _setSyncProgress(folderId, message: "refresh_bookshelf_tip".tr);
    try {
      bool ok;
      switch (source) {
        case NovelSource.wenku8:
          final results = await Future.wait(
            Iterable.generate(6, (index) => _syncWenku8Shelf(index)),
          );
          ok = results.every((item) => item);
        case NovelSource.yamibo:
          ok = await refreshYamiboFavorites(
            onProgress: (value, message) =>
                _setSyncProgress(folderId, value: value, message: message),
          );
        case NovelSource.esj:
          ok = await refreshEsjFavorites(
            onProgress: (value, message) =>
                _setSyncProgress(folderId, value: value, message: message),
          );
      }
      await loadFolders();
      return _syncResultMessage(ok, folderId);
    } finally {
      _clearSyncProgress(folderId);
    }
  }

  Future<bool> _refreshFolder(BookshelfFolder folder) async {
    if (folder.id == defaultClassId) {
      return _syncWenku8Shelf(0);
    }
    if (folder.id == yamiboClassId) {
      return refreshYamiboFavorites(
        onProgress: (value, message) =>
            _setSyncProgress(folder.id, value: value, message: message),
      );
    }
    if (folder.id == esjClassId) {
      return refreshEsjFavorites(
        onProgress: (value, message) =>
            _setSyncProgress(folder.id, value: value, message: message),
      );
    }
    if (folder.id.startsWith(subscriptionShelfPrefix)) {
      return syncSubscriptionSmartShelves(onlyFolderId: folder.id);
    }
    final aids = await _getFolderAids(folder);
    return _refreshExistingBooksByAid(aids);
  }

  Future<String> refreshBookshelf() async {
    final tasks = <Future<bool>>[];
    _clearSyncError(defaultClassId);
    _clearSyncError(yamiboClassId);
    _clearSyncError(esjClassId);
    if (SourceConfigService.instance.shouldPullOnlineToLocal(
      NovelSource.wenku8,
    )) {
      _setSyncProgress(defaultClassId, message: "refresh_bookshelf_tip".tr);
      tasks.addAll(Iterable.generate(6, (index) => _syncWenku8Shelf(index)));
    }
    if (SourceConfigService.instance.shouldPullOnlineToLocal(
      NovelSource.yamibo,
    )) {
      _setSyncProgress(yamiboClassId, message: "refresh_bookshelf_tip".tr);
      tasks.add(
        refreshYamiboFavorites(
          onProgress: (value, message) =>
              _setSyncProgress(yamiboClassId, value: value, message: message),
        ),
      );
    }
    if (SourceConfigService.instance.shouldPullOnlineToLocal(NovelSource.esj)) {
      _setSyncProgress(esjClassId, message: "refresh_bookshelf_tip".tr);
      tasks.add(
        refreshEsjFavorites(
          onProgress: (value, message) =>
              _setSyncProgress(esjClassId, value: value, message: message),
        ),
      );
    }
    try {
      final results = await Future.wait(tasks);
      final subscriptionOk = await syncSubscriptionSmartShelves();
      if (!subscriptionOk &&
          syncErrors[defaultClassId] == null &&
          syncErrors.isNotEmpty) {
        _setSyncError(defaultClassId, syncErrors.values.first);
      }
      await loadFolders();
      return results.every((ok) => ok) && subscriptionOk
          ? "update_successfully".tr
          : _syncResultMessage(false, defaultClassId);
    } finally {
      _clearSyncProgress(defaultClassId);
      _clearSyncProgress(yamiboClassId);
      _clearSyncProgress(esjClassId);
    }
  }

  Future<bool> syncSubscriptionSmartShelves({String? onlyFolderId}) async {
    final saved = LocalStorageService.instance.getBookshelfFolders();
    var allOk = true;
    for (final folder in saved) {
      final id = folder['id'] ?? '';
      if (onlyFolderId != null && id != onlyFolderId) continue;
      final config = _smartShelfConfigFromFolder(folder);
      if (!config.isSubscription) continue;
      final tags = config.subscriptionTags.isNotEmpty
          ? config.subscriptionTags
          : _tagsFromSmartConfig(config);
      if (tags.isEmpty) continue;
      final enabledSources = SourceConfigService.instance.enabledSources;
      final sourceScope = config.sources.isEmpty
          ? enabledSources
          : config.sources
                .where((source) => enabledSources.contains(source))
                .toList();
      if (onlyFolderId == null &&
          _shouldSkipRecentYamiboSubscription(id, sourceScope)) {
        _setSyncProgress(
          id,
          message: "smart_subscription_skip_recent".trParams({
            "time": _smartSubscriptionIntervalLabel(
              LocalStorageService.instance
                  .getSmartSubscriptionMinSyncIntervalSeconds(),
            ),
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 600));
        _clearSyncProgress(id);
        continue;
      }
      final previous = {
        for (final item in LocalStorageService.instance.getSmartShelfMembership(
          id,
        ))
          if ((item['aid'] ?? '').isNotEmpty) item['aid']!: item,
      };
      final candidates = <String, _SubscriptionCandidate>{};
      var folderOk = true;
      _setSyncProgress(id, message: "refresh_bookshelf_tip".tr);
      for (final source in sourceScope) {
        final sourceResult = await _searchSubscriptionSource(
          source,
          tags,
          config,
          folderId: id,
        );
        if (sourceResult.failed) {
          folderOk = false;
          allOk = false;
          _setSyncError(
            id,
            sourceResult.errorMessage ?? '${source.titleKey.tr} failed',
          );
        }
        for (final candidate in sourceResult.candidates.values) {
          candidates[candidate.cover.aid] = candidate;
          await _upsertSubscriptionCover(
            candidate.cover,
            source,
            candidate.tags,
          );
        }
      }
      final now = DateTime.now().toIso8601String();
      if (!folderOk && candidates.isEmpty && previous.isNotEmpty) {
        allOk = false;
        _clearSyncProgress(id);
        continue;
      }
      final nextByAid = <String, Map<String, String>>{
        if (config.isSubscriptionIncremental) ...previous,
      };
      for (final aid in candidates.keys) {
        final old = previous[aid];
        nextByAid[aid] = {
          'aid': aid,
          'firstSeenAt': old?['firstSeenAt'] ?? now,
          'lastSeenAt': now,
          'isNew': old == null ? 'true' : (old['isNew'] ?? 'false'),
        };
      }
      LocalStorageService.instance.setSmartShelfMembership(
        id,
        nextByAid.values.toList(),
      );
      if (folderOk) {
        LocalStorageService.instance.setSmartShelfLastSuccessfulSyncAt(
          id,
          DateTime.now(),
        );
      }
      _clearSyncProgress(id);
    }
    return allOk;
  }

  bool _shouldSkipRecentYamiboSubscription(
    String folderId,
    List<NovelSource> sourceScope,
  ) {
    if (!sourceScope.contains(NovelSource.yamibo)) return false;
    final seconds = LocalStorageService.instance
        .getSmartSubscriptionMinSyncIntervalSeconds();
    if (seconds <= 0) return false;
    final last = LocalStorageService.instance.getSmartShelfLastSuccessfulSyncAt(
      folderId,
    );
    if (last == null) return false;
    return DateTime.now().difference(last) < Duration(seconds: seconds);
  }

  static String _smartSubscriptionIntervalLabel(int seconds) {
    return switch (seconds) {
      <= 0 => "smart_subscription_interval_none".tr,
      600 => "smart_subscription_interval_10m".tr,
      1800 => "smart_subscription_interval_30m".tr,
      3600 => "smart_subscription_interval_1h".tr,
      10800 => "smart_subscription_interval_3h".tr,
      21600 => "smart_subscription_interval_6h".tr,
      86400 => "smart_subscription_interval_24h".tr,
      _ => "${seconds}s",
    };
  }

  Future<_SubscriptionSearchResult> _searchSubscriptionSource(
    NovelSource source,
    List<String> tags,
    SmartShelfConfig config, {
    required String folderId,
  }) async {
    if (source == NovelSource.yamibo) {
      return _searchYamiboDeepSubscription(tags, config, folderId: folderId);
    }
    final candidates = <String, _SubscriptionCandidate>{};
    try {
      for (final tag in tags) {
        final covers = await _searchSubscriptionTagPages(
          source,
          tag,
          config,
          folderId: folderId,
        );
        for (final cover in covers) {
          final candidate = candidates.putIfAbsent(
            cover.aid,
            () => _SubscriptionCandidate(cover),
          );
          candidate.tags.add(tag);
          candidate.tags.addAll(_sourceSectionConditionValues(source, config));
        }
      }
    } on _SubscriptionSearchException catch (e) {
      return _SubscriptionSearchResult(
        candidates,
        failed: true,
        errorMessage: e.message,
      );
    }
    final requireAllTags = _subscriptionRequiresAllTags(config);
    candidates.removeWhere((_, candidate) {
      return requireAllTags
          ? !BookTags.containsAll(candidate.tags, tags)
          : !BookTags.containsAny(candidate.tags, tags);
    });
    return _SubscriptionSearchResult(candidates);
  }

  Future<_SubscriptionSearchResult> _searchYamiboDeepSubscription(
    List<String> tags,
    SmartShelfConfig config, {
    required String folderId,
  }) async {
    if (!YamiboApi.hasCookie) {
      SourceAuthGuard.clearLogin(NovelSource.yamibo);
      SourceAuthGuard.showLoginRequired(NovelSource.yamibo);
      return _SubscriptionSearchResult(
        const {},
        failed: true,
        errorMessage: 'Yamibo ${"source_login_required".tr}',
      );
    }
    final effectiveTags = yamiboSubscriptionSearchTags(tags);
    if (effectiveTags.isEmpty) return const _SubscriptionSearchResult({});
    final searchResults = <String, NovelCover>{};
    final forumIds = _yamiboForumIdsForConfig(config);
    const maxPages = 3;
    const maxCandidates = 120;
    var failed = false;
    String? errorMessage;

    for (final tag in effectiveTags) {
      for (final query in BookTags.queryVariants(tag)) {
        String? searchId;
        for (var page = 1; page <= maxPages; page++) {
          _setSyncProgress(
            folderId,
            message: '${"refresh_bookshelf_tip".tr} ${searchResults.length}',
          );
          await _waitForYamiboSubscriptionSearchSlot(folderId);
          final result = await YamiboApi.searchThreads(
            keyword: query,
            page: page,
            searchId: page == 1 ? null : searchId,
            forumIds: forumIds,
          );
          if (result is! Success || result.data is! YamiboSearchPageResponse) {
            failed = true;
            errorMessage = result is Error && result.error != null
                ? '${result.error}'
                : 'Yamibo search request failed';
            break;
          }
          final response = result.data as YamiboSearchPageResponse;
          if (YamiboParser.isUnavailableDuringDailyBackup(response.html)) {
            failed = true;
            errorMessage = 'Yamibo ${"yamibo_backup_window".tr}';
            break;
          }
          if (!SourceAuthGuard.checkHtml(NovelSource.yamibo, response.html)) {
            failed = true;
            errorMessage = 'Yamibo ${"source_login_required".tr}';
            break;
          }
          if (YamiboParser.isSearchTooQuicklyPage(response.html)) {
            failed = true;
            errorMessage = 'Yamibo search too quickly';
            break;
          }
          final parsed = YamiboParser.getSearchPageData(
            response.html,
            allowedForumIds: forumIds.toSet(),
          );
          searchId = response.searchId ?? parsed.searchId ?? searchId;
          for (final cover in parsed.items) {
            searchResults[cover.aid] = cover;
            if (searchResults.length >= maxCandidates) break;
          }
          if (!parsed.hasMore ||
              searchId == null ||
              searchResults.length >= maxCandidates) {
            break;
          }
        }
        if (failed || searchResults.length >= maxCandidates) break;
      }
      if (failed || searchResults.length >= maxCandidates) break;
    }

    var checked = 0;
    List<_SubscriptionCandidate?> candidates;
    try {
      candidates = await _mapConcurrent(searchResults.values.toList(), 3, (
        cover,
      ) async {
        final candidate = await _matchYamiboSubscriptionCandidate(
          cover,
          tags,
          effectiveTags,
          config,
        );
        checked += 1;
        final total = searchResults.length;
        _setSyncProgress(
          folderId,
          value: total <= 0 ? null : (checked / total).clamp(0.0, 1.0),
          message: '$checked / $total',
        );
        return candidate;
      });
    } on _SubscriptionSearchException catch (e) {
      candidates = const [];
      failed = true;
      errorMessage = e.message;
    }
    return _SubscriptionSearchResult(
      {
        for (final item in candidates.whereType<_SubscriptionCandidate>())
          item.cover.aid: item,
      },
      failed: failed,
      errorMessage: errorMessage,
    );
  }

  Future<_SubscriptionCandidate?> _matchYamiboSubscriptionCandidate(
    NovelCover cover,
    List<String> originalTags,
    List<String> effectiveTags,
    SmartShelfConfig config,
  ) async {
    final tid = SourceId.yamiboTid(cover.aid);
    if (tid.isEmpty) return null;
    final result = await YamiboApi.getThreadPage(tid: tid).timeout(
      const Duration(seconds: 12),
      onTimeout: () => const Error('timeout'),
    );
    if (result is! Success) return null;
    if (!SourceAuthGuard.checkHtml(NovelSource.yamibo, result.data)) {
      return null;
    }
    if (YamiboParser.isUnavailableDuringDailyBackup(result.data)) {
      throw _SubscriptionSearchException('Yamibo ${"yamibo_backup_window".tr}');
    }
    final error = YamiboParser.threadErrorMessage(result.data);
    if (error?.isNotEmpty == true) return null;

    late final YamiboThreadData detail;
    late final Content content;
    try {
      detail = YamiboParser.getThreadDetail(result.data);
      content = YamiboParser.getThreadContent(
        result.data,
        authorId: detail.authorId,
      );
    } catch (_) {
      return null;
    }
    final matchText = [
      detail.detail.title,
      detail.detail.author,
      detail.detail.status,
      detail.detail.tags.join(' '),
      detail.detail.introduce,
      content.text,
    ].join('\n');
    final matchedTags = matchedYamiboSubscriptionTags(
      originalTags: originalTags,
      detailTags: detail.detail.tags,
      matchText: matchText,
    );
    final requireAllTags = _subscriptionRequiresAllTags(config);
    final matched = requireAllTags
        ? BookTags.containsAll(matchedTags, originalTags)
        : BookTags.containsAny(matchedTags, originalTags);
    if (!matched) return null;

    final candidate = _SubscriptionCandidate(
      NovelCover(detail.detail.title, '', cover.aid),
    );
    candidate.tags.addAll([
      'Yamibo',
      '百合',
      ...detail.detail.tags,
      ...matchedTags,
      ...effectiveTags,
      ..._sourceSectionConditionValues(NovelSource.yamibo, config),
    ]);
    return candidate;
  }

  static Set<String> matchedYamiboSubscriptionTags({
    required Iterable<String> originalTags,
    required Iterable<String> detailTags,
    required String matchText,
  }) {
    final searchableDetailTags = detailTags.where(
      (tag) => !_isYamiboDisplayOnlyTag(tag),
    );
    return {
      if (BookTags.containsAny(originalTags, ['百合'])) '百合',
      for (final tag in BookTags.normalize(originalTags))
        if (!_isYamiboDefaultTag(tag) &&
            (BookTags.containsAny(searchableDetailTags, [tag]) ||
                BookTags.containsAny([matchText], [tag])))
          tag,
    };
  }

  static List<String> yamiboSubscriptionSearchTags(List<String> tags) {
    final normalized = BookTags.normalize(
      tags.where((tag) => !_isYamiboDefaultTag(tag)),
    );
    final specificTags = normalized
        .where((tag) => !_isYamiboInherentTag(tag))
        .toList(growable: false);
    return specificTags.isNotEmpty ? specificTags : normalized;
  }

  static bool _isYamiboDefaultTag(String tag) =>
      BookTags.containsAny(['Yamibo'], [tag]);

  static bool _isYamiboInherentTag(String tag) =>
      BookTags.containsAny(['百合'], [tag]);

  static bool _isYamiboDisplayOnlyTag(String tag) =>
      BookTags.containsAny(['Yamibo', '百合', '论坛主题'], [tag]);

  List<String> _yamiboForumIdsForConfig(SmartShelfConfig config) {
    final sections = _sourceSectionValues(config, NovelSource.yamibo);
    if (sections.isEmpty) {
      return const [
        YamiboApi.literatureFid,
        YamiboApi.lightNovelFid,
        YamiboApi.txtNovelFid,
      ];
    }
    return sections;
  }

  bool _subscriptionRequiresAllTags(SmartShelfConfig config) {
    if (config.mode == SmartShelfMatchMode.any) return false;
    final tagGroups = config.groups.where(
      (group) => group.conditions.any(
        (condition) => condition.type == SmartShelfConditionType.tag,
      ),
    );
    if (tagGroups.isEmpty) return true;
    return tagGroups.every((group) => group.mode == SmartShelfMatchMode.all);
  }

  List<String> _tagsFromSmartConfig(SmartShelfConfig config) {
    return BookTags.normalize([
      for (final group in config.groups)
        for (final condition in group.conditions)
          if (condition.type == SmartShelfConditionType.tag) condition.value,
    ]);
  }

  Future<List<NovelCover>> _searchSubscriptionTag(
    NovelSource source,
    String tag,
    int page,
    SmartShelfConfig config, {
    required String folderId,
  }) async {
    late final String? requestUrl;
    requestUrl = switch (source) {
      NovelSource.wenku8 => Api.getNovelByCategoryUrl(
        category: tag,
        sort: '0',
        index: page,
      ),
      _ => null,
    };
    if (source == NovelSource.yamibo) {
      await _waitForYamiboSubscriptionSearchSlot(folderId);
    }
    final result = switch (source) {
      NovelSource.wenku8 => await Api.getNovelByCategory(
        category: tag,
        sort: '0',
        index: page,
      ),
      NovelSource.esj => await EsjApi.searchNovel(
        keyword: tag,
        page: page,
        type: _esjTypeForConfig(config),
      ),
      NovelSource.yamibo => await YamiboApi.searchThreads(
        keyword: tag,
        page: page,
        forumIds: _yamiboForumIdsForConfig(config),
      ),
    };
    if (result is! Success) {
      if (source == NovelSource.wenku8 &&
          requestUrl != null &&
          _isBrowserAssistedError('${result is Error ? result.error : ''}')) {
        _setSyncAssistUrl(folderId, requestUrl);
      }
      throw _SubscriptionSearchException(
        '${source.titleKey.tr}: ${result is Error && result.error != null ? result.error : "update_failed".tr}',
      );
    }
    return switch (source) {
      NovelSource.wenku8 =>
        SourceAuthGuard.checkHtml(source, result.data)
            ? Parser.parseToList(result.data)
            : throw _SubscriptionSearchException(
                '${source.titleKey.tr}: ${"source_login_required".tr}',
              ),
      NovelSource.esj =>
        SourceAuthGuard.checkHtml(source, result.data)
            ? EsjParser.getSearchResults(result.data)
            : throw _SubscriptionSearchException(
                '${source.titleKey.tr}: ${"source_login_required".tr}',
              ),
      NovelSource.yamibo =>
        result.data is YamiboSearchPageResponse
            ? (SourceAuthGuard.checkHtml(
                    source,
                    (result.data as YamiboSearchPageResponse).html,
                  )
                  ? YamiboParser.getSearchPageData(
                      (result.data as YamiboSearchPageResponse).html,
                      allowedForumIds: _yamiboForumIdsForConfig(config).toSet(),
                    ).items
                  : throw _SubscriptionSearchException(
                      '${source.titleKey.tr}: ${"source_login_required".tr}',
                    ))
            : const <NovelCover>[],
    };
  }

  Future<void> _waitForYamiboSubscriptionSearchSlot(String folderId) {
    final next = _yamiboSubscriptionSearchQueue.then((_) async {
      while (true) {
        final last = _lastYamiboSubscriptionSearchAt;
        if (last == null) break;
        final elapsed = DateTime.now().difference(last);
        final remaining = _yamiboSubscriptionSearchInterval - elapsed;
        if (remaining <= Duration.zero) break;
        final seconds =
            remaining.inSeconds +
            (remaining.inMilliseconds % 1000 == 0 ? 0 : 1);
        _setSyncProgress(
          folderId,
          message: "yamibo_search_throttle_wait".trParams({
            "seconds": '$seconds',
          }),
        );
        await Future<void>.delayed(
          remaining > const Duration(seconds: 1)
              ? const Duration(seconds: 1)
              : remaining,
        );
      }
      _lastYamiboSubscriptionSearchAt = DateTime.now();
    });
    _yamiboSubscriptionSearchQueue = next.catchError((_) {});
    return next;
  }

  bool _isBrowserAssistedError(String error) =>
      error.contains(cloudflare403ExceptionMessage) ||
      error.contains(cloudflareChallengeExceptionMessage);

  Future<List<NovelCover>> _searchSubscriptionTagPages(
    NovelSource source,
    String tag,
    SmartShelfConfig config, {
    required String folderId,
  }) async {
    final byAid = <String, NovelCover>{};
    final variants = BookTags.queryVariants(tag);
    final maxPages = switch (source) {
      NovelSource.yamibo => 1,
      NovelSource.wenku8 || NovelSource.esj => 3,
    };
    for (final query in variants) {
      for (var page = 1; page <= maxPages; page++) {
        final covers = await _searchSubscriptionTag(
          source,
          query,
          page,
          config,
          folderId: folderId,
        );
        if (covers.isEmpty) break;
        for (final cover in covers) {
          byAid[cover.aid] = cover;
        }
      }
    }
    return byAid.values.toList();
  }

  int _esjTypeForConfig(SmartShelfConfig config) {
    final sections = _sourceSectionValues(config, NovelSource.esj);
    if (sections.isEmpty) return 0;
    return int.tryParse(sections.first) ?? 0;
  }

  List<String> _sourceSectionValues(
    SmartShelfConfig config,
    NovelSource source,
  ) {
    final prefix = '${source.id}:';
    return [
      for (final group in config.groups)
        for (final condition in group.conditions)
          if (condition.type == SmartShelfConditionType.section &&
              condition.value.startsWith(prefix))
            condition.value.substring(prefix.length),
    ];
  }

  List<String> _sourceSectionConditionValues(
    NovelSource source,
    SmartShelfConfig config,
  ) {
    final prefix = '${source.id}:';
    return [
      for (final group in config.groups)
        for (final condition in group.conditions)
          if (condition.type == SmartShelfConditionType.section &&
              condition.value.startsWith(prefix))
            condition.value,
    ];
  }

  Future<void> _upsertSubscriptionCover(
    NovelCover cover,
    NovelSource source,
    Iterable<String> tags,
  ) async {
    final previous = (await DBService.instance.getAllBookshelf())
        .firstWhereOrNull((item) => item.aid == cover.aid);
    final addToSourceShelf = LocalStorageService.instance
        .getSmartSubscriptionAddsToSourceShelf();
    await DBService.instance.upsertBookshelf(
      BookshelfEntityData(
        aid: cover.aid,
        bid: previous?.bid ?? cover.aid,
        url: previous?.url ?? '',
        title: cover.title,
        img: _syncedImageFor(source, cover.imageUrl, previous),
        classId:
            previous?.classId ??
            (addToSourceShelf
                ? switch (source) {
                    NovelSource.wenku8 => defaultClassId,
                    NovelSource.esj => esjClassId,
                    NovelSource.yamibo => yamiboClassId,
                  }
                : _subscriptionCacheClassId),
        updateKey: previous?.updateKey ?? '',
        updateTime: previous?.updateTime,
        hasUpdate: previous?.hasUpdate ?? false,
        rating: previous?.rating ?? 0,
        remoteTagsJson: BookTags.encode([
          ...BookTags.decode(previous?.remoteTagsJson),
          ...tags,
          source.titleKey.tr,
          if (source == NovelSource.yamibo) ...[
            '百合',
            ...YamiboParser.yamiboTags(YamiboParser.safeTitleTags(cover.title)),
          ],
          ..._sectionTagsForSource(source, tags),
        ]),
        localTagsJson: previous?.localTagsJson ?? BookTags.emptyJson,
      ),
    );
  }

  List<String> _sectionTagsForSource(
    NovelSource source,
    Iterable<String> tags,
  ) {
    final sourcePrefix = '${source.id}:';
    return [
      for (final tag in tags)
        if (tag.startsWith(sourcePrefix)) tag,
    ];
  }

  Future<bool> _syncWenku8Shelf(int classId) async {
    if (!SourceConfigService.instance.shouldPullOnlineToLocal(
      NovelSource.wenku8,
    )) {
      return true;
    }
    final result = await Api.getBookshelf(classId: classId);
    if (result is! Success) return false;
    if (!SourceAuthGuard.checkHtml(NovelSource.wenku8, result.data)) {
      return false;
    }
    final previous = {
      for (final item in await DBService.instance.getAllBookshelf())
        item.aid: item,
    };
    final bookshelf = Parser.getBookshelf(result.data, classId);
    final remoteAids = <String>{};
    for (final e in bookshelf.list) {
      remoteAids.add(e.aid);
      if (SourceConfigService.instance.isLocallyHidden(
        NovelSource.wenku8,
        e.aid,
      )) {
        continue;
      }
      final prev = previous[e.aid];
      final keepLocal = prev?.classId.startsWith(_localFolderPrefix) == true;
      await DBService.instance.upsertBookshelf(
        BookshelfEntityData(
          aid: e.aid,
          bid: e.bid,
          url: e.url,
          title: e.title,
          img: _syncedImageFor(NovelSource.wenku8, e.img, prev),
          classId: keepLocal ? prev!.classId : classId.toString(),
          updateKey: e.updateKey,
          updateTime: e.updateTime,
          hasUpdate: _hasBookshelfUpdate(prev, e.updateKey),
          rating: prev?.rating ?? 0,
          remoteTagsJson: _remoteTagsJsonFor(e, prev),
          localTagsJson: prev?.localTagsJson ?? BookTags.emptyJson,
        ),
      );
    }
    await _removeMissingRemoteWenku8Items(classId, remoteAids, previous);
    return true;
  }

  Future<bool> _refreshExistingBooksByAid(Iterable<String> aids) async {
    final aidSet = aids.toSet();
    if (aidSet.isEmpty) return true;
    var ok = true;
    if (aidSet.any(
      (aid) => SourceFavoriteAdapter.sourceOfAid(aid) == NovelSource.wenku8,
    )) {
      ok = await _refreshExistingWenku8BooksByAid(aidSet) && ok;
    }
    if (aidSet.any(
      (aid) => SourceFavoriteAdapter.sourceOfAid(aid) == NovelSource.esj,
    )) {
      ok = await syncEsjFavoritesToBookshelf(onlyAids: aidSet) && ok;
    }
    if (aidSet.any(
      (aid) => SourceFavoriteAdapter.sourceOfAid(aid) == NovelSource.yamibo,
    )) {
      ok = await syncYamiboFavoritesToBookshelf(onlyAids: aidSet) && ok;
    }
    return ok;
  }

  Future<bool> _refreshExistingWenku8BooksByAid(Set<String> aids) async {
    if (!SourceConfigService.instance.shouldPullOnlineToLocal(
      NovelSource.wenku8,
    )) {
      return true;
    }
    final previous = {
      for (final item in await DBService.instance.getAllBookshelf())
        item.aid: item,
    };
    var ok = true;
    for (var classId = 0; classId < 6; classId++) {
      final result = await Api.getBookshelf(classId: classId);
      if (result is! Success) {
        ok = false;
        continue;
      }
      if (!SourceAuthGuard.checkHtml(NovelSource.wenku8, result.data)) {
        return false;
      }
      final bookshelf = Parser.getBookshelf(result.data, classId);
      for (final item in bookshelf.list) {
        if (!aids.contains(item.aid)) continue;
        final prev = previous[item.aid];
        await DBService.instance.upsertBookshelf(
          BookshelfEntityData(
            aid: item.aid,
            bid: item.bid,
            url: item.url,
            title: item.title,
            img: _syncedImageFor(NovelSource.wenku8, item.img, prev),
            classId: prev?.classId ?? classId.toString(),
            updateKey: item.updateKey,
            updateTime: item.updateTime,
            hasUpdate: _hasBookshelfUpdate(prev, item.updateKey),
            rating: prev?.rating ?? 0,
            remoteTagsJson: _remoteTagsJsonFor(item, prev),
            localTagsJson: prev?.localTagsJson ?? BookTags.emptyJson,
          ),
        );
      }
    }
    return ok;
  }

  Future<void> _removeMissingRemoteWenku8Items(
    int classId,
    Set<String> remoteAids,
    Map<String, BookshelfEntityData> previous,
  ) async {
    if (classId == 0) return;
    for (final item in previous.values) {
      if (item.classId == classId.toString() &&
          !remoteAids.contains(item.aid) &&
          !SourceConfigService.instance.isLocallyHidden(
            NovelSource.wenku8,
            item.aid,
          )) {
        await DBService.instance.deleteBookshelfByAid(item.aid);
      }
    }
  }

  Future<bool> refreshYamiboFavorites({
    void Function(double? value, String message)? onProgress,
  }) async {
    final ok = await syncYamiboFavoritesToBookshelf(
      onProgress: onProgress,
      onError: (message) => _setSyncError(yamiboClassId, message),
    );
    if (!ok && YamiboParser.isDailyBackupWindow()) {
      _setSyncError(yamiboClassId, 'Yamibo ${"yamibo_backup_window".tr}');
    }
    return ok;
  }

  Future<bool> refreshEsjFavorites({
    void Function(double? value, String message)? onProgress,
  }) => syncEsjFavoritesToBookshelf(onProgress: onProgress);

  static Future<bool> syncEsjFavoritesToBookshelf({
    Set<String>? onlyAids,
    void Function(double? value, String message)? onProgress,
  }) async {
    if (!SourceConfigService.instance.shouldPullOnlineToLocal(
      NovelSource.esj,
    )) {
      return true;
    }
    if (!EsjApi.hasCookie) {
      SourceAuthGuard.clearLogin(NovelSource.esj);
      SourceAuthGuard.showLoginRequired(NovelSource.esj);
      return false;
    }
    final previous = {
      for (final item in await DBService.instance.getAllBookshelf())
        item.aid: item,
    };
    final favorites = <String, BookshelfNovelInfo>{};
    var page = 1;
    var done = false;

    while (!done) {
      final result = await EsjApi.getFavoritePage(page: page);
      switch (result) {
        case Success():
          if (!SourceAuthGuard.checkHtml(NovelSource.esj, result.data)) {
            return false;
          }
          onProgress?.call(null, '${"refresh_bookshelf_tip".tr} $page');
          final List<BookshelfNovelInfo> items;
          try {
            items = EsjParser.getFavoritePage(result.data);
          } catch (_) {
            return false;
          }
          if (items.isEmpty) {
            done = true;
            break;
          }
          final beforeCount = favorites.length;
          for (final item in items) {
            favorites[item.aid] = item;
          }
          if (favorites.length == beforeCount) done = true;
          page += 1;
        case Error():
          return false;
      }
    }

    for (final item in favorites.values) {
      if (onlyAids != null && !onlyAids.contains(item.aid)) continue;
      if (SourceConfigService.instance.isLocallyHidden(
        NovelSource.esj,
        item.aid,
      )) {
        continue;
      }
      final prev = previous[item.aid];
      final keepLocal =
          prev?.classId == defaultClassId ||
          prev?.classId.startsWith(_localFolderPrefix) == true;
      await DBService.instance.upsertBookshelf(
        BookshelfEntityData(
          aid: item.aid,
          bid: item.bid,
          url: item.url,
          title: item.title,
          img: _syncedImageFor(NovelSource.esj, item.img, prev),
          classId: keepLocal ? prev!.classId : esjClassId,
          updateKey: item.updateKey,
          updateTime: item.updateTime,
          hasUpdate: _hasBookshelfUpdate(prev, item.updateKey),
          rating: prev?.rating ?? 0,
          remoteTagsJson: _remoteTagsJsonFor(item, prev),
          localTagsJson: prev?.localTagsJson ?? BookTags.emptyJson,
        ),
      );
    }
    if (onlyAids == null && favorites.isNotEmpty) {
      for (final item in previous.values) {
        if (item.classId == esjClassId && !favorites.containsKey(item.aid)) {
          await DBService.instance.deleteBookshelfByAid(item.aid);
        }
      }
    }
    if (onlyAids == null && !await syncEsjViewHistoryToLocal()) return false;
    return true;
  }

  static Future<bool> syncEsjViewHistoryToLocal() async {
    if (!EsjApi.hasCookie) return true;
    final result = await EsjApi.getViewHistory();
    switch (result) {
      case Success():
        final List<EsjReadHistory> histories;
        try {
          histories = EsjParser.getViewHistory(result.data);
        } catch (_) {
          return false;
        }
        final bookshelf = {
          for (final item in await DBService.instance.getAllBookshelf())
            item.aid: item,
        };
        final readerMode =
            LocalStorageService.instance.getReaderDirection() ==
                ReaderDirection.upToDown
            ? kScrollReadMode
            : kPageReadMode;
        for (final history in histories) {
          final existing = await DBService.instance.getReadHistoryByCid(
            history.aid,
            history.cid,
          );
          await DBService.instance.upsertReadHistory(
            existing?.copyWith(isLatest: true) ??
                ReadHistoryEntityData(
                  cid: history.cid,
                  aid: history.aid,
                  readerMode: readerMode,
                  isDualPage: false,
                  location: 0,
                  progress: 0,
                  isLatest: true,
                ),
          );
          final shelfItem = bookshelf[history.aid];
          await DBService.instance.upsertBrowsingHistory(
            BrowsingHistoryEntityData(
              aid: history.aid,
              title: history.title,
              img: shelfItem?.img ?? EsjApi.logoUrl,
              time: DateTime.now(),
            ),
          );
        }
        return true;
      case Error():
        return false;
    }
  }

  static Future<bool> syncYamiboFavoritesToBookshelf({
    Set<String>? onlyAids,
    void Function(double? value, String message)? onProgress,
    void Function(String message)? onError,
  }) async {
    if (!SourceConfigService.instance.shouldPullOnlineToLocal(
      NovelSource.yamibo,
    )) {
      return true;
    }
    if (!YamiboApi.hasCookie) {
      onError?.call('Yamibo ${"source_login_required".tr}');
      SourceAuthGuard.clearLogin(NovelSource.yamibo);
      SourceAuthGuard.showLoginRequired(NovelSource.yamibo);
      return false;
    }
    final previous = {
      for (final item in await DBService.instance.getAllBookshelf())
        item.aid: item,
    };
    final favorites = <String, BookshelfNovelInfo>{};
    final needOwnerUpdateCheck = <BookshelfNovelInfo>[];
    var page = 1;
    var total = 0;
    var perPage = 0;
    var scanned = 0;
    var done = false;

    while (!done) {
      final result = await YamiboApi.getFavoritePage(page: page);
      switch (result) {
        case Success():
          if (!SourceAuthGuard.checkHtml(NovelSource.yamibo, result.data)) {
            onError?.call('Yamibo ${"source_login_required".tr}');
            return false;
          }
          if (YamiboParser.isUnavailableDuringDailyBackup(result.data)) {
            onError?.call('Yamibo ${"yamibo_backup_window".tr}');
            return false;
          }
          onProgress?.call(
            total <= 0 ? null : (scanned / total).clamp(0.0, 1.0),
            total <= 0
                ? '${"refresh_bookshelf_tip".tr} $page'
                : '$scanned / $total',
          );
          final YamiboFavoritePageData pageData;
          try {
            pageData = YamiboParser.getFavoritePageData(result.data);
          } catch (e) {
            onError?.call(
              'Yamibo ${"yamibo_detail_parse_failed".trParams({"error": e.toString()})}',
            );
            return false;
          }
          if (pageData.count > 0) total = pageData.count;
          if (pageData.perPage > 0) perPage = pageData.perPage;
          if (pageData.items.isEmpty) {
            done = true;
            break;
          }

          final beforeScanned = scanned;
          for (final item in pageData.items) {
            scanned += 1;
            if (onlyAids != null && !onlyAids.contains(item.aid)) continue;
            final previousItem = previous[item.aid];
            if (previousItem != null &&
                _yamiboTopicUpdateKey(previousItem.updateKey) ==
                    item.updateKey) {
              favorites[item.aid] = _mergeYamiboFavoriteWithPrevious(
                item,
                previousItem,
              );
            } else {
              favorites[item.aid] = item;
              needOwnerUpdateCheck.add(item);
            }
          }

          if (total > 0 && scanned >= total) done = true;
          if (perPage > 0 && pageData.items.length < perPage) done = true;
          if (scanned == beforeScanned) done = true;
          page += 1;
        case Error():
          onError?.call('Yamibo ${result.error ?? "update_failed".tr}');
          return false;
      }
    }

    final checkedItems = await _mapConcurrent(
      needOwnerUpdateCheck,
      4,
      _withYamiboOwnerUpdateInfo,
    );
    for (final item in checkedItems) {
      favorites[item.aid] = item;
    }

    if (onlyAids == null) {
      LocalStorageService.instance.setBookshelfAidOrder(
        yamiboClassId,
        favorites.keys,
      );
    }

    for (final item in favorites.values) {
      if (SourceConfigService.instance.isLocallyHidden(
        NovelSource.yamibo,
        item.aid,
      )) {
        continue;
      }
      final prev = previous[item.aid];
      final keepLocal =
          prev?.classId == defaultClassId ||
          prev?.classId.startsWith(_localFolderPrefix) == true;
      await DBService.instance.upsertBookshelf(
        BookshelfEntityData(
          aid: item.aid,
          bid: item.bid,
          url: item.url,
          title: item.title,
          img: _syncedImageFor(NovelSource.yamibo, item.img, prev),
          classId: keepLocal ? prev!.classId : yamiboClassId,
          updateKey: item.updateKey,
          updateTime: item.updateTime,
          hasUpdate: _hasBookshelfUpdate(prev, item.updateKey),
          rating: prev?.rating ?? 0,
          remoteTagsJson: _remoteTagsJsonFor(item, prev),
          localTagsJson: prev?.localTagsJson ?? BookTags.emptyJson,
        ),
      );
    }
    if (onlyAids == null && favorites.isNotEmpty) {
      for (final item in previous.values) {
        if (item.classId == yamiboClassId && !favorites.containsKey(item.aid)) {
          await DBService.instance.deleteBookshelfByAid(item.aid);
        }
      }
    }
    return true;
  }

  static bool _hasBookshelfUpdate(
    BookshelfEntityData? previous,
    String updateKey,
  ) {
    if (previous == null || updateKey.isEmpty) return false;
    if (previous.hasUpdate && previous.updateKey == updateKey) return true;
    return previous.updateKey.isNotEmpty && previous.updateKey != updateKey;
  }

  static String _syncedImageFor(
    NovelSource source,
    String? onlineImage,
    BookshelfEntityData? previous,
  ) {
    if (source == NovelSource.yamibo) return '';
    final online = onlineImage?.trim() ?? '';
    if (online.isNotEmpty) return online;
    return previous?.img ?? '';
  }

  static String _remoteTagsJsonFor(
    BookshelfNovelInfo item,
    BookshelfEntityData? previous,
  ) {
    final tags = item.remoteTags.isNotEmpty || item.tags.isNotEmpty
        ? item.tags
        : BookTags.decode(previous?.remoteTagsJson);
    return BookTags.encode(
      item.aid.startsWith('yamibo:')
          ? BookTags.merge(YamiboParser.yamiboTags(tags), const ['百合'])
          : tags,
    );
  }

  static BookshelfNovelInfo _mergeYamiboFavoriteWithPrevious(
    BookshelfNovelInfo item,
    BookshelfEntityData previous,
  ) {
    return BookshelfNovelInfo(
      bid: item.bid,
      aid: item.aid,
      url: item.url,
      title: item.title,
      img: '',
      updateKey: previous.updateKey,
      updateTime: previous.updateTime,
      hasUpdate: previous.hasUpdate,
      rating: previous.rating,
      remoteTags: item.remoteTags.isNotEmpty
          ? item.remoteTags
          : BookTags.decode(previous.remoteTagsJson),
      localTags: BookTags.decode(previous.localTagsJson),
    );
  }

  static String _yamiboTopicUpdateKey(String updateKey) =>
      updateKey.split(_yamiboOwnerUpdateSeparator).first;

  static Future<BookshelfNovelInfo> _withYamiboOwnerUpdateInfo(
    BookshelfNovelInfo item,
  ) async {
    try {
      final tid = SourceId.yamiboTid(item.aid);
      final firstPage = await YamiboApi.getThreadPage(
        tid: tid,
      ).timeout(const Duration(seconds: 12));
      if (firstPage is! Success) return item;

      final firstPageData = YamiboParser.getThreadDetail(firstPage.data);
      var detail = firstPageData;
      if (firstPageData.authorId.isNotEmpty) {
        final authorPage = await YamiboApi.getThreadPage(
          tid: tid,
          authorId: firstPageData.authorId,
        ).timeout(const Duration(seconds: 12));
        if (authorPage is Success) {
          detail = YamiboParser.getThreadDetail(authorPage.data);
        }
      }

      var updateTime = detail.updateTime;
      if (detail.maxPage > 1 && detail.authorId.isNotEmpty) {
        final lastPage = await YamiboApi.getThreadPage(
          tid: tid,
          page: detail.maxPage,
          authorId: detail.authorId,
        ).timeout(const Duration(seconds: 12));
        if (lastPage is Success) {
          updateTime =
              YamiboParser.getLatestAuthorPostTime(
                lastPage.data,
                authorId: detail.authorId,
              ) ??
              updateTime;
        }
      }

      final ownerUpdateKey =
          '${detail.authorId}:${detail.maxPage}:${updateTime?.millisecondsSinceEpoch ?? ''}';
      return BookshelfNovelInfo(
        bid: item.bid,
        aid: item.aid,
        url: item.url,
        title: detail.detail.title,
        img: detail.detail.imgUrl,
        updateKey:
            '${item.updateKey}$_yamiboOwnerUpdateSeparator$ownerUpdateKey',
        updateTime: updateTime ?? item.updateTime,
        hasUpdate: item.hasUpdate,
        rating: item.rating,
        remoteTags: BookTags.merge(item.remoteTags, detail.detail.tags),
        localTags: item.localTags,
      );
    } catch (_) {
      return item;
    }
  }

  static Future<List<R>> _mapConcurrent<T, R>(
    List<T> items,
    int concurrency,
    Future<R> Function(T item) mapper,
  ) async {
    final results = List<R?>.filled(items.length, null);
    var nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        final index = nextIndex;
        if (index >= items.length) return;
        nextIndex += 1;
        results[index] = await mapper(items[index]);
      }
    }

    await Future.wait(
      List.generate(
        items.length < concurrency ? items.length : concurrency,
        (_) => worker(),
      ),
    );
    return results.whereType<R>().toList();
  }
}

class _SubscriptionCandidate {
  _SubscriptionCandidate(this.cover);

  final NovelCover cover;
  final Set<String> tags = <String>{};
}

class _SubscriptionSearchResult {
  const _SubscriptionSearchResult(
    this.candidates, {
    this.failed = false,
    this.errorMessage,
  });

  final Map<String, _SubscriptionCandidate> candidates;
  final bool failed;
  final String? errorMessage;
}

class _SubscriptionSearchException implements Exception {
  const _SubscriptionSearchException(this.message);

  final String message;
}

class BookshelfSyncProgress {
  const BookshelfSyncProgress({this.value, this.message});

  final double? value;
  final String? message;
}

class BookshelfFolder {
  final String id;
  final String name;
  final String? parentId;
  final BookshelfFolderCover? cover;
  final bool builtIn;
  final int count;
  final bool hasUpdate;
  final bool smartFolder;
  final List<String> smartFolderAids;
  final int childCount;
  final bool hasNew;

  BookshelfFolder({
    required this.id,
    required this.name,
    this.parentId,
    this.cover,
    this.builtIn = false,
    this.count = 0,
    this.hasUpdate = false,
    this.smartFolder = false,
    this.smartFolderAids = const [],
    this.childCount = 0,
    this.hasNew = false,
  });
}

enum BookshelfFolderCoverType { book, file }

class BookshelfFolderCover {
  const BookshelfFolderCover({required this.type, required this.value});

  BookshelfFolderCover.book(String value)
    : this(type: BookshelfFolderCoverType.book, value: value);

  BookshelfFolderCover.file(String value)
    : this(type: BookshelfFolderCoverType.file, value: value);

  final BookshelfFolderCoverType type;
  final String value;

  static BookshelfFolderCover? fromJson(Map<String, String>? json) {
    if (json == null) return null;
    final value = json['value']?.trim() ?? '';
    if (value.isEmpty) return null;
    final type = switch (json['type']) {
      'file' => BookshelfFolderCoverType.file,
      _ => BookshelfFolderCoverType.book,
    };
    return BookshelfFolderCover(type: type, value: value);
  }

  Map<String, String> toJson() => {
    'type': type == BookshelfFolderCoverType.file ? 'file' : 'book',
    'value': value,
  };
}

class BookshelfContentController extends GetxController {
  final String classId;
  final bool isSmartFolder;
  final List<String> smartFolderAids;

  BookshelfContentController({
    required this.classId,
    this.isSmartFolder = false,
    this.smartFolderAids = const [],
  });

  final BookshelfController _bookshelfController = Get.find();
  final MainController _mainController = Get.find();

  bool get isSelectionMode => _bookshelfController.isSelectionMode.value;

  bool get isYamiboBookshelf => classId == BookshelfController.yamiboClassId;

  bool get isEsjBookshelf => classId == BookshelfController.esjClassId;

  bool get isRemoteWenku8Bookshelf => int.tryParse(classId) != null;

  bool get canMoveToRemoteWenku8Bookshelf =>
      !isSmartFolder &&
      !isYamiboBookshelf &&
      !isEsjBookshelf &&
      isRemoteWenku8Bookshelf &&
      SourceFavoriteAdapter.canPushLocalToRemote(NovelSource.wenku8) &&
      SourceConfigService.instance.shouldPushLocalToRemote(NovelSource.wenku8);

  bool get shouldRefreshAfterRemove =>
      isRemoteWenku8Bookshelf &&
      SourceFavoriteAdapter.shouldRemoveRemote(NovelSource.wenku8);

  Rxn<Bookshelf> bookshelf = Rxn();
  Rx<PageState> pageState = Rx(PageState.loading);
  RxInt selectedCount = 0.obs;
  String errorMsg = "";
  StreamSubscription<List<BookshelfEntityData>>? _bookshelfSubscription;
  StreamSubscription<List<BrowsingHistoryEntityData>>? _historySubscription;
  Worker? _smartFolderWorker;
  Worker? _sortWorker;
  List<BookshelfEntityData> _lastBookshelfData = const [];

  static Future<void> sortBookshelfNovelInfo(
    List<BookshelfNovelInfo> list,
    String? classId,
  ) async {
    final index = classId == null
        ? LocalStorageService.instance.getBookshelfSortType()
        : LocalStorageService.instance.getBookshelfSortTypeForClassId(classId);
    final sortType = index < 0 || index >= BookshelfSortType.values.length
        ? BookshelfSortType.added
        : BookshelfSortType.values[index];
    switch (sortType) {
      case BookshelfSortType.update:
        list.sort(_compareBookshelfNovelInfo);
        break;
      case BookshelfSortType.title:
        list.sort((a, b) {
          final aKey = titleSortKey(a.title);
          final bKey = titleSortKey(b.title);
          final keyResult = aKey.compareTo(bKey);
          if (keyResult != 0) return keyResult;
          return a.title.compareTo(b.title);
        });
        break;
      case BookshelfSortType.added:
        if (classId == null) break;
        final order = LocalStorageService.instance.syncBookshelfAidOrder(
          classId,
          list.map((item) => item.aid),
        );
        final orderIndex = {for (var i = 0; i < order.length; i++) order[i]: i};
        list.sort((a, b) {
          final result = (orderIndex[a.aid] ?? 0).compareTo(
            orderIndex[b.aid] ?? 0,
          );
          if (result != 0) return result;
          return _compareBookshelfNovelInfo(a, b);
        });
        break;
      case BookshelfSortType.recentRead:
        final times = await BookshelfController._getRecentReadTimes();
        list.sort((a, b) {
          final aTime = times[a.aid];
          final bTime = times[b.aid];
          if (aTime != null && bTime != null) return bTime.compareTo(aTime);
          if (aTime != null) return -1;
          if (bTime != null) return 1;
          return _compareBookshelfNovelInfo(a, b);
        });
        break;
    }
  }

  BookshelfSortType get sortType {
    final index = LocalStorageService.instance.getBookshelfSortTypeForClassId(
      classId,
    );
    if (index < 0 || index >= BookshelfSortType.values.length) {
      return BookshelfSortType.added;
    }
    return BookshelfSortType.values[index];
  }

  bool get isTitleSort => sortType == BookshelfSortType.title;

  @override
  void onReady() {
    super.onReady();
    _sortWorker = ever(_bookshelfController.sortRevision, (_) {
      _onBookshelfData(_lastBookshelfData);
    });

    if (isSmartFolder) {
      _watchSmartFolder();
    } else {
      _bookshelfSubscription = DBService.instance
          .getBookshelfByClassId(classId)
          .listen(_onBookshelfData);
    }
  }

  void _watchSmartFolder() async {
    await _loadSmartFolderBooks();
    if (classId == BookshelfController.recentSmartId) {
      _historySubscription = DBService.instance
          .getWatchableAllBrowsingHistory()
          .listen((_) => _loadSmartFolderBooks());
    }
    _smartFolderWorker = ever(_bookshelfController.folders, (_) async {
      await _loadSmartFolderBooks();
    });
  }

  @override
  void onClose() {
    _bookshelfSubscription?.cancel();
    _historySubscription?.cancel();
    _smartFolderWorker?.dispose();
    _sortWorker?.dispose();
    super.onClose();
  }

  Future<void> _loadSmartFolderBooks() async {
    if (classId == BookshelfController.recentSmartId) {
      await _loadRecentReadBooks();
      return;
    }
    final allBooks = await DBService.instance.getAllBookshelf();
    final dynamicAids = await _bookshelfController.getSmartFolderAids(classId);
    _onBookshelfData(
      allBooks.where((b) => dynamicAids.contains(b.aid)).toList(),
    );
  }

  Future<void> _loadRecentReadBooks() async {
    final limit = LocalStorageService.instance.getBookshelfRecentCount();
    final histories = await DBService.instance.getRecentBrowsingHistory(limit);
    final booksByAid = {
      for (final book in await DBService.instance.getAllBookshelf())
        book.aid: book,
    };
    _onBookshelfData(
      histories.map((history) {
        final book = booksByAid[history.aid];
        if (book != null) return book;
        return _bookshelfDataFromHistory(history);
      }).toList(),
    );
  }

  BookshelfEntityData _bookshelfDataFromHistory(
    BrowsingHistoryEntityData history,
  ) {
    return BookshelfEntityData(
      aid: history.aid,
      bid: history.aid,
      url: _detailUrlForHistoryAid(history.aid),
      title: history.title,
      img: history.img,
      classId: classId,
      updateKey: '',
      updateTime: null,
      hasUpdate: false,
      rating: 0,
      remoteTagsJson: BookTags.emptyJson,
      localTagsJson: BookTags.emptyJson,
    );
  }

  String _detailUrlForHistoryAid(String aid) {
    if (SourceId.isEsj(aid)) {
      return EsjApi.detailUrl(SourceId.esjBookId(aid));
    }
    if (SourceId.isYamibo(aid)) {
      return YamiboApi.threadUrl(SourceId.yamiboTid(aid));
    }
    return '${Api.wenku8Node.node}/modules/article/articleinfo.php?id=$aid';
  }

  void _onBookshelfData(List<BookshelfEntityData> bss) async {
    _lastBookshelfData = List<BookshelfEntityData>.from(bss);
    final readCompleteAids = await _getReadCompleteAids(bss);
    final aidSet = bss.map((b) => b.aid).toSet();
    _detailCache
      ..clear()
      ..addEntries(
        (await DBService.instance.getAllNovelDetails())
            .where((detail) => aidSet.contains(detail.aid))
            .map((detail) => MapEntry(detail.aid, detail)),
      );
    List<BookshelfNovelInfo> list = bss
        .map(
          (i) => BookshelfNovelInfo(
            bid: i.bid,
            aid: i.aid,
            url: i.url,
            title: i.title,
            img: i.img,
            updateKey: i.updateKey,
            updateTime: i.updateTime,
            hasUpdate: i.hasUpdate,
            isReadComplete: readCompleteAids.contains(i.aid),
            author: _cachedAuthorOf(i.aid),
            sourceLabel: _sourceLabelOfAid(i.aid),
            rating: i.rating,
            remoteTags: _cachedTagsOf(i.aid, i.remoteTagsJson),
            localTags: BookTags.decode(i.localTagsJson),
          ),
        )
        .toList();
    await sortBookshelfNovelInfo(list, classId);

    if (list.isEmpty) {
      bookshelf.value = null;
      _updateSelectedCount();
      pageState.value = PageState.empty;
    } else {
      bookshelf.value = Bookshelf(list: list, classId: classId);
      _updateSelectedCount();
      pageState.value = PageState.success;
    }
  }

  Future<Set<String>> _getReadCompleteAids(
    List<BookshelfEntityData> books,
  ) async {
    if (books.isEmpty) return {};
    final aids = books.map((b) => b.aid).toList();
    final aidSet = aids.toSet();
    final details = {
      for (final detail in await DBService.instance.getAllNovelDetails())
        if (aidSet.contains(detail.aid)) detail.aid: detail,
    };
    if (details.isEmpty) return {};

    final histories = await DBService.instance.getReadHistoryByAids(aids);
    final readByAid = <String, Set<String>>{};
    for (final history in histories) {
      if (history.progress < 100) continue;
      readByAid.putIfAbsent(history.aid, () => <String>{}).add(history.cid);
    }

    final complete = <String>{};
    for (final book in books) {
      final detail = details[book.aid];
      final readCids = readByAid[book.aid];
      if (detail == null || readCids == null) continue;
      try {
        final novel = NovelDetail.fromString(detail.json);
        final latestCid = _latestCatalogueCid(novel);
        if (latestCid != null && readCids.contains(latestCid)) {
          complete.add(book.aid);
        }
      } catch (_) {
        continue;
      }
    }
    return complete;
  }

  String _cachedAuthorOf(String aid) {
    final detail = _detailCache[aid];
    if (detail == null) return '';
    try {
      final author = NovelDetail.fromString(detail.json).author.trim();
      if (author == 'Yamibo' || author == 'ESJZone') return '';
      return author;
    } catch (_) {
      return '';
    }
  }

  List<String> _cachedTagsOf(String aid, String remoteTagsJson) {
    final tags = BookTags.decode(remoteTagsJson);
    final detail = _detailCache[aid];
    if (detail == null) return tags;
    try {
      return BookTags.merge(tags, NovelDetail.fromString(detail.json).tags);
    } catch (_) {
      return tags;
    }
  }

  String _sourceLabelOfAid(String aid) {
    return switch (SourceFavoriteAdapter.sourceOfAid(aid)) {
      NovelSource.wenku8 => 'wenku8'.tr,
      NovelSource.esj => 'esjzone'.tr,
      NovelSource.yamibo => 'yamibo_forum'.tr,
    };
  }

  final Map<String, NovelDetailEntityData> _detailCache = {};

  String? _latestCatalogueCid(NovelDetail detail) {
    for (final volume in detail.catalogue.reversed) {
      if (volume.chapters.isNotEmpty) return volume.chapters.last.cid;
    }
    return null;
  }

  void toggleCoverSelection(String aid) {
    final selected = bookshelf.value!.list
        .firstWhere((v) => v.aid == aid)
        .isSelected
        .value;
    bookshelf.value!.list.firstWhere((v) => v.aid == aid).isSelected.value =
        !selected;
    _updateSelectedCount();
  }

  Future<void> setRating(String aid, double rating) =>
      DBService.instance.setBookshelfRating(aid, rating);

  Future removeNovelFromList() async {
    if (shouldRefreshAfterRemove) {
      return Api.removeNovelFromList(
        list: getSelectedNovel(),
        classId: int.parse(classId),
      );
    }
    final selectedItems =
        bookshelf.value?.list.where((v) => v.isSelected.value == true) ??
        const Iterable<BookshelfNovelInfo>.empty();
    for (final item in selectedItems) {
      final aid = item.aid;
      final source = _sourceOfAid(aid);
      if (SourceFavoriteAdapter.shouldRemoveRemote(source)) {
        final removed = await SourceFavoriteAdapter.removeRemoteFavorite(
          source: source,
          remoteId: source == NovelSource.wenku8 ? item.bid : aid,
        );
        if (!removed) continue;
      } else {
        _hideLocalRemoteFavorite(aid);
      }
      await DBService.instance.deleteBookshelfByAid(aid);
    }
  }

  Future moveNovelToOther(int newClassId) async {
    if (!canMoveToRemoteWenku8Bookshelf) return;
    return Api.moveNovelToOther(
      list: getSelectedNovel(),
      classId: int.parse(classId),
      newClassId: newClassId,
    );
  }

  void _hideLocalRemoteFavorite(String aid) {
    final source = _sourceOfAid(aid);
    if (!SourceConfigService.instance.shouldPullOnlineToLocal(source)) return;
    SourceConfigService.instance.hideLocalFavorite(source, aid);
  }

  NovelSource _sourceOfAid(String aid) {
    return SourceFavoriteAdapter.sourceOfAid(aid);
  }

  List<String> getSelectedAids() => bookshelf.value!.list
      .where((v) => v.isSelected.value == true)
      .map((i) => i.aid)
      .toList();

  List<String> getSelectedNovel() => bookshelf.value!.list
      .where((v) => v.isSelected.value == true)
      .map((i) => i.bid)
      .toList();

  void exitSelectionMode() {
    _bookshelfController.isSelectionMode.value = false;
    _mainController.showBookshelfBottomActionBar.value = false;
    deselect();
  }

  void enterSelectionMode() {
    _bookshelfController.isSelectionMode.value = true;
    _mainController.showBookshelfBottomActionBar.value = true;
  }

  void deselect() {
    for (final v in bookshelf.value!.list) {
      v.isSelected.value = false;
    }
    _updateSelectedCount();
  }

  void selectAll() {
    for (final v in bookshelf.value!.list) {
      v.isSelected.value = true;
    }
    _updateSelectedCount();
  }

  void _updateSelectedCount() {
    selectedCount.value =
        bookshelf.value?.list.where((v) => v.isSelected.value == true).length ??
        0;
  }

  static String titleInitial(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return '#';
    final char = String.fromCharCode(trimmed.runes.first);
    final upper = char.toUpperCase();
    if (RegExp(r'^[A-Z]$').hasMatch(upper)) return upper;
    if (RegExp(r'^[0-9]$').hasMatch(char)) return '#';
    final code = char.codeUnitAt(0);
    if (code >= 0x4E00 && code <= 0x9FFF) {
      return _pinyinInitial(char);
    }
    return '#';
  }

  static String titleSortKey(String title) {
    final initial = titleInitial(title);
    final normalized = title.trim().toUpperCase();
    return '$initial|$normalized';
  }

  static String _pinyinInitial(String char) {
    const initials = 'ABCDEFGHJKLMNOPQRSTWXYZ';
    const boundaries = [
      '阿',
      '芭',
      '擦',
      '搭',
      '蛾',
      '发',
      '噶',
      '哈',
      '击',
      '喀',
      '垃',
      '妈',
      '拿',
      '哦',
      '啪',
      '期',
      '然',
      '撒',
      '塌',
      '挖',
      '昔',
      '压',
      '匝',
    ];
    final code = char.codeUnitAt(0);
    for (var i = boundaries.length - 1; i >= 0; i--) {
      if (code >= boundaries[i].codeUnitAt(0)) return initials[i];
    }
    return '#';
  }
}

class BookshelfSearchController extends GetxController {
  final _bookshelfController = Get.find<BookshelfController>();
  final searchTextEditController = Get.find<TextEditingController>(
    tag: "searchTextEditController",
  );

  RxList<BookshelfNovelInfo> data = RxList();
  Rx<PageState> pageState = Rx(PageState.placeholder);

  void getBookshelfByKeyword() async {
    final books = await DBService.instance.getBookshelfByKeyword(
      searchTextEditController.text,
    );
    final aidSet = books.map((b) => b.aid).toSet();
    final details = {
      for (final detail in await DBService.instance.getAllNovelDetails())
        if (aidSet.contains(detail.aid)) detail.aid: detail,
    };
    data.assignAll(
      books.map(
        (e) => BookshelfNovelInfo(
          bid: e.bid,
          aid: e.aid,
          url: e.url,
          title: e.title,
          img: e.img,
          updateKey: e.updateKey,
          updateTime: e.updateTime,
          hasUpdate: e.hasUpdate,
          author: _authorOf(details[e.aid]),
          sourceLabel: _sourceLabelOfAid(e.aid),
          rating: e.rating,
        ),
      ),
    );
    await BookshelfContentController.sortBookshelfNovelInfo(data, null);
    if (data.isEmpty) {
      pageState.value = PageState.empty;
    } else {
      pageState.value = PageState.success;
    }
  }

  void back() =>
      _bookshelfController.pageState.value = PageState.bookshelfContent;

  Future<void> setRating(String aid, double rating) =>
      DBService.instance.setBookshelfRating(aid, rating);

  String _sourceLabelOfAid(String aid) {
    return switch (SourceFavoriteAdapter.sourceOfAid(aid)) {
      NovelSource.wenku8 => 'wenku8'.tr,
      NovelSource.esj => 'esjzone'.tr,
      NovelSource.yamibo => 'yamibo_forum'.tr,
    };
  }

  String _authorOf(NovelDetailEntityData? detail) {
    if (detail == null) return '';
    try {
      final author = NovelDetail.fromString(detail.json).author.trim();
      if (author == 'Yamibo' || author == 'ESJZone') return '';
      return author;
    } catch (_) {
      return '';
    }
  }
}

int _compareBookshelfNovelInfo(BookshelfNovelInfo a, BookshelfNovelInfo b) {
  if (a.hasUpdate != b.hasUpdate) return a.hasUpdate ? -1 : 1;
  final aTime = a.updateTime;
  final bTime = b.updateTime;
  if (aTime != null && bTime != null) return bTime.compareTo(aTime);
  if (aTime != null) return -1;
  if (bTime != null) return 1;
  return b.updateKey.compareTo(a.updateKey);
}
