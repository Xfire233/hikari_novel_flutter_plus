import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/common/database/database.dart';
import 'package:hikari_novel_flutter/main.dart';
import 'package:hikari_novel_flutter/models/book_tags.dart';
import 'package:hikari_novel_flutter/models/resource.dart';
import 'package:hikari_novel_flutter/models/source_config.dart';
import 'package:hikari_novel_flutter/models/source_id.dart';
import 'package:hikari_novel_flutter/models/source_login_result.dart';
import 'package:hikari_novel_flutter/network/esj_api.dart';
import 'package:hikari_novel_flutter/network/esj_parser.dart';
import 'package:hikari_novel_flutter/network/request.dart';
import 'package:hikari_novel_flutter/pages/bookshelf/controller.dart';
import 'package:hikari_novel_flutter/router/app_sub_router.dart';
import 'package:hikari_novel_flutter/service/db_service.dart';
import 'package:hikari_novel_flutter/service/local_storage_service.dart';
import 'package:hikari_novel_flutter/service/source_config_service.dart';
import 'package:hikari_novel_flutter/service/source_favorite_adapter.dart';
import 'package:hikari_novel_flutter/widgets/state_page.dart';

class EsjzoneWebPage extends StatefulWidget {
  const EsjzoneWebPage({super.key, this.initialUrl, this.accountMode = false});

  final String? initialUrl;
  final bool accountMode;

  @override
  State<EsjzoneWebPage> createState() => _EsjzoneWebPageState();
}

class _EsjzoneWebPageState extends State<EsjzoneWebPage> {
  InAppWebViewController? _webViewController;
  final _cookieManager = CookieManager.instance();
  late String _currentUrl;
  String _title = 'ESJZone';
  double _progress = 0;
  bool _busy = false;
  String? _errorMessage;

