import 'package:hikari_novel_flutter/models/source_config.dart';
import 'package:hikari_novel_flutter/models/source_id.dart';
import 'package:hikari_novel_flutter/network/api.dart';
import 'package:hikari_novel_flutter/network/esj_api.dart';
import 'package:hikari_novel_flutter/network/esj_parser.dart';
import 'package:hikari_novel_flutter/models/resource.dart';
import 'package:hikari_novel_flutter/service/source_config_service.dart';

class SourceFavoriteAdapter {
  const SourceFavoriteAdapter._();

  static bool canPushLocalToRemote(NovelSource source) {
    return switch (source) {
      NovelSource.wenku8 => true,
      NovelSource.esj => true,
      NovelSource.yamibo => false,
    };
  }

  static bool canRemoveRemote(NovelSource source) {
    return switch (source) {
      NovelSource.wenku8 => true,
      NovelSource.esj => true,
      NovelSource.yamibo => false,
    };
  }

  static bool canChooseRemoteTarget(NovelSource source) {
    return switch (source) {
      NovelSource.wenku8 => true,
      NovelSource.esj => false,
      NovelSource.yamibo => false,
    };
  }

  static bool shouldPushRemote(NovelSource source) {
    final config = SourceConfigService.instance.configOf(source);
    return canPushLocalToRemote(source) &&
        config.enabled &&
        config.pushLocalToRemote;
  }

  static bool shouldRemoveRemote(NovelSource source) {
    final config = SourceConfigService.instance.configOf(source);
    return canRemoveRemote(source) &&
        config.enabled &&
        config.pushLocalToRemote &&
        config.removeRemoteWhenLocalDeleted;
  }

  static Future<bool> addRemoteFavorite({
    required NovelSource source,
    required String aid,
  }) => _setRemoteFavorite(source: source, aid: aid, favorite: true);

  static Future<bool> removeRemoteFavorite({
    required NovelSource source,
    required String remoteId,
  }) async {
    if (!shouldRemoveRemote(source)) return false;
    switch (source) {
      case NovelSource.wenku8:
        final result = await Api.removeNovel(delid: remoteId);
        return result is Success;
      case NovelSource.esj:
        return _setRemoteFavorite(
          source: source,
          aid: remoteId,
          favorite: false,
        );
      case NovelSource.yamibo:
        return false;
    }
  }

  static Future<bool> _setRemoteFavorite({
    required NovelSource source,
    required String aid,
    required bool favorite,
  }) async {
    if (favorite && !shouldPushRemote(source)) return false;
    if (!favorite && !shouldRemoveRemote(source)) return false;
    switch (source) {
      case NovelSource.wenku8:
        if (!favorite) {
          final result = await Api.removeNovel(delid: aid);
          return result is Success;
        }
        final result = await Api.addNovel(aid: aid);
        return result is Success;
      case NovelSource.esj:
        return _setEsjRemoteFavorite(aid: aid, favorite: favorite);
      case NovelSource.yamibo:
        return false;
    }
  }

  static Future<bool> _setEsjRemoteFavorite({
    required String aid,
    required bool favorite,
  }) async {
    final exists = await _esjRemoteFavoriteExists(aid);
    if (exists == null) return false;
    if (exists == favorite) return true;

    final bookId = SourceId.esjBookId(aid);
    if (bookId.isEmpty) return false;
    final result = await EsjApi.toggleFavorite(bookId: bookId);
    if (result is! Success) return false;

    final updated = await _esjRemoteFavoriteExists(aid);
    return updated == favorite;
  }

  static Future<bool?> _esjRemoteFavoriteExists(String aid) async {
    if (!EsjApi.hasCookie) return null;
    final favorites = <String>{};
    var page = 1;
    var done = false;
    while (!done) {
      final result = await EsjApi.getFavoritePage(page: page);
      switch (result) {
        case Success():
          final items = EsjParser.getFavoritePage(result.data);
          if (items.isEmpty) {
            done = true;
            break;
          }
          final beforeCount = favorites.length;
          favorites.addAll(items.map((item) => item.aid));
          if (favorites.contains(aid)) return true;
          if (favorites.length == beforeCount) done = true;
          page += 1;
        case Error():
          return null;
      }
    }
    return false;
  }

  static NovelSource sourceOfAid(String aid) {
    if (SourceId.isEsj(aid)) return NovelSource.esj;
    if (SourceId.isYamibo(aid)) return NovelSource.yamibo;
    return NovelSource.wenku8;
  }
}
