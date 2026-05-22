import 'dart:convert';

class BookTags {
  const BookTags._();

  static const emptyJson = '[]';

  static const _traditionalToSimplified = <String, String>{
    '\u7570': '\u5f02',
    '\u570b': '\u56fd',
    '\u8f15': '\u8f7b',
    '\u50b3': '\u4f20',
    '\u6200': '\u604b',
    '\u611b': '\u7231',
    '\u5b78': '\u5b66',
    '\u8f49': '\u8f6c',
    '\u8a9e': '\u8bed',
    '\u9577': '\u957f',
    '\u528d': '\u5251',
    '\u9ad4': '\u4f53',
    '\u5f8c': '\u540e',
    '\u88cf': '\u91cc',
    '\u88e1': '\u91cc',
    '\u958b': '\u5f00',
    '\u95dc': '\u5173',
    '\u96d9': '\u53cc',
    '\u55ae': '\u5355',
    '\u9748': '\u7075',
    '\u9f8d': '\u9f99',
    '\u5287': '\u5267',
    '\u8056': '\u5723',
    '\u6230': '\u6218',
    '\u8c93': '\u732b',
    '\u7378': '\u517d',
    '\u7375': '\u730e',
    '\u60e1': '\u6076',
    '\u5922': '\u68a6',
    '\u8a2d': '\u8bbe',
    '\u507d': '\u4f2a',
    '\u61f8': '\u60ac',
    '\u99ac': '\u9a6c',
    '\u9a0e': '\u9a91',
    '\u95b1': '\u9605',
    '\u5e2b': '\u5e08',
    '\u8853': '\u672f',
    '\u4e9e': '\u4e9a',
    '\u843d': '\u843d',
    '\u821e': '\u821e',
    '\u9ede': '\u70b9',
    '\u7121': '\u65e0',
    '\u8b8a': '\u53d8',
    '\u66f4': '\u66f4',
    '\u95c7': '\u6697',
    '\u8a18': '\u8bb0',
    '\u7d50': '\u7ed3',
    '\u9023': '\u8fde',
    '\u8f09': '\u8f7d',
    '\u5b8c': '\u5b8c',
    '\u9032': '\u8fdb',
    '\u884c': '\u884c',
    '\u72c0': '\u72b6',
    '\u614b': '\u6001',
  };

  static final Map<String, String> _simplifiedToTraditional = {
    for (final entry in _traditionalToSimplified.entries)
      entry.value: entry.key,
  };

  static List<String> normalize(Iterable<dynamic> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      final text = clean(value);
      if (text.isEmpty) continue;
      final key = canonicalKey(text);
      if (seen.add(key)) result.add(text);
    }
    return result;
  }

  static String clean(dynamic value) => '$value'
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[#＃\+：:，,\s]+'), '')
      .trim();

  static String canonicalKey(dynamic value) {
    final text = clean(value).toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (text.isEmpty) return '';
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_traditionalToSimplified[char] ?? char);
    }
    return buffer.toString();
  }

  static List<String> queryVariants(dynamic value) {
    final cleanText = clean(value);
    if (cleanText.isEmpty) return const [];
    final variants = <String>[cleanText];
    final traditional = StringBuffer();
    var changed = false;
    for (final rune in cleanText.runes) {
      final char = String.fromCharCode(rune);
      final mapped = _simplifiedToTraditional[char] ?? char;
      if (mapped != char) changed = true;
      traditional.write(mapped);
    }
    if (changed) variants.add(traditional.toString());
    final seen = <String>{};
    return [
      for (final variant in variants)
        if (seen.add(variant.toLowerCase())) variant,
    ];
  }

  static List<String> statusTags([String? a, String? b, String? c]) {
    final text = [a, b, c].whereType<String>().join(' ');
    if (isCompletedText(text)) return const ['已完结'];
    return const [];
  }

  static bool isCompletedTag(dynamic value) =>
      canonicalKey(value) == canonicalKey('已完结') || isCompletedText('$value');

  static bool isCompletedText(String value) {
    final key = canonicalKey(value);
    if (key.contains('未完') ||
        key.contains('连载') ||
        key.contains('连载中') ||
        key.contains('进行中')) {
      return false;
    }
    return key.contains('已完结') ||
        key.contains('完结') ||
        key.contains('完本') ||
        key.contains('完结済');
  }

  static List<String> decode(String? jsonText) {
    if (jsonText == null || jsonText.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is Iterable) return normalize(decoded);
    } catch (_) {
      return const [];
    }
    return const [];
  }

  static String encode(Iterable<dynamic> values) =>
      jsonEncode(normalize(values));

  static List<String> merge(Iterable<dynamic> a, Iterable<dynamic> b) =>
      normalize([...a, ...b]);

  static bool containsAny(Iterable<String> source, Iterable<String> target) {
    final sourceKeys = source.map(canonicalKey).where((e) => e.isNotEmpty);
    final targetKeys = target.map(canonicalKey).where((e) => e.isNotEmpty);
    return targetKeys.any(
      (targetKey) =>
          sourceKeys.any((sourceKey) => _tagKeyMatches(sourceKey, targetKey)),
    );
  }

  static bool containsAll(Iterable<String> source, Iterable<String> target) {
    final sourceKeys = source.map(canonicalKey).where((e) => e.isNotEmpty);
    final targetKeys = target.map(canonicalKey).where((e) => e.isNotEmpty);
    return targetKeys.every(
      (targetKey) =>
          sourceKeys.any((sourceKey) => _tagKeyMatches(sourceKey, targetKey)),
    );
  }

  static bool _tagKeyMatches(String sourceKey, String targetKey) {
    if (sourceKey == targetKey) return true;
    if (sourceKey.length < 2 || targetKey.length < 2) return false;
    return sourceKey.contains(targetKey) || targetKey.contains(sourceKey);
  }
}
