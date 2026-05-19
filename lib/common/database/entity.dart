import 'package:drift/drift.dart';

/// 书架表
/// - [aid] 小说id
/// - [bid] 删除id
/// - [url] 小说的详情页面url
/// - [title] 小说标题
/// - [img] 小说封面url
/// - [classId] 该小说所在的书架号
/// - [updateKey] 最新章节/楼层标识
/// - [updateTime] 更新时间
/// - [hasUpdate] 是否有未读更新
class BookshelfEntity extends Table {
  TextColumn get aid => text()();

  TextColumn get bid => text()();

  TextColumn get url => text()();

  TextColumn get title => text()();

  TextColumn get img => text()();

  TextColumn get classId => text()();

  TextColumn get updateKey => text().withDefault(const Constant(''))();

  DateTimeColumn get updateTime => dateTime().nullable()();

  BoolColumn get hasUpdate => boolean().withDefault(const Constant(false))();

  RealColumn get rating => real().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {aid};
}

/// 历史浏览表
/// - [aid] 小说id
/// - [title] 小说标题
/// - [img] 小说封面url
/// - [time] 查看的时间
class BrowsingHistoryEntity extends Table {
  TextColumn get aid => text()();

  TextColumn get title => text()();

  TextColumn get img => text()();

  DateTimeColumn get time => dateTime()();

  @override
  Set<Column> get primaryKey => {aid};
}

/// 搜索历史记录表
/// - [keyword] 搜索内容
class SearchHistoryEntity extends Table {
  TextColumn get keyword => text()();

  @override
  Set<Column> get primaryKey => {keyword};
}

/// 阅读历史记录
/// - [cid] 章节号
/// - [aid] 书号
/// - [readerMode] 阅读模式
/// - [isDualPage] 是否双页
/// - [location] 阅读位置
/// - [progress] 阅读进度
/// - [isLatest] 是否为上次阅读的章节
class ReadHistoryEntity extends Table {
  TextColumn get cid => text()();

  TextColumn get aid => text()();

  IntColumn get readerMode => integer()();

  BoolColumn get isDualPage => boolean()();

  IntColumn get location => integer()();

  IntColumn get progress => integer()();

  BoolColumn get isLatest => boolean()();

  @override
  Set<Column> get primaryKey => {aid, cid};
}

class NovelDetailEntity extends Table {
  TextColumn get aid => text()();

  TextColumn get json => text()();

  @override
  Set<Column> get primaryKey => {aid};
}
