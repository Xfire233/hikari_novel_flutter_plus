import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/source_config.dart';
import 'package:hikari_novel_flutter/pages/about/view.dart';
import 'package:hikari_novel_flutter/pages/cache_queue/view.dart';
import 'package:hikari_novel_flutter/pages/dev_tools/view.dart';
import 'package:hikari_novel_flutter/pages/esjzone_web/view.dart';
import 'package:hikari_novel_flutter/pages/comment/view.dart';
import 'package:hikari_novel_flutter/pages/home/view.dart';
import 'package:hikari_novel_flutter/pages/login/view.dart';
import 'package:hikari_novel_flutter/pages/main/view.dart';
import 'package:hikari_novel_flutter/pages/novel_detail/view.dart';
import 'package:hikari_novel_flutter/pages/photo/view.dart';
import 'package:hikari_novel_flutter/pages/reader/view.dart';
import 'package:hikari_novel_flutter/pages/reader/widgets/reader_setting.dart';
import 'package:hikari_novel_flutter/pages/reply/view.dart';
import 'package:hikari_novel_flutter/pages/search/view.dart';
import 'package:hikari_novel_flutter/pages/setting/view.dart';
import 'package:hikari_novel_flutter/pages/user_bookshelf/view.dart';
import 'package:hikari_novel_flutter/pages/user_info/view.dart';
import 'package:hikari_novel_flutter/pages/welcome/view.dart';
import 'package:hikari_novel_flutter/pages/yamibo_forum/view.dart';
import 'package:hikari_novel_flutter/router/route_path.dart';

import '../pages/browsing_history/view.dart';
import '../widgets/state_page.dart';

class AppRoutes {
  static final List<GetPage<dynamic>> mainRoutePages = [
    CustomGetPage(name: RoutePath.main, page: () => MainPage()),
    CustomGetPage(name: RoutePath.home, page: () => HomePage()),
    CustomGetPage(name: RoutePath.login, page: () => LoginPage()),
    CustomGetPage(name: RoutePath.photo, page: () => PhotoPage()),
    CustomGetPage(name: RoutePath.reader, page: () => ReaderPage()),
    CustomGetPage(name: RoutePath.welcome, page: () => WelcomePage()),
    CustomGetPage(
      name: RoutePath.readerSetting,
      page: () => ReaderSettingPage(),
    ),
  ];

  static Route<dynamic>? subRoutePages(RouteSettings settings) {
    switch (settings.name) {
      case RoutePath.logo:
        return GetPageRoute(settings: settings, page: () => LogoPage());
      case RoutePath.novelDetail:
        {
          final raw = settings.arguments;
          final args = raw is Map
              ? raw.map((key, value) => MapEntry('$key', value))
              : {'aid': '$raw'};
          return _contentRoute(
            settings: settings,
            page: () => NovelDetailPage(
              aid: '${args['aid'] ?? ''}',
              seedTitle: '${args['title'] ?? ''}',
              seedImageUrl: args['imageUrl']?.toString(),
            ),
          );
        }
      case RoutePath.comment:
        {
          var args = settings.arguments as String;
          return _contentRoute(
            settings: settings,
            page: () => CommentPage(aid: args),
          );
        }
      case RoutePath.reply:
        {
          var args = settings.arguments as List<String>;
          return _contentRoute(
            settings: settings,
            page: () => ReplyPage(aid: args[0], rid: args[1]),
          );
        }
      case RoutePath.userBookshelf:
        {
          var args = settings.arguments as String;
          return _contentRoute(
            settings: settings,
            page: () => UserBookshelfPage(uid: args),
          );
        }
      case RoutePath.browsingHistory:
        return _contentRoute(
          settings: settings,
          page: () => BrowsingHistoryPage(),
        );
      case RoutePath.userInfo:
        return _contentRoute(settings: settings, page: () => UserInfoPage());
      case RoutePath.about:
        return _contentRoute(settings: settings, page: () => AboutPage());
      case RoutePath.setting:
        return _contentRoute(settings: settings, page: () => SettingPage());
      case RoutePath.search:
        {
          final args = settings.arguments;
          final author = args is String
              ? args
              : args is Map
              ? args['author'] as String?
              : null;
          final sourceId = args is Map ? args['source'] as String? : null;
          final initialSource = _sourceFromId(sourceId);
          final esjTag = args is Map ? args['esjTag'] as String? : null;
          final esjKeyword = args is Map ? args['esjKeyword'] as String? : null;
          return _contentRoute(
            settings: settings,
            page: () => SearchPage(
              author: author,
              initialSource: initialSource,
              esjTag: esjTag,
              esjKeyword: esjKeyword,
            ),
          );
        }
      case RoutePath.cacheQueue:
        return _contentRoute(settings: settings, page: () => CacheQueuePage());
      case RoutePath.devTools:
        return _contentRoute(
          settings: settings,
          page: () => const DevToolsPage(),
        );
      case RoutePath.yamiboForum:
        return _contentRoute(
          settings: settings,
          page: () => const YamiboForumPage(),
        );
      case RoutePath.yamiboAuthorThreads:
        final args = settings.arguments as Map?;
        return _contentRoute(
          settings: settings,
          page: () => YamiboAuthorThreadPage(
            authorName: args?['authorName'] as String? ?? 'Yamibo',
            authorId: args?['authorId'] as String? ?? '',
          ),
        );
      case RoutePath.esjzone:
        final args = settings.arguments as String?;
        return _contentRoute(
          settings: settings,
          page: () => EsjzoneWebPage(initialUrl: args),
        );
      default:
        return null;
    }
  }

  static NovelSource? _sourceFromId(String? sourceId) {
    for (final source in NovelSource.values) {
      if (source.id == sourceId) return source;
    }
    return null;
  }

  static GetPageRoute<dynamic> _contentRoute({
    required RouteSettings settings,
    required Widget Function() page,
  }) {
    return GetPageRoute(
      settings: settings,
      page: page,
      transition: Transition.rightToLeftWithFade,
      curve: Curves.easeOutCubic,
      transitionDuration: const Duration(milliseconds: 220),
    );
  }
}

class CustomGetPage extends GetPage<dynamic> {
  CustomGetPage({
    required super.name,
    required super.page,
    this.fullscreen = false,
    super.transitionDuration,
  }) : super(
         curve: Curves.linear,
         transition: Transition.native,
         showCupertinoParallax: false,
         popGesture: false,
         fullscreenDialog: fullscreen != null && fullscreen,
       );
  late final bool? fullscreen;
}
