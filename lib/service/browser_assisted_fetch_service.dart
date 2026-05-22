import 'package:hikari_novel_flutter/service/local_storage_service.dart';

class BrowserAssistedFetchService {
  const BrowserAssistedFetchService._();

  static String? getCachedHtml(String url) {
    for (final key in _cacheKeys(url)) {
      final html = LocalStorageService.instance.getAssistedHtml(key);
      if (html != null && isUsableHtml(html)) return html;
    }
    return null;
  }

  static void saveHtml({
    required String requestedUrl,
    required String currentUrl,
    required String html,
  }) {
    if (!isUsableHtml(html)) return;
    for (final key in _cacheKeys(currentUrl)) {
      LocalStorageService.instance.setAssistedHtml(key, html);
    }
    if (requestedUrl.trim().isNotEmpty) {
      for (final key in _cacheKeys(requestedUrl)) {
        LocalStorageService.instance.setAssistedHtml(key, html);
      }
    }
  }

  static List<String> _cacheKeys(String url) {
    final clean = url.trim();
    if (clean.isEmpty) return const [];
    return {
      clean,
      _withoutCharsetQuery(clean),
    }.where((key) => key.isNotEmpty).toList();
  }

  static String _withoutCharsetQuery(String url) {
    return url
        .replaceFirst(RegExp(r'([?&])charset=[^&]*&'), r'$1')
        .replaceFirst(RegExp(r'[?&]charset=[^&]*$'), '');
  }

  static bool isUsableHtml(String html) {
    final normalized = html.toLowerCase();
    if (normalized.length < 200) return false;
    if (normalized.contains('cf-browser-verification') ||
        normalized.contains('cf_chl') ||
        normalized.contains('_cf_chl_opt') ||
        normalized.contains('__cf_chl_tk') ||
        normalized.contains('cf-mitigated') ||
        normalized.contains('cloudflare challenge') ||
        normalized.contains('challenge-platform') ||
        normalized.contains('challenge-running') ||
        normalized.contains('just a moment') ||
        normalized.contains('attention required') ||
        normalized.contains('access denied')) {
      return false;
    }
    return true;
  }
}
