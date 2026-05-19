import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:hikari_novel_flutter/common/migration.dart';
import 'package:path_provider/path_provider.dart';
import 'entity.dart';

part "database.g.dart";

@DriftDatabase(
  tables: [
    BookshelfEntity,
    BrowsingHistoryEntity,
    SearchHistoryEntity,
    ReadHistoryEntity,
    NovelDetailEntity,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 7; //版本号

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2 && to >= 2) {
        await Migration.fromOneToTwo(this);
      }
      if (from < 3 && to >= 3) {
        Migration.fromTwoToThree();
      }
      if (from < 4 && to >= 4) {
        await Migration.fromThreeToFour(this);
      }
      if (from < 5 && to >= 5) {
        await Migration.fromFourToFive(this);
      }
      if (from < 6 && to >= 6) {
        await Migration.fromFiveToSix(this);
      }
      if (from < 7 && to >= 7) {
        await Migration.fromSixToSeven(this);
      }
    },
  );

  Future<void> insertAllBookshelf(Iterable<BookshelfEntityData> data) =>
      batch((b) => b.insertAll(bookshelfEntity, data));

  Future<void> upsertBookshelf(BookshelfEntityData data) =>
      into(bookshelfEntity).insertOnConflictUpdate(data);

  Future<void> deleteAllBookshelf() => delete(bookshelfEntity).go();

  Future<void> deleteWenku8BookshelfByClassId(
    String classId,
  ) => customStatement(
    "DELETE FROM bookshelf_entity WHERE class_id = ? AND aid NOT LIKE 'yamibo:%' AND aid NOT LIKE 'esj:%'",
    [classId],
  );

  Future<void> deleteDefaultBookshelf() => customStatement(
    "DELETE FROM bookshelf_entity WHERE class_id = '0' AND aid NOT LIKE 'yamibo:%' AND aid NOT LIKE 'esj:%'",
  );

  Future<void> deleteBookshelfByAid(String aid) =>
      (delete(bookshelfEntity)..where((i) => i.aid.equals(aid))).go();

  Future<void> deleteBookshelfByClassId(String classId) =>
      (delete(bookshelfEntity)..where((i) => i.classId.equals(classId))).go();

  Future<List<BrowsingHistoryEntityData>> getRecentBrowsingHistory(int limit) =>
      (select(browsingHistoryEntity)
            ..orderBy([(t) => OrderingTerm.desc(t.time)])
            ..limit(limit))
          .get();

  Future<List<BrowsingHistoryEntityData>> getAllBrowsingHistory() =>
      select(browsingHistoryEntity).get();

  Future<List<NovelDetailEntityData>> getAllNovelDetails() =>
      select(novelDetailEntity).get();

  Future<List<ReadHistoryEntityData>> getReadHistoryByAids(
    Iterable<String> aids,
  ) async {
    final aidList = aids.toList();
    if (aidList.isEmpty) return [];
    return (select(readHistoryEntity)..where((i) => i.aid.isIn(aidList))).get();
  }

  Future<void> moveBookshelfItemsToClassId(
    Iterable<String> aids,
    String classId,
  ) async {
    final aidList = aids.toList();
    if (aidList.isEmpty) return;
    await (update(bookshelfEntity)..where((i) => i.aid.isIn(aidList))).write(
      BookshelfEntityCompanion(classId: Value(classId)),
    );
  }

  Future<void> moveYamiboBookshelfToYamiboClass() => customStatement(
    "UPDATE bookshelf_entity SET class_id = 'yamibo' WHERE aid LIKE 'yamibo:%' AND class_id NOT LIKE 'local_%'",
  );

  Future<void> moveEsjBookshelfToEsjClass() => customStatement(
    "UPDATE bookshelf_entity SET class_id = 'esj' WHERE aid LIKE 'esj:%' AND class_id NOT LIKE 'local_%' AND class_id != '0' AND class_id != 'esj'",
  );

  Future<void> clearBookshelfUpdate(String aid) =>
      (update(bookshelfEntity)..where((i) => i.aid.equals(aid))).write(
        const BookshelfEntityCompanion(hasUpdate: Value(false)),
      );

  Future<void> setBookshelfRating(String aid, double rating) =>
      (update(bookshelfEntity)..where((i) => i.aid.equals(aid))).write(
        BookshelfEntityCompanion(rating: Value(rating.clamp(0, 5))),
      );

  Stream<List<BookshelfEntityData>> getBookshelfByClassId(String classId) =>
      (select(
        bookshelfEntity,
      )..where((i) => i.classId.equals(classId))).watch();

  Future<List<BookshelfEntityData>> getAllBookshelf() =>
      select(bookshelfEntity).get();

  Future<List<BookshelfEntityData>> getBookshelfByKeyword(String keyword) =>
      (select(
        bookshelfEntity,
      )..where((i) => i.title.contains(keyword).equals(true))).get();

  Future<void> upsertBrowsingHistory(BrowsingHistoryEntityData data) =>
      into(browsingHistoryEntity).insertOnConflictUpdate(data);

  Stream<List<BrowsingHistoryEntityData>> getWatchableAllBrowsingHistory() =>
      select(browsingHistoryEntity).watch();

  Future<void> deleteBrowsingHistory(String aid) =>
      (delete(browsingHistoryEntity)..where((i) => i.aid.equals(aid))).go();

  Future<void> deleteAllBrowsingHistory() => delete(browsingHistoryEntity).go();

  Future<void> upsertSearchHistory(SearchHistoryEntityData data) =>
      into(searchHistoryEntity).insertOnConflictUpdate(data);

  Stream<List<SearchHistoryEntityData>> getAllSearchHistory() =>
      select(searchHistoryEntity).watch();

  Future<List<SearchHistoryEntityData>> getAllSearchHistoryItems() =>
      select(searchHistoryEntity).get();

  Future<void> deleteAllSearchHistory() => delete(searchHistoryEntity).go();

  Future<void> upsertReadHistory(ReadHistoryEntityData data) =>
      transaction(() async {
        await (update(readHistoryEntity)
              ..where((i) => i.isLatest.equals(true) & i.aid.equals(data.aid)))
            .write(
              RawValuesInsertable({
                readHistoryEntity.isLatest.name: Variable<bool>(false),
              }),
            );
        await into(readHistoryEntity).insertOnConflictUpdate(data);
      });

  Future<List<ReadHistoryEntityData>> getAllReadHistory() =>
      select(readHistoryEntity).get();

  Future<ReadHistoryEntityData?> getReadHistoryByCid(String aid, String cid) =>
      (select(
        readHistoryEntity,
      )..where((i) => i.aid.equals(aid) & i.cid.equals(cid))).getSingleOrNull();

  Stream<ReadHistoryEntityData?> getLastestReadHistoryByAid(String aid) =>
      (select(readHistoryEntity)
            ..where((i) => i.aid.equals(aid) & i.isLatest.equals(true)))
          .watchSingleOrNull();

  Stream<ReadHistoryEntityData?> getWatchableReadHistoryByCid(
    String aid,
    String cid,
  ) => (select(
    readHistoryEntity,
  )..where((i) => i.aid.equals(aid) & i.cid.equals(cid))).watchSingleOrNull();

  /// - [cids] 该卷下所有小说的cid
  Stream<List<ReadHistoryEntityData>> getWatchableReadHistoryByVolume(
    String aid,
    List<String> cids,
  ) => (select(
    readHistoryEntity,
  )..where((i) => i.aid.equals(aid) & i.cid.isIn(cids))).watch();

  Future<void> deleteReadHistoryByCid(String aid, String cid) => (delete(
    readHistoryEntity,
  )..where((i) => i.aid.equals(aid) & i.cid.equals(cid))).go();

  Future<void> upsertReadHistoryDirectly(ReadHistoryEntityData data) =>
      into(readHistoryEntity).insertOnConflictUpdate(data);

  Future<void> deleteAllReadHistory() => delete(readHistoryEntity).go();

  Future<void> upsertNovelDetail(NovelDetailEntityData data) =>
      into(novelDetailEntity).insertOnConflictUpdate(data);

  Future<NovelDetailEntityData?> getNovelDetail(String aid) => (select(
    novelDetailEntity,
  )..where((i) => i.aid.equals(aid))).getSingleOrNull();

  Future<void> deleteAllNovelDetail() => delete(novelDetailEntity).go();
}

QueryExecutor _openConnection() => driftDatabase(
  name: "hikari_novel_database",
  native: const DriftNativeOptions(
    databaseDirectory: getApplicationSupportDirectory,
  ),
);
