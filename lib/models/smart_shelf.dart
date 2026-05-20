import 'package:hikari_novel_flutter/models/book_tags.dart';
import 'package:hikari_novel_flutter/models/bookshelf.dart';
import 'package:hikari_novel_flutter/models/source_config.dart';

enum SmartShelfKind { local, subscription }

enum SmartShelfMatchMode { all, any }

enum SmartShelfConditionType {
  tag,
  source,
  author,
  title,
  hasUpdate,
  ratingMin,
  ratingMax,
  addedAfter,
  updatedAfter,
}

class SmartShelfCondition {
  const SmartShelfCondition({required this.type, required this.value});

  final SmartShelfConditionType type;
  final String value;

  factory SmartShelfCondition.fromJson(Map<dynamic, dynamic> json) {
    final rawType = '${json['type'] ?? ''}';
    return SmartShelfCondition(
      type: SmartShelfConditionType.values.firstWhere(
        (item) => item.name == rawType,
        orElse: () => SmartShelfConditionType.tag,
      ),
      value: '${json['value'] ?? ''}'.trim(),
    );
  }

  Map<String, dynamic> toJson() => {'type': type.name, 'value': value};
}

class SmartShelfConditionGroup {
  const SmartShelfConditionGroup({
    this.mode = SmartShelfMatchMode.all,
    this.conditions = const [],
  });

  final SmartShelfMatchMode mode;
  final List<SmartShelfCondition> conditions;

  factory SmartShelfConditionGroup.fromJson(Map<dynamic, dynamic> json) {
    final rawMode = '${json['mode'] ?? ''}';
    return SmartShelfConditionGroup(
      mode: SmartShelfMatchMode.values.firstWhere(
        (item) => item.name == rawMode,
        orElse: () => SmartShelfMatchMode.all,
      ),
      conditions: (json['conditions'] is Iterable)
          ? (json['conditions'] as Iterable)
                .whereType<Map>()
                .map(SmartShelfCondition.fromJson)
                .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'conditions': conditions.map((item) => item.toJson()).toList(),
  };
}

class SmartShelfConfig {
  const SmartShelfConfig({
    this.kind = SmartShelfKind.local,
    this.mode = SmartShelfMatchMode.all,
    this.groups = const [],
    this.sources = const [],
    this.subscriptionTags = const [],
  });

  final SmartShelfKind kind;
  final SmartShelfMatchMode mode;
  final List<SmartShelfConditionGroup> groups;
  final List<NovelSource> sources;
  final List<String> subscriptionTags;

  factory SmartShelfConfig.tag(String tag) {
    final normalized = BookTags.normalize([tag]);
    final cleanTag = normalized.isEmpty ? tag.trim() : normalized.first;
    return SmartShelfConfig(
      groups: [
        SmartShelfConditionGroup(
          conditions: [
            SmartShelfCondition(
              type: SmartShelfConditionType.tag,
              value: cleanTag,
            ),
          ],
        ),
      ],
    );
  }

  factory SmartShelfConfig.fromJson(Map<dynamic, dynamic> json) {
    final rawKind = '${json['kind'] ?? ''}';
    final rawMode = '${json['mode'] ?? ''}';
    final sourceIds = json['sources'] is Iterable
        ? (json['sources'] as Iterable).map((item) => '$item').toSet()
        : const <String>{};
    return SmartShelfConfig(
      kind: SmartShelfKind.values.firstWhere(
        (item) => item.name == rawKind,
        orElse: () => SmartShelfKind.local,
      ),
      mode: SmartShelfMatchMode.values.firstWhere(
        (item) => item.name == rawMode,
        orElse: () => SmartShelfMatchMode.all,
      ),
      groups: (json['groups'] is Iterable)
          ? (json['groups'] as Iterable)
                .whereType<Map>()
                .map(SmartShelfConditionGroup.fromJson)
                .where((item) => item.conditions.isNotEmpty)
                .toList()
          : const [],
      sources: NovelSource.values
          .where((source) => sourceIds.contains(source.id))
          .toList(),
      subscriptionTags: BookTags.normalize(
        json['subscriptionTags'] is Iterable
            ? json['subscriptionTags'] as Iterable
            : const [],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'mode': mode.name,
    'groups': groups.map((item) => item.toJson()).toList(),
    'sources': sources.map((item) => item.id).toList(),
    'subscriptionTags': subscriptionTags,
  };

  bool get isSubscription => kind == SmartShelfKind.subscription;

  bool matches(BookshelfNovelInfo book) {
    if (sources.isNotEmpty &&
        !sources.contains(_sourceFromBook(book.aid, book.sourceLabel))) {
      return false;
    }
    if (groups.isEmpty) return true;
    final matches = groups.map((group) => _matchesGroup(book, group));
    return mode == SmartShelfMatchMode.all
        ? matches.every((item) => item)
        : matches.any((item) => item);
  }

  bool _matchesGroup(BookshelfNovelInfo book, SmartShelfConditionGroup group) {
    final matches = group.conditions.map((condition) {
      return _matchesCondition(book, condition);
    });
    return group.mode == SmartShelfMatchMode.all
        ? matches.every((item) => item)
        : matches.any((item) => item);
  }

  bool _matchesCondition(BookshelfNovelInfo book, SmartShelfCondition c) {
    final value = c.value.trim();
    if (value.isEmpty) return true;
    switch (c.type) {
      case SmartShelfConditionType.tag:
        return BookTags.containsAny(book.tags, [value]);
      case SmartShelfConditionType.source:
        return _sourceFromBook(book.aid, book.sourceLabel).id == value;
      case SmartShelfConditionType.author:
        return book.author.toLowerCase().contains(value.toLowerCase());
      case SmartShelfConditionType.title:
        return book.title.toLowerCase().contains(value.toLowerCase());
      case SmartShelfConditionType.hasUpdate:
        return book.hasUpdate == (value == 'true');
      case SmartShelfConditionType.ratingMin:
        return book.rating >= (double.tryParse(value) ?? 0);
      case SmartShelfConditionType.ratingMax:
        return book.rating <= (double.tryParse(value) ?? 5);
      case SmartShelfConditionType.addedAfter:
        return true;
      case SmartShelfConditionType.updatedAfter:
        final date = DateTime.tryParse(value);
        if (date == null || book.updateTime == null) return false;
        return book.updateTime!.isAfter(date);
    }
  }

  NovelSource _sourceFromBook(String aid, String label) {
    if (aid.startsWith('yamibo:')) return NovelSource.yamibo;
    if (aid.startsWith('esj:')) return NovelSource.esj;
    return NovelSource.wenku8;
  }
}

class SmartShelfMembership {
  const SmartShelfMembership({
    required this.aid,
    required this.firstSeenAt,
    required this.lastSeenAt,
    this.isNew = false,
  });

  final String aid;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;
  final bool isNew;

  factory SmartShelfMembership.fromJson(Map<dynamic, dynamic> json) {
    final now = DateTime.now();
    return SmartShelfMembership(
      aid: '${json['aid'] ?? ''}',
      firstSeenAt: DateTime.tryParse('${json['firstSeenAt'] ?? ''}') ?? now,
      lastSeenAt: DateTime.tryParse('${json['lastSeenAt'] ?? ''}') ?? now,
      isNew: json['isNew'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'aid': aid,
    'firstSeenAt': firstSeenAt.toIso8601String(),
    'lastSeenAt': lastSeenAt.toIso8601String(),
    'isNew': isNew,
  };
}
