import 'package:flutter_test/flutter_test.dart';
import 'package:hikari_novel_flutter/models/book_tags.dart';
import 'package:hikari_novel_flutter/models/smart_shelf.dart';
import 'package:hikari_novel_flutter/network/yamibo_parser.dart';
import 'package:hikari_novel_flutter/pages/bookshelf/controller.dart';

void main() {
  test('matches simplified and traditional tag variants', () {
    expect(BookTags.containsAny(['異世界'], ['异世界']), isTrue);
    expect(BookTags.containsAny(['异世界'], ['異世界']), isTrue);
  });

  test('matches tag aliases by contained canonical text', () {
    expect(BookTags.containsAny(['百合向'], ['百合']), isTrue);
    expect(BookTags.containsAll(['異世界', '百合向'], ['异世界', '百合']), isTrue);
  });

  test('deduplicates equivalent simplified and traditional tags', () {
    expect(BookTags.normalize(['異世界', '异世界']), ['異世界']);
  });

  test('generates traditional query variant for simplified tags', () {
    expect(BookTags.queryVariants('异世界'), ['异世界', '異世界']);
  });

  test('detects completed status tags', () {
    expect(BookTags.isCompletedText('已完結'), isTrue);
    expect(BookTags.isCompletedText('連載中'), isFalse);
    expect(BookTags.containsAny(['完結'], ['已完结']), isTrue);
  });

  test('matches Yamibo deep subscription tags from first post text', () {
    final matched = BookshelfController.matchedYamiboSubscriptionTags(
      originalTags: ['异世界', '百合'],
      detailTags: ['Yamibo', '论坛主题'],
      matchText: '首楼简介提到了異世界冒险，也明确写了百合要素。',
    );

    expect(matched, containsAll(['异世界', '百合']));
  });

  test('keeps Yamibo source-inherent yuri tag for subscription matching', () {
    final matched = BookshelfController.matchedYamiboSubscriptionTags(
      originalTags: ['异世界', '百合'],
      detailTags: ['Yamibo', '百合', '论坛主题'],
      matchText: '里世界远足风格的现代冒险，没有目标关键词。',
    );

    expect(matched, contains('百合'));
    expect(matched, isNot(contains('异世界')));
  });

  test('matches Yamibo all-mode tags with inherent yuri plus deep text', () {
    final matched = BookshelfController.matchedYamiboSubscriptionTags(
      originalTags: ['百合', '校园'],
      detailTags: ['Yamibo', '论坛主题'],
      matchText: '首楼简介写明这是一部校园群像故事。',
    );

    expect(matched, containsAll(['百合', '校园']));
  });

  test(
    'searches Yamibo subscription by specific tags before inherent yuri',
    () {
      expect(BookshelfController.yamiboSubscriptionSearchTags(['百合', '校园']), [
        '校园',
      ]);
      expect(
        BookshelfController.yamiboSubscriptionSearchTags(['Yamibo', '百合']),
        ['百合'],
      );
    },
  );

  test('preserves deep matched tags when merging detail tags', () {
    final merged = BookTags.merge(['异世界', '姐妹'], ['Yamibo', '论坛主题']);

    expect(merged, containsAll(['异世界', '姐妹', 'Yamibo']));
  });

  test('detects Yamibo daily backup no-data responses only in window', () {
    final duringBackup = DateTime(2026, 5, 22, 5, 45);
    final outsideBackup = DateTime(2026, 5, 22, 6, 1);

    expect(
      YamiboParser.isUnavailableDuringDailyBackup('', now: duringBackup),
      isTrue,
    );
    expect(
      YamiboParser.isUnavailableDuringDailyBackup(
        '<html><body>maintenance</body></html>',
        now: duringBackup,
      ),
      isTrue,
    );
    expect(
      YamiboParser.isUnavailableDuringDailyBackup(
        '{"Variables":{"forum_threadlist":[]}}',
        now: duringBackup,
      ),
      isFalse,
    );
    expect(
      YamiboParser.isUnavailableDuringDailyBackup(
        '<html><body>regular page</body></html>',
        now: outsideBackup,
      ),
      isFalse,
    );
  });

  test('defaults subscription shelves to replace sync mode', () {
    final config = SmartShelfConfig.fromJson({
      'kind': 'subscription',
      'mode': 'all',
    });

    expect(config.subscriptionSyncMode, SmartShelfSubscriptionSyncMode.replace);
  });

  test('serializes incremental subscription sync mode', () {
    const config = SmartShelfConfig(
      kind: SmartShelfKind.subscription,
      subscriptionSyncMode: SmartShelfSubscriptionSyncMode.incremental,
    );

    final restored = SmartShelfConfig.fromJson(config.toJson());

    expect(
      restored.subscriptionSyncMode,
      SmartShelfSubscriptionSyncMode.incremental,
    );
  });
}
