import 'dart:convert';

class BookTags {
  const BookTags._();

  static const emptyJson = '[]';

  static List<String> normalize(Iterable<dynamic> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      final text = '$value'
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(RegExp(r'^[#＃]+'), '')
          .trim();
      if (text.isEmpty) continue;
      final key = text.toLowerCase();
      if (seen.add(key)) result.add(text);
    }
    return result;
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

  static String encode(Iterable<dynamic> values) => jsonEncode(normalize(values));

  static List<String> merge(Iterable<dynamic> a, Iterable<dynamic> b) =>
      normalize([...a, ...b]);

  static bool containsAny(Iterable<String> source, Iterable<String> target) {
    final sourceKeys = source.map((item) => item.toLowerCase()).toSet();
    return target.any((item) => sourceKeys.contains(item.toLowerCase()));
  }

  static bool containsAll(Iterable<String> source, Iterable<String> target) {
    final sourceKeys = source.map((item) => item.toLowerCase()).toSet();
    return target.every((item) => sourceKeys.contains(item.toLowerCase()));
  }
}
