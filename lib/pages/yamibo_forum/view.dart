import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/common/constants.dart';
import 'package:hikari_novel_flutter/common/database/database.dart';
import 'package:hikari_novel_flutter/main.dart';
import 'package:hikari_novel_flutter/models/book_tags.dart';
import 'package:hikari_novel_flutter/models/source_config.dart';
import 'package:hikari_novel_flutter/network/request.dart';
import 'package:hikari_novel_flutter/network/yamibo_api.dart';
import 'package:hikari_novel_flutter/network/yamibo_parser.dart';
import 'package:hikari_novel_flutter/pages/bookshelf/controller.dart';
import 'package:hikari_novel_flutter/router/app_sub_router.dart';
import 'package:hikari_novel_flutter/service/db_service.dart';
import 'package:hikari_novel_flutter/service/local_storage_service.dart';
import 'package:hikari_novel_flutter/service/source_auth_guard.dart';
import 'package:hikari_novel_flutter/service/source_config_service.dart';
import 'package:hikari_novel_flutter/widgets/browsing_novel_grid.dart';
import 'package:hikari_novel_flutter/widgets/source_backdrop.dart';
import 'package:hikari_novel_flutter/widgets/state_page.dart';

import '../../models/resource.dart';

class YamiboForumPage extends StatefulWidget {
  const YamiboForumPage({
    super.key,
    this.showAppBar = true,
    this.showForumTabs = true,
    this.initialFid = YamiboApi.literatureFid,
  });

  final bool showAppBar;
  final bool showForumTabs;
  final String initialFid;

  @override
  State<YamiboForumPage> createState() => _YamiboForumPageState();
}

class _YamiboForumPageState extends State<YamiboForumPage> {
  final _scrollController = ScrollController();
  final _threads = <YamiboForumThread>[];
  final _types = <YamiboForumType>[];
  final _favoriteAids = <String>{};

