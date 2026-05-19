import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/source_config.dart';
import 'package:hikari_novel_flutter/pages/main/controller.dart';
import 'package:hikari_novel_flutter/router/route_path.dart';

class AppSubRouter {
  // Current content route name.
  static String currentContentRouteName = RoutePath.logo;

  // Sub navigator id.
  static final int subNavigatorId = 1;

  // Sub navigator key.
  static final GlobalKey<NavigatorState>? subNavigatorKey = Get.nestedKey(
    subNavigatorId,
  );

  static void _toContentPage(String name, {dynamic arg, bool replace = false}) {
    Get.find<MainController>().showContent.value = true;
    if (!replace && arg == null && currentContentRouteName == name) return;
    if (replace) {
      Get.offAndToNamed(name, arguments: arg, id: subNavigatorId);
    } else {
      Get.toNamed(name, arguments: arg, id: subNavigatorId);
    }
  }

  static void toNovelDetail({required String aid}) =>
      _toContentPage(RoutePath.novelDetail, arg: aid);

  static void toComment({required String aid}) =>
      _toContentPage(RoutePath.comment, arg: aid);

  static void toReply({required String aid, required String rid}) =>
      _toContentPage(RoutePath.reply, arg: [aid, rid]);

  static void toUserBookshelf({required String uid}) =>
      _toContentPage(RoutePath.userBookshelf, arg: uid);

  static void toBrowsingHistory() => _toContentPage(RoutePath.browsingHistory);

  static void toUserInfo() => _toContentPage(RoutePath.userInfo);

  static void toAbout() => _toContentPage(RoutePath.about);

  static void toSetting() => _toContentPage(RoutePath.setting);

  static void toSearch({String? author, NovelSource? source}) => _toContentPage(
    RoutePath.search,
    arg: {'author': author, 'source': source?.id},
  );

  static void toEsjSearch({required String keyword}) => _toContentPage(
    RoutePath.search,
    arg: {'source': NovelSource.esj.id, 'esjKeyword': keyword},
  );

  static void toEsjTagSearch({required String tag}) => _toContentPage(
    RoutePath.search,
    arg: {'source': NovelSource.esj.id, 'esjTag': tag},
  );

  static void toCacheQueue() => _toContentPage(RoutePath.cacheQueue);

  static void toDevTools() => _toContentPage(RoutePath.devTools);

  static void toYamiboForum() => _toContentPage(RoutePath.yamiboForum);

  static void toYamiboAuthorThreads({
    required String authorName,
    required String authorId,
  }) => _toContentPage(
    RoutePath.yamiboAuthorThreads,
    arg: {'authorName': authorName, 'authorId': authorId},
  );

  static void toEsjzone({String? url}) =>
      _toContentPage(RoutePath.esjzone, arg: url);
}