  String? get _currentBookId => EsjApi.extractBookId(_currentUrl);

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl ?? EsjApi.baseUrl;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final loggedIn = await _syncCookie(silent: true);
        if (!context.mounted) return;
        Navigator.of(
          context,
        ).pop(SourceLoginResult(loggedIn: loggedIn, syncFavorites: false));
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_title),
          titleSpacing: 16,
          actions: widget.accountMode
              ? [
                  IconButton(
                    onPressed: _relogin,
                    icon: const Icon(Icons.login),
                    tooltip: 'source_relogin'.tr,
                  ),
                  IconButton(
                    onPressed: _confirmLoginAndClose,
                    icon: const Icon(Icons.verified_user_outlined),
                    tooltip: 'source_check_login_status'.tr,
                  ),
                  IconButton(
                    onPressed: _syncFavorites,
                    icon: const Icon(Icons.cloud_download_outlined),
                    tooltip: 'source_sync_online_favorites'.tr,
                  ),
                ]
              : [
                  IconButton(
                    onPressed: _webViewController?.reload,
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    onPressed: _confirmLoginAndClose,
                    icon: const Icon(Icons.login),
                    tooltip: 'esjzone_sync_login'.tr,
                  ),
                  IconButton(
                    onPressed: _openUrlDialog,
                    icon: const Icon(Icons.link),
                    tooltip: 'ESJZone URL',
                  ),
                  PopupMenuButton<_EsjAction>(
                    onSelected: _handleAction,
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: _EsjAction.reader,
                        enabled: _currentBookId != null,
                        child: Text('open_in_reader'.tr),
                      ),
                      PopupMenuItem(
                        value: _EsjAction.favorite,
                        enabled: _currentBookId != null,
                        child: Text('favorite'.tr),
                      ),
                      PopupMenuItem(
                        value: _EsjAction.syncFavorite,
                        child: Text('sync_esj_favorites'.tr),
                      ),
                    ],
                  ),
                ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                if (_progress > 0 && _progress < 1)
                  LinearProgressIndicator(value: _progress),
                Expanded(
                  child: SafeArea(
                    top: false,
                    child: InAppWebView(
                      webViewEnvironment: webViewEnvironment,
                      initialUrlRequest: URLRequest(url: WebUri('about:blank')),
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
                      onWebViewCreated: (controller) async {
                        _webViewController = controller;
                        if (widget.accountMode) {
                          await _syncStoredCookiesToWebView();
                        }
                        await controller.loadUrl(
                          urlRequest: URLRequest(
                            url: WebUri(widget.initialUrl ?? EsjApi.baseUrl),
                          ),
                        );
                      },
                      onTitleChanged: (_, title) {
                        if (!mounted) return;
                        setState(
                          () => _title = title?.trim().isNotEmpty == true
                              ? title!.trim()
                              : 'ESJZone',
                        );
                      },
                      onLoadStart: (_, url) {
                        if (url?.scheme == 'about') return;
                        if (!mounted) return;
                        setState(() {
                          _errorMessage = null;
                          _currentUrl = url?.toString() ?? _currentUrl;
                        });
                      },
                      onLoadStop: (_, url) async {
                        if (url?.scheme == 'about') return;
                        if (!mounted) return;
                        setState(
                          () => _currentUrl = url?.toString() ?? _currentUrl,
                        );
                        await _syncCookie(silent: true);
                      },
                      onProgressChanged: (_, progress) {
                        if (!mounted) return;
                        setState(() => _progress = progress / 100);
                      },
                      onReceivedError: (_, request, error) {
                        if (!mounted || request.isForMainFrame != true) return;
                        setState(
                          () => _errorMessage =
                              '${error.type}: ${error.description}',
                        );
                      },
                      onReceivedHttpError: (_, request, response) {
                        if (!mounted || request.isForMainFrame != true) return;
                        setState(
                          () => _errorMessage =
                              '${response.statusCode}: ${response.reasonPhrase}',
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            if (_errorMessage != null)
              ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: ErrorMessage(
                  msg: _errorMessage!,
                  action: _webViewController?.reload,
                ),
              ),
            Offstage(offstage: !_busy, child: const LoadingPage()),
          ],
        ),
        floatingActionButton: widget.accountMode || _currentBookId == null
            ? null
            : FloatingActionButton.extended(
                onPressed: _openCurrentBookInReader,
                icon: const Icon(Icons.chrome_reader_mode_outlined),
                label: Text('open_in_reader'.tr),
              ),
      ),
    );
  }

  Future<void> _handleAction(_EsjAction action) async {
    switch (action) {
      case _EsjAction.reader:
        await _openCurrentBookInReader();
      case _EsjAction.favorite:
        await _favoriteCurrentBook();
      case _EsjAction.syncFavorite:
        await _syncFavorites();
    }
  }

  Future<void> _confirmLoginAndClose() async {
    final loggedIn = await _syncCookie();
    if (!mounted || !loggedIn) return;
    Navigator.of(context).pop(
      SourceLoginResult(loggedIn: true, syncFavorites: !widget.accountMode),
    );
  }

  Future<void> _relogin() async {
    await _cookieManager.deleteCookies(url: WebUri(EsjApi.baseUrl));
    LocalStorageService.instance.setEsjCookie(null);
    const loginUrl = EsjApi.baseUrl;
    if (mounted) {
      setState(() {
        _currentUrl = loginUrl;
        _errorMessage = null;
        _progress = 0;
      });
    }
    await _webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(loginUrl)),
    );
  }

  Future<void> _openUrlDialog() async {
    final controller = TextEditingController(text: _currentUrl);
    final url = await Get.dialog<String>(
      AlertDialog(
        title: const Text('ESJZone URL'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(onPressed: Get.back, child: Text('cancel'.tr)),
          TextButton(
            onPressed: () => Get.back(result: controller.text.trim()),
            child: Text('confirm'.tr),
          ),
        ],
      ),
    );
    controller.dispose();
    if (url == null || url.isEmpty) return;
    final bookId = EsjApi.extractBookId(url);
    final target = bookId == null ? url : EsjApi.detailUrl(bookId);
    await _webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(target)),
    );
  }

  Future<bool> _syncCookie({
    bool silent = false,
    bool syncFavorites = false,
  }) async {
    final cookies = await _cookieManager.getCookies(
      url: WebUri(EsjApi.baseUrl),
    );
    final cookie = cookies
        .where((c) => c.name.isNotEmpty)
        .map((c) => '${c.name}=${c.value}')
        .join('; ');
    if (cookie.isEmpty) {
      if (!silent) {
        LocalStorageService.instance.setEsjCookie(null);
      }
      if (!silent && mounted) {
        showSnackBar(message: 'source_login_required'.tr, context: context);
      }
      return false;
    }
    final loggedIn = EsjApi.isAuthenticatedCookie(cookie);
    if (loggedIn) {
      LocalStorageService.instance.setEsjCookie(cookie);
      SourceConfigService.instance.setSourceEnabled(NovelSource.esj, true);
    } else {
      if (!silent || LocalStorageService.instance.getEsjCookie() != null) {
        LocalStorageService.instance.setEsjCookie(null);
      }
    }
    if (!silent && mounted) {
      if (!loggedIn) {
        showSnackBar(message: 'source_login_required'.tr, context: context);
        return false;
      }
      if (!syncFavorites) {
        showSnackBar(message: 'esjzone_login_synced'.tr, context: context);
        return true;
      }
      setState(() => _busy = true);
      final synced = await BookshelfController.syncEsjFavoritesToBookshelf();
      if (!mounted) return false;
      setState(() => _busy = false);
      if (Get.isRegistered<BookshelfController>()) {
        await Get.find<BookshelfController>().loadFolders();
      }
      if (!mounted) return false;
      showSnackBar(
        message: synced ? 'update_successfully'.tr : 'update_failed'.tr,
        context: context,
      );
    }
    return loggedIn;
  }

  Future<void> _syncStoredCookiesToWebView() async {
    final stored = LocalStorageService.instance.getEsjCookie();
    if (stored == null || stored.trim().isEmpty) return;
    for (final entry in _parseCookieHeader(stored).entries) {
      await _cookieManager.setCookie(
        url: WebUri(EsjApi.baseUrl),
        name: entry.key,
        value: entry.value,
        path: '/',
        isSecure: true,
      );
    }
  }

  Map<String, String> _parseCookieHeader(String value) {
    final result = <String, String>{};
    for (final part in value.split(';')) {
      final index = part.indexOf('=');
      if (index <= 0) continue;
      final key = part.substring(0, index).trim();
      final cookieValue = part.substring(index + 1).trim();
      if (key.isNotEmpty && cookieValue.isNotEmpty) result[key] = cookieValue;
    }
    return result;
  }

  Future<void> _openCurrentBookInReader() async {
    final bookId = _currentBookId;
    if (bookId == null) return;
    await _syncCookie(silent: true);
    AppSubRouter.toNovelDetail(aid: SourceId.esjAid(bookId));
  }

  Future<void> _favoriteCurrentBook() async {
    final bookId = _currentBookId;
    if (bookId == null) return;
    await _syncCookie(silent: true);
    setState(() => _busy = true);
    final result = await EsjApi.getNovelDetail(id: bookId);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Success():
        final aid = SourceId.esjAid(bookId);
        final detail = EsjParser.getNovelDetail(result.data, aid);
        if (SourceFavoriteAdapter.shouldPushRemote(NovelSource.esj)) {
          final pushed = await SourceFavoriteAdapter.addRemoteFavorite(
            source: NovelSource.esj,
            aid: aid,
          );
          if (!pushed) {
            if (mounted) {
              showErrorDialog('update_failed'.tr, [
                TextButton(onPressed: Get.back, child: Text('confirm'.tr)),
              ]);
            }
            return;
          }
        }
        await DBService.instance.upsertBookshelf(
          BookshelfEntityData(
            aid: aid,
            bid: aid,
            url: EsjApi.detailUrl(bookId),
            title: detail.title,
            img: detail.imgUrl,
            classId: BookshelfController.esjClassId,
            updateKey: EsjParser.latestChapterCid(detail) ?? '',
            updateTime: null,
            hasUpdate: false,
            rating: 0,
            remoteTagsJson: BookTags.encode(detail.tags),
            localTagsJson: BookTags.emptyJson,
          ),
        );
        SourceConfigService.instance.restoreLocalFavorite(NovelSource.esj, aid);
        if (mounted) showSnackBar(message: 'favorited'.tr, context: context);
      case Error():
        if (mounted) {
          showErrorDialog(result.error.toString(), [
            TextButton(onPressed: Get.back, child: Text('confirm'.tr)),
          ]);
        }
    }
  }

  Future<void> _syncFavorites() async {
    final loggedIn = await _syncCookie(silent: true);
    if (!loggedIn) {
      showErrorDialog('source_login_required'.tr, [
        TextButton(onPressed: Get.back, child: Text('confirm'.tr)),
      ]);
      return;
    }
    setState(() => _busy = true);
    final result = await BookshelfController.syncEsjFavoritesToBookshelf();
    if (!mounted) return;
    setState(() => _busy = false);
    if (result) {
      showSnackBar(message: 'update_successfully'.tr, context: context);
    } else {
      showErrorDialog('update_failed'.tr, [
        TextButton(onPressed: Get.back, child: Text('confirm'.tr)),
      ]);
    }
  }
}

enum _EsjAction { reader, favorite, syncFavorite }