  late String _currentFid = widget.initialFid;
  String? _selectedTypeId;
  String _forumName = 'Yamibo';
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadFavorites();
    _loadPage(refresh: true);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      top: false,
      child: Column(
        children: [
          _buildForumSelector(context),
          Expanded(child: _buildBody()),
        ],
      ),
    );

    if (!widget.showAppBar) return content;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Text(_forumTitle(_currentFid)),
        actions: [
          IconButton(
            onPressed: () => _loadPage(refresh: true),
            icon: const Icon(Icons.refresh),
            tooltip: 'refresh'.tr,
          ),
          IconButton(
            onPressed: _openWebLogin,
            icon: const Icon(Icons.login),
            tooltip: 'yamibo_web_login'.tr,
          ),
          PopupMenuButton<_YamiboAction>(
            onSelected: _handleAction,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _YamiboAction.openWeb,
                child: Text('yamibo_open_web'.tr),
              ),
            ],
          ),
        ],
      ),
      body: SourceBackdrop(source: NovelSource.yamibo, child: content),
    );
  }

  Widget _buildForumSelector(BuildContext context) {
    final selectedTypeText = _typeName(_selectedTypeId ?? '');
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showForumTabs)
          SizedBox(
            height: 48,
            child: YamiboHomeTabs(
              currentFid: _currentFid,
              onChanged: _changeForum,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              splashColor: scheme.primary.withValues(alpha: 0.08),
            ),
            child: Material(
              color: scheme.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(18),
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                title: Row(
                  children: [
                    const Icon(Icons.sell_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selectedTypeText.isEmpty
                            ? 'yamibo_forum_type_all'.tr
                            : selectedTypeText,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.36,
                    ),
                    child: SingleChildScrollView(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            ChoiceChip(
                              label: Text('yamibo_forum_type_all'.tr),
                              selected: _selectedTypeId == null,
                              showCheckmark: false,
                              onSelected: (_) => _changeType(null),
                            ),
                            ..._types.map(
                              (type) => ChoiceChip(
                                label: Text(type.title),
                                selected: _selectedTypeId == type.id,
                                showCheckmark: false,
                                onSelected: (_) => _changeType(type.id),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<(String, String)> get _forumOptions => const [
    (YamiboApi.literatureFid, '文学区'),
    (YamiboApi.lightNovelFid, '轻小说/译文区'),
    (YamiboApi.txtNovelFid, 'TXT 小说区'),
  ];

  String _forumTitle(String fid) {
    for (final item in _forumOptions) {
      if (item.$1 == fid) return item.$2;
    }
    return _forumName;
  }

  void _changeForum(String fid) {
    if (_currentFid == fid) return;
    setState(() {
      _currentFid = fid;
      _selectedTypeId = null;
      _types.clear();
      _threads.clear();
      _page = 1;
      _hasMore = true;
      _forumName = _forumTitle(fid);
    });
    _loadPage(refresh: true);
  }

  Widget _buildBody() {
    if (_loading && _threads.isEmpty) return const LoadingPage();
    if (_errorMessage != null && _threads.isEmpty) {
      final loginRequired = _errorMessage == 'source_login_required'.tr;
      return ErrorMessage(
        msg: _errorMessage!,
        action: loginRequired ? _openWebLogin : () => _loadPage(refresh: true),
        buttonText: loginRequired ? 'yamibo_web_login' : 'retry',
        iconData: loginRequired ? Icons.login : Icons.refresh,
      );
    }
    if (_threads.isEmpty) {
      return EmptyPage(onRefresh: () => _loadPage(refresh: true));
    }

    if (LocalStorageService.instance.getBrowsingEInkMode()) {
      return BrowsingPageMode(
        page: _page,
        canPreviousPage: _page > 1,
        canNextPage: _hasMore,
        onPreviousPage: _previousForumPage,
        onNextPage: _nextForumPage,
        onRefresh: _refreshForumPage,
        contentKey: '$_currentFid|$_selectedTypeId|$_page|${_threads.length}',
        localPageCountBuilder: (constraints) {
          final itemsPerPage = _threadItemsPerLocalPage(constraints);
          return (_threads.length + itemsPerPage - 1) ~/ itemsPerPage;
        },
        contentBuilder: _buildThreadPage,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadPage(refresh: true),
      child: _buildThreadList(showLoadingFooter: true),
    );
  }

  Widget _buildThreadList({required bool showLoadingFooter}) {
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(
        kPageHorizontalPadding,
        8,
        kPageHorizontalPadding,
        24,
      ),
      itemCount: _threads.length + (showLoadingFooter && _loadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        if (index >= _threads.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _ThreadTile(
          thread: _threads[index],
          typeName: _typeName(_threads[index].typeId),
          favorited: _favoriteAids.contains(_threads[index].aid),
          onTap: () => _openThread(_threads[index]),
          onFavorite: () => _favoriteThread(_threads[index]),
        );
      },
    );
  }

  int _threadItemsPerLocalPage(BoxConstraints constraints) {
    final height = constraints.maxHeight.isFinite
        ? constraints.maxHeight
        : 560.0;
    const verticalPadding = 16.0;
    const itemHeight = 78.0;
    final usableHeight = (height - verticalPadding).clamp(1.0, height);
    return (usableHeight / itemHeight).floor().clamp(1, 40);
  }

  Widget _buildThreadPage(
    BuildContext context,
    BoxConstraints constraints,
    int localPage,
  ) {
    final itemsPerPage = _threadItemsPerLocalPage(constraints);
    final start = localPage * itemsPerPage;
    final end = (start + itemsPerPage).clamp(0, _threads.length);
    final visibleThreads = start >= _threads.length
        ? <YamiboForumThread>[]
        : _threads.sublist(start, end);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        kPageHorizontalPadding,
        8,
        kPageHorizontalPadding,
        8,
      ),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visibleThreads.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final thread = visibleThreads[index];
        return _ThreadTile(
          thread: thread,
          typeName: _typeName(thread.typeId),
          favorited: _favoriteAids.contains(thread.aid),
          compact: true,
          onTap: () => _openThread(thread),
          onFavorite: () => _favoriteThread(thread),
        );
      },
    );
  }

  Future<IndicatorResult> _loadPage({
    required bool refresh,
    int? pageOverride,
  }) async {
    if (_loadingMore || (_loading && !refresh)) {
      return IndicatorResult.noMore;
    }
    final replacing = refresh || pageOverride != null;
    final nextPage = pageOverride ?? (refresh ? 1 : _page + 1);
    setState(() {
      if (replacing) {
        _loading = true;
        _errorMessage = null;
      } else {
        _loadingMore = true;
      }
    });

    final result = await YamiboApi.getForumPage(
      fid: _currentFid,
      page: nextPage,
      typeId: _selectedTypeId,
    );
    if (!mounted) return IndicatorResult.fail;

    switch (result) {
      case Success():
        try {
          if (YamiboParser.isUnavailableDuringDailyBackup(result.data)) {
            setState(() {
              _loading = false;
              _loadingMore = false;
              _errorMessage = 'yamibo_backup_window'.tr;
            });
            return IndicatorResult.fail;
          }
          final data = YamiboParser.getForumPageData(result.data);
          if (data.hasPermissionError) {
            SourceAuthGuard.clearLogin(NovelSource.yamibo);
            SourceAuthGuard.showLoginRequired(NovelSource.yamibo);
            _showLoginRequired(refresh: replacing);
            return IndicatorResult.fail;
          }
          if (data.threads.isEmpty && nextPage > 1) {
            setState(() {
              _hasMore = false;
              _loading = false;
              _loadingMore = false;
            });
            return IndicatorResult.noMore;
          }
          setState(() {
            _forumName = data.forumName.isEmpty
                ? 'yamibo_literature'.tr
                : data.forumName;
            if (data.types.isNotEmpty) {
              _types
                ..clear()
                ..addAll(data.types);
            }
            if (replacing) _threads.clear();
            _threads.addAll(data.threads);
            _page = nextPage;
            _hasMore =
                data.threads.length >= data.perPage &&
                (_threads.length < data.threadCount || data.threadCount == 0);
            _loading = false;
            _loadingMore = false;
            _errorMessage = null;
          });
          return IndicatorResult.success;
        } catch (e) {
          setState(() {
            _loading = false;
            _loadingMore = false;
            _errorMessage = e.toString();
          });
          return IndicatorResult.fail;
        }
      case Error():
        setState(() {
          _loading = false;
          _loadingMore = false;
          _errorMessage = result.error.toString();
        });
        return IndicatorResult.fail;
    }
  }

  Future<IndicatorResult> _refreshForumPage() => _loadPage(refresh: true);

  Future<IndicatorResult> _previousForumPage() {
    if (_page <= 1) return Future.value(IndicatorResult.noMore);
    return _loadPage(refresh: false, pageOverride: _page - 1);
  }

  Future<IndicatorResult> _nextForumPage() {
    if (!_hasMore) return Future.value(IndicatorResult.noMore);
    return _loadPage(refresh: false, pageOverride: _page + 1);
  }

  void _showLoginRequired({required bool refresh}) {
    setState(() {
      if (refresh) _threads.clear();
      _loading = false;
      _loadingMore = false;
      _errorMessage = 'source_login_required'.tr;
    });
  }

  void _handleScroll() {
    if (LocalStorageService.instance.getBrowsingEInkMode()) return;
    if (!_hasMore ||
        _loading ||
        _loadingMore ||
        !_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 360) {
      _loadPage(refresh: false);
    }
  }

  void _changeType(String? typeId) {
    if (_selectedTypeId == typeId) return;
    setState(() => _selectedTypeId = typeId);
    _loadPage(refresh: true);
  }

  Future<void> _loadFavorites() async {
    final data = await DBService.instance
        .getBookshelfByClassId(BookshelfController.yamiboClassId)
        .first;
    if (!mounted) return;
    setState(() {
      _favoriteAids
        ..clear()
        ..addAll(data.map((item) => item.aid));
    });
  }

  String _typeName(String typeId) {
    if (typeId.isEmpty) return '';
    for (final item in _types) {
      if (item.id == typeId) return item.title;
    }
    return '';
  }

  void _openThread(YamiboForumThread thread) {
    AppSubRouter.toNovelDetail(aid: thread.aid);
  }

  Future<void> _favoriteThread(YamiboForumThread thread) async {
    await DBService.instance.upsertBookshelf(
      BookshelfEntityData(
        aid: thread.aid,
        bid: thread.aid,
        url: YamiboApi.threadUrl(thread.tid),
        title: thread.title,
        img: '',
        classId: BookshelfController.yamiboClassId,
        updateKey: thread.lastPostTime?.millisecondsSinceEpoch.toString() ?? '',
        updateTime: thread.lastPostTime,
        hasUpdate: false,
        rating: 0,
        remoteTagsJson: BookTags.encode([
          ...YamiboParser.yamiboTags(const []),
          _typeName(thread.typeId),
          ...YamiboParser.safeTitleTags(thread.title),
        ]),
        localTagsJson: BookTags.emptyJson,
      ),
    );
    SourceConfigService.instance.restoreLocalFavorite(
      NovelSource.yamibo,
      thread.aid,
    );
    await _loadFavorites();
    await _refreshBookshelfFoldersIfVisible();
    if (mounted) showSnackBar(message: 'favorited'.tr, context: context);
  }

  Future<void> _handleAction(_YamiboAction action) async {
    switch (action) {
      case _YamiboAction.openWeb:
        await _openWebLogin();
    }
  }

  Future<void> _openWebLogin() async {
    final result = await Navigator.of(context, rootNavigator: true)
        .push<YamiboWebLoginResult>(
          MaterialPageRoute(builder: (_) => const YamiboWebLoginPage()),
        );
    if (result?.loggedIn == true) {
      SourceConfigService.instance.enableSourceAfterLogin(NovelSource.yamibo);
      if (result?.syncFavorites == true &&
          SourceConfigService.instance.shouldPullOnlineToLocal(
            NovelSource.yamibo,
          )) {
        await BookshelfController.syncYamiboFavoritesToBookshelf();
        await _loadFavorites();
        await _refreshBookshelfFoldersIfVisible();
      }
      await _loadPage(refresh: true);
    }
  }

  Future<void> _refreshBookshelfFoldersIfVisible() async {
    if (!Get.isRegistered<BookshelfController>()) return;
    await Get.find<BookshelfController>().loadFolders();
  }
}

class YamiboWebLoginResult {
  const YamiboWebLoginResult({
    required this.loggedIn,
    required this.syncFavorites,
  });

  final bool loggedIn;
  final bool syncFavorites;
}

class YamiboHomeTabs extends StatelessWidget {
  const YamiboHomeTabs({
    super.key,
    required this.currentFid,
    required this.onChanged,
  });

  final String currentFid;
  final ValueChanged<String> onChanged;

  static const options = [
    (YamiboApi.literatureFid, '文学区'),
    (YamiboApi.lightNovelFid, '轻小说/译文区'),
    (YamiboApi.txtNovelFid, 'TXT 小说区'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const minItemWidth = 116.0;
        final needsScroll =
            constraints.maxWidth < minItemWidth * options.length;
        final availableWidth = (constraints.maxWidth - 10).clamp(
          0.0,
          double.infinity,
        );
        if (!needsScroll) {
          final itemWidth = availableWidth / options.length;
          return Row(
            children: [
              for (final item in options)
                SizedBox(
                  width: itemWidth,
                  child: _YamiboHomeTabButton(
                    label: item.$2,
                    selected: currentFid == item.$1,
                    onTap: () => onChanged(item.$1),
                  ),
                ),
            ],
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (final item in options)
                SizedBox(
                  width: minItemWidth,
                  child: _YamiboHomeTabButton(
                    label: item.$2,
                    selected: currentFid == item.$1,
                    onTap: () => onChanged(item.$1),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _YamiboHomeTabButton extends StatelessWidget {
  const _YamiboHomeTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
      child: Material(
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class YamiboWebLoginPage extends StatefulWidget {
  const YamiboWebLoginPage({super.key});

  @override
  State<YamiboWebLoginPage> createState() => _YamiboWebLoginPageState();
}

class _YamiboWebLoginPageState extends State<YamiboWebLoginPage> {
  final _cookieManager = CookieManager.instance();
  InAppWebViewController? _webViewController;
  double _progress = 0;
  String _title = 'Yamibo';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final loggedIn = await _syncCookie(silent: true);
        if (!context.mounted) return;
        if (!loggedIn) {
          showSnackBar(message: 'source_login_required'.tr, context: context);
        }
        Navigator.of(
          context,
        ).pop(YamiboWebLoginResult(loggedIn: loggedIn, syncFavorites: false));
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_title),
          actions: [
            IconButton(
              onPressed: _webViewController?.reload,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              onPressed: _syncAndCloseIfLoggedIn,
              icon: const Icon(Icons.sync),
              tooltip: 'yamibo_sync_login'.tr,
            ),
            TextButton(onPressed: _finish, child: Text('confirm'.tr)),
          ],
        ),
        body: Column(
          children: [
            if (_progress > 0 && _progress < 1)
              LinearProgressIndicator(value: _progress),
            Expanded(
              child: InAppWebView(
                webViewEnvironment: webViewEnvironment,
                initialUrlRequest: URLRequest(
                  url: WebUri('${YamiboApi.baseUrl}/forum.php?mobile=2'),
                ),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  mediaPlaybackRequiresUserGesture: false,
                  transparentBackground: false,
                  useShouldOverrideUrlLoading: false,
                  supportZoom: true,
                  sharedCookiesEnabled: true,
                  thirdPartyCookiesEnabled: true,
                  userAgent: Request.userAgent.values.first,
                ),
                onWebViewCreated: (controller) =>
                    _webViewController = controller,
                onTitleChanged: (_, title) {
                  if (!mounted) return;
                  setState(() {
                    _title = title?.trim().isNotEmpty == true
                        ? title!.trim()
                        : 'Yamibo';
                  });
                },
                onLoadStop: (_, _) => _syncCookie(silent: true),
                onProgressChanged: (_, progress) {
                  if (!mounted) return;
                  setState(() => _progress = progress / 100);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _finish() async {
    final loggedIn = await _syncCookie(silent: true);
    if (!mounted) return;
    Navigator.of(
      context,
    ).pop(YamiboWebLoginResult(loggedIn: loggedIn, syncFavorites: false));
  }

  Future<void> _syncAndCloseIfLoggedIn() async {
    final loggedIn = await _syncCookie();
    if (!mounted || !loggedIn) return;
    Navigator.of(
      context,
    ).pop(const YamiboWebLoginResult(loggedIn: true, syncFavorites: true));
  }

  Future<bool> _syncCookie({bool silent = false}) async {
    final cookies = await _cookieManager.getCookies(
      url: WebUri(YamiboApi.baseUrl),
    );
    final cookie = cookies
        .where((c) => c.name.isNotEmpty)
        .map((c) => '${c.name}=${c.value}')
        .join('; ');
    if (cookie.isEmpty) {
      if (!silent) {
        LocalStorageService.instance.setYamiboCookie(null);
      }
      if (!silent && mounted) {
        showSnackBar(message: 'source_login_required'.tr, context: context);
      }
      return false;
    }
    final loggedIn = YamiboApi.isAuthenticatedCookie(cookie);
    if (loggedIn) {
      LocalStorageService.instance.setYamiboCookie(cookie);
      SourceConfigService.instance.enableSourceAfterLogin(NovelSource.yamibo);
    } else {
      if (!silent || LocalStorageService.instance.getYamiboCookie() != null) {
        LocalStorageService.instance.setYamiboCookie(null);
      }
    }
    if (!silent && mounted) {
      showSnackBar(
        message: loggedIn
            ? 'yamibo_login_synced'.tr
            : 'source_login_required'.tr,
        context: context,
      );
    }
    return loggedIn;
  }
}

enum _YamiboAction { openWeb }

class YamiboAuthorThreadPage extends StatefulWidget {
  const YamiboAuthorThreadPage({
    super.key,
    required this.authorName,
    required this.authorId,
  });

  final String authorName;
  final String authorId;

  @override
  State<YamiboAuthorThreadPage> createState() => _YamiboAuthorThreadPageState();
}

class _YamiboAuthorThreadPageState extends State<YamiboAuthorThreadPage> {
  final _scrollController = ScrollController();
  final _threads = <YamiboForumThread>[];
  final _favoriteAids = <String>{};
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadFavorites();
    _loadPage(refresh: true);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Text(widget.authorName.isEmpty ? 'Yamibo' : widget.authorName),
        actions: [
          IconButton(
            onPressed: () => _loadPage(refresh: true),
            icon: const Icon(Icons.refresh),
            tooltip: 'refresh'.tr,
          ),
        ],
      ),
      body: SourceBackdrop(source: NovelSource.yamibo, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading && _threads.isEmpty) return const LoadingPage();
    if (_errorMessage != null && _threads.isEmpty) {
      return ErrorMessage(
        msg: _errorMessage!,
        action: () => _loadPage(refresh: true),
        buttonText: 'retry',
        iconData: Icons.refresh,
      );
    }
    if (_threads.isEmpty) {
      return EmptyPage(onRefresh: () => _loadPage(refresh: true));
    }

    if (LocalStorageService.instance.getBrowsingEInkMode()) {
      return BrowsingPageMode(
        page: _page,
        canPreviousPage: _page > 1,
        canNextPage: _hasMore,
        onPreviousPage: _previousPage,
        onNextPage: _nextPage,
        onRefresh: _refreshPage,
        contentKey: '${widget.authorId}|$_page|${_threads.length}',
        localPageCountBuilder: (constraints) {
          final itemsPerPage = _threadItemsPerLocalPage(constraints);
          return (_threads.length + itemsPerPage - 1) ~/ itemsPerPage;
        },
        contentBuilder: _buildThreadPage,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadPage(refresh: true),
      child: _buildThreadList(showLoadingFooter: true),
    );
  }

  Widget _buildThreadList({required bool showLoadingFooter}) {
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(
        kPageHorizontalPadding,
        8,
        kPageHorizontalPadding,
        24,
      ),
      itemCount: _threads.length + (showLoadingFooter && _loadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        if (index >= _threads.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _ThreadTile(
          thread: _threads[index],
          typeName: '',
          favorited: _favoriteAids.contains(_threads[index].aid),
          onTap: () => _openThread(_threads[index]),
          onFavorite: () => _favoriteThread(_threads[index]),
        );
      },
    );
  }

  int _threadItemsPerLocalPage(BoxConstraints constraints) {
    final height = constraints.maxHeight.isFinite
        ? constraints.maxHeight
        : 560.0;
    const verticalPadding = 16.0;
    const itemHeight = 78.0;
    final usableHeight = (height - verticalPadding).clamp(1.0, height);
    return (usableHeight / itemHeight).floor().clamp(1, 40);
  }

  Widget _buildThreadPage(
    BuildContext context,
    BoxConstraints constraints,
    int localPage,
  ) {
    final itemsPerPage = _threadItemsPerLocalPage(constraints);
    final start = localPage * itemsPerPage;
    final end = (start + itemsPerPage).clamp(0, _threads.length);
    final visibleThreads = start >= _threads.length
        ? <YamiboForumThread>[]
        : _threads.sublist(start, end);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        kPageHorizontalPadding,
        8,
        kPageHorizontalPadding,
        8,
      ),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visibleThreads.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final thread = visibleThreads[index];
        return _ThreadTile(
          thread: thread,
          typeName: '',
          favorited: _favoriteAids.contains(thread.aid),
          compact: true,
          onTap: () => _openThread(thread),
          onFavorite: () => _favoriteThread(thread),
        );
      },
    );
  }

  Future<IndicatorResult> _loadPage({
    required bool refresh,
    int? pageOverride,
  }) async {
    if (widget.authorId.isEmpty) {
      setState(() {
        _loading = false;
        _errorMessage = 'source_login_required'.tr;
      });
      return IndicatorResult.fail;
    }
    if (_loadingMore || (_loading && !refresh)) return IndicatorResult.noMore;

    final replacing = refresh || pageOverride != null;
    final nextPage = pageOverride ?? (refresh ? 1 : _page + 1);
    setState(() {
      if (replacing) {
        _loading = true;
        _errorMessage = null;
      } else {
        _loadingMore = true;
      }
    });

    final result = await YamiboApi.getUserThreadPage(
      uid: widget.authorId,
      page: nextPage,
    );
    if (!mounted) return IndicatorResult.fail;

    switch (result) {
      case Success():
        try {
          if (YamiboParser.isUnavailableDuringDailyBackup(result.data)) {
            setState(() {
              _loading = false;
              _loadingMore = false;
              _errorMessage = 'yamibo_backup_window'.tr;
            });
            return IndicatorResult.fail;
          }
          if (YamiboParser.isUserThreadPermissionPage(result.data)) {
            SourceAuthGuard.clearLogin(NovelSource.yamibo);
            SourceAuthGuard.showLoginRequired(NovelSource.yamibo);
            _showLoginRequired(refresh: replacing);
            return IndicatorResult.fail;
          }
          final data = YamiboParser.getUserThreadPageData(
            result.data,
            authorName: widget.authorName,
          );
          setState(() {
            if (replacing) _threads.clear();
            _threads.addAll(data.threads);
            _page = nextPage;
            _hasMore = data.hasMore && data.threads.isNotEmpty;
            _loading = false;
            _loadingMore = false;
            _errorMessage = null;
          });
          if (data.threads.isEmpty && nextPage > 1) {
            return IndicatorResult.noMore;
          }
          return IndicatorResult.success;
        } catch (e) {
          setState(() {
            _loading = false;
            _loadingMore = false;
            _errorMessage = e.toString();
          });
          return IndicatorResult.fail;
        }
      case Error():
        setState(() {
          _loading = false;
          _loadingMore = false;
          _errorMessage = result.error.toString();
        });
        return IndicatorResult.fail;
    }
  }

  Future<IndicatorResult> _refreshPage() => _loadPage(refresh: true);

  Future<IndicatorResult> _previousPage() {
    if (_page <= 1) return Future.value(IndicatorResult.noMore);
    return _loadPage(refresh: false, pageOverride: _page - 1);
  }

  Future<IndicatorResult> _nextPage() {
    if (!_hasMore) return Future.value(IndicatorResult.noMore);
    return _loadPage(refresh: false, pageOverride: _page + 1);
  }

  void _showLoginRequired({required bool refresh}) {
    setState(() {
      if (refresh) _threads.clear();
      _loading = false;
      _loadingMore = false;
      _errorMessage = 'source_login_required'.tr;
    });
  }

  void _handleScroll() {
    if (LocalStorageService.instance.getBrowsingEInkMode()) return;
    if (!_hasMore ||
        _loading ||
        _loadingMore ||
        !_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 360) {
      _loadPage(refresh: false);
    }
  }

  Future<void> _loadFavorites() async {
    final data = await DBService.instance
        .getBookshelfByClassId(BookshelfController.yamiboClassId)
        .first;
    if (!mounted) return;
    setState(() {
      _favoriteAids
        ..clear()
        ..addAll(data.map((item) => item.aid));
    });
  }

  void _openThread(YamiboForumThread thread) {
    AppSubRouter.toNovelDetail(aid: thread.aid);
  }

  Future<void> _favoriteThread(YamiboForumThread thread) async {
    await DBService.instance.upsertBookshelf(
      BookshelfEntityData(
        aid: thread.aid,
        bid: thread.aid,
        url: YamiboApi.threadUrl(thread.tid),
        title: thread.title,
        img: '',
        classId: BookshelfController.yamiboClassId,
        updateKey: thread.lastPostTime?.millisecondsSinceEpoch.toString() ?? '',
        updateTime: thread.lastPostTime,
        hasUpdate: false,
        rating: 0,
        remoteTagsJson: BookTags.encode([
          ...YamiboParser.yamiboTags(const []),
          ...YamiboParser.safeTitleTags(thread.title),
        ]),
        localTagsJson: BookTags.emptyJson,
      ),
    );
    SourceConfigService.instance.restoreLocalFavorite(
      NovelSource.yamibo,
      thread.aid,
    );
    await _loadFavorites();
    if (Get.isRegistered<BookshelfController>()) {
      await Get.find<BookshelfController>().loadFolders();
    }
    if (mounted) showSnackBar(message: 'favorited'.tr, context: context);
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({
    required this.thread,
    required this.typeName,
    required this.favorited,
    required this.onTap,
    required this.onFavorite,
    this.compact = false,
  });

  final YamiboForumThread thread;
  final String typeName;
  final bool favorited;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (compact) return _buildCompact(context, theme);

    return Card.outlined(
      margin: EdgeInsets.zero,
      elevation: 1.5,
      color: theme.colorScheme.surface.withValues(alpha: 0.84),
      shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.18),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kCardBorderRadius),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (thread.isTop)
                          _Badge(
                            label: 'TOP',
                            color: theme.colorScheme.primary,
                          ),
                        if (thread.isDigest)
                          _Badge(
                            label: 'DIGEST',
                            color: theme.colorScheme.tertiary,
                          ),
                        if (typeName.isNotEmpty)
                          _Badge(
                            label: typeName,
                            color: theme.colorScheme.secondary,
                          ),
                      ],
                    ),
                    if (thread.isTop || thread.isDigest || typeName.isNotEmpty)
                      const SizedBox(height: 6),
                    Text(
                      thread.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.32,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      [
                        if (thread.author.isNotEmpty) thread.author,
                        '${thread.replies} 回复',
                        '${thread.views} 浏览',
                        if (thread.lastPostTime != null)
                          _formatDate(thread.lastPostTime!),
                      ].join('  ·  '),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: favorited ? null : onFavorite,
                icon: Icon(favorited ? Icons.star : Icons.star_border),
                tooltip: 'favorite'.tr,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompact(BuildContext context, ThemeData theme) {
    final meta = [
      if (typeName.isNotEmpty) typeName,
      if (thread.author.isNotEmpty) thread.author,
      '${thread.replies} 回复',
      if (thread.lastPostTime != null) _formatDate(thread.lastPostTime!),
    ].join('  ·  ');

    return SizedBox(
      height: 77,
      child: Card.outlined(
        margin: EdgeInsets.zero,
        elevation: 1.5,
        color: theme.colorScheme.surface.withValues(alpha: 0.84),
        shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.18),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kCardBorderRadius),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 2, 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (thread.isTop || thread.isDigest)
                            Padding(
                              padding: const EdgeInsets.only(right: 6, top: 2),
                              child: _Badge(
                                label: thread.isTop ? 'TOP' : 'DIGEST',
                                color: thread.isTop
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.tertiary,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              thread.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                height: 1.24,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: favorited ? null : onFavorite,
                  icon: Icon(favorited ? Icons.star : Icons.star_border),
                  tooltip: 'favorite'.tr,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
