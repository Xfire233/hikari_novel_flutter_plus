import 'package:get/get.dart';

import '../common/database/database.dart';

class DBService extends GetxService {
  static DBService get instance => Get.find<DBService>();

  late final AppDatabase _db;

  void init() {
    _db = AppDatabase();
  }

  Future<void> insertAllBookshelf(Iterable<BookshelfEntityData> data) =>
      _db.insertAllBookshelf(data);

  Future<void> upsertBookshelf(BookshelfEntityData data) =>
      _db.upsertBookshelf(data);

  Future<void> deleteAllBookshelf() => _db.deleteAllBookshelf();

  Future<void> deleteWenku8BookshelfByClassId(String classId) =>
      _db.deleteWenku8BookshelfByClassId(classId);

  Future<void> deleteDefaultBookshelf() => _db.deleteDefaultBookshelf();

  Future<void> deleteBookshelfByAid(String aid) =>
      _db.deleteBookshelfByAid(aid);

  Future<void> deleteBookshelfByClassId(String classId) =>
      _db.deleteBookshelfByClassId(classId);

  Future<List<BrowsingHistoryEntityData>> getRecentBrowsingHistory(int limit) =>
      _db.getRecentBrowsingHistory(limit);

  Future<List<BrowsingHistoryEntityData>> getAllBrowsingHistory() =>
      _db.getAllBrowsingHistory();

  Future<List<NovelDetailEntityData>> getAllNovelDetails() =>
      _db.getAllNovelDetails();

  Future<List<ReadHistoryEntityData>> getReadHistoryByAids(
    Iterable<String> aids,
  ) => _db.getReadHistoryByAids(aids);

  Future<void> moveBookshelfItemsToClassId(
    Iterable<String> aids,
    String classId,
  ) => _db.moveBookshelfItemsToClassId(aids, classId);

  Future<void> moveYamiboBookshelfToYamiboClass() =>
      _db.moveYamiboBookshelfToYamiboClass();

  Future<void> moveEsjBookshelfToEsjClass() => _db.moveEsjBookshelfToEsjClass();

  Future<void> clearBookshelfUpdate(String aid) =>
      _db.clearBookshelfUpdate(aid);

  Future<void> setBookshelfRating(String aid, double rating) =>
      _db.setBookshelfRating(aid, rating);

  Future<void> setBookshelfRemoteTags(String aid, String tagsJson) =>
      _db.setBookshelfRemoteTags(aid, tagsJson);

  Future<void> setBookshelfLocalTags(String aid, String tagsJson) =>
      _db.setBookshelfLocalTags(aid, tagsJson);

  Stream<List<BookshelfEntityData>> getBookshelfByClassId(String classId) =>
      _db.getBookshelfByClassId(classId);

  Future<List<BookshelfEntityData>> getAllBookshelf() => _db.getAllBookshelf();

  Future<List<BookshelfEntityData>> getBookshelfByKeyword(String keyword) =>
      _db.getBookshelfByKeyword(keyword);

  Future<void> upsertBrowsingHistory(BrowsingHistoryEntityData data) =>
      _db.upsertBrowsingHistory(data);

  Stream<List<BrowsingHistoryEntityData>> getWatchableAllBrowsingHistory() =>
      _db.getWatchableAllBrowsingHistory();

  Future<void> deleteBrowsingHistory(String aid) =>
      _db.deleteBrowsingHistory(aid);

  Future<void> deleteAllBrowsingHistory() => _db.deleteAllBrowsingHistory();

  Future<void> upsertSearchHistory(SearchHistoryEntityData data) =>
      _db.upsertSearchHistory(data);

  Stream<List<SearchHistoryEntityData>> getAllSearchHistory() =>
      _db.getAllSearchHistory();

  Future<List<SearchHistoryEntityData>> getAllSearchHistoryItems() =>
      _db.getAllSearchHistoryItems();

  Future<void> deleteAllSearchHistory() => _db.deleteAllSearchHistory();

  Future<void> upsertReadHistory(ReadHistoryEntityData data) =>
      _db.upsertReadHistory(data);

  Future<List<ReadHistoryEntityData>> getAllReadHistory() =>
      _db.getAllReadHistory();

  Future<ReadHistoryEntityData?> getReadHistoryByCid(String aid, String cid) =>
      _db.getReadHistoryByCid(aid, cid);

  Stream<ReadHistoryEntityData?> getLastestReadHistoryByAid(String aid) =>
      _db.getLastestReadHistoryByAid(aid);

  Stream<ReadHistoryEntityData?> getWatchableReadHistoryByCid(
    String aid,
    String cid,
  ) => _db.getWatchableReadHistoryByCid(aid, cid);

  Stream<List<ReadHistoryEntityData>> getWatchableReadHistoryByVolume(
    String aid,
    List<String> cids,
  ) => _db.getWatchableReadHistoryByVolume(aid, cids);

  Future<void> deleteReadHistoryByCid(String aid, String cid) =>
      _db.deleteReadHistoryByCid(aid, cid);

  Future<void> upsertReadHistoryDirectly(ReadHistoryEntityData data) =>
      _db.upsertReadHistoryDirectly(data);

  Future<void> deleteAllReadHistory() => _db.deleteAllReadHistory();

  Future<void> upsertNovelDetail(NovelDetailEntityData data) =>
      _db.upsertNovelDetail(data);

  Future<NovelDetailEntityData?> getNovelDetail(String aid) =>
      _db.getNovelDetail(aid);

  Future<void> deleteAllNovelDetail() => _db.deleteAllNovelDetail();
}
