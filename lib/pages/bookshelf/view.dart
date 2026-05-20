import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/pages/bookshelf/controller.dart';
import 'package:hikari_novel_flutter/pages/bookshelf/widgets/bookshelf_content_view.dart';
import 'package:hikari_novel_flutter/pages/bookshelf/widgets/bookshelf_search_view.dart';
import 'package:responsive_grid_list/responsive_grid_list.dart';

import '../../common/common_widgets.dart';
import '../../common/constants.dart';
import '../../common/extension.dart';
import '../../models/bookshelf.dart';
import '../../models/page_state.dart';
import '../../models/smart_shelf.dart';
import '../../models/source_config.dart';
import '../../network/request.dart';
import '../../widgets/custom_tile.dart';
import '../../widgets/source_backdrop.dart';
import '../../widgets/state_page.dart';

class BookshelfPage extends StatelessWidget {
  final controller = Get.put(BookshelfController());
  final searchTextEditController = Get.put(
    TextEditingController(),
    tag: "searchTextEditController",
  );

  BookshelfContentController get currentTabController =>
      Get.find<BookshelfContentController>(
        tag: "BookshelfContentController ${controller.currentClassId}",
      );

  BookshelfPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: _pageTransition,
        child: controller.pageState.value == PageState.bookshelfSearch
            ? KeyedSubtree(
                key: const ValueKey('bookshelf-search'),
                child: BookshelfSearchView(),
              )
            : KeyedSubtree(
                key: const ValueKey('bookshelf-content'),
                child: _buildBookshelfContent(context),
              ),
      ),
    );
  }

  Widget _buildBookshelfContent(BuildContext context) {
    return Obx(
      () => AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: _folderTransition,
        child: Scaffold(
          key: ValueKey('bookshelf-${controller.currentClassId}'),
          appBar: _buildAppBar(context),
          body: controller.isInFolder
              ? _buildOpenFolderBody(context)
              : _buildFolderList(context),
          floatingActionButton: _buildFab(context),
          bottomNavigationBar: _buildBottomBar(context),
        ),
      ),
    );
  }

  Widget _pageTransition(Widget child, Animation<double> animation) {
    final slide = Tween<Offset>(
      begin: const Offset(0.04, 0),
      end: Offset.zero,
    ).animate(animation);
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(position: slide, child: child),
    );
  }

  Widget _folderTransition(Widget child, Animation<double> animation) {
    final slide = Tween<Offset>(
      begin: const Offset(0.08, 0),
      end: Offset.zero,
    ).animate(animation);
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(position: slide, child: child),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    if (controller.isSelectionMode.value) {
      return AppBar(
        automaticallyImplyLeading: false,
        leading: CloseButton(onPressed: currentTabController.exitSelectionMode),
        title: Obx(
          () => Text(currentTabController.selectedCount.value.toString()),
        ),
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        titleSpacing: 16,
        actions: [
          IconButton(
            onPressed: currentTabController.selectAll,
            icon: const Icon(Icons.select_all),
            tooltip: "select_all".tr,
          ),
          PopupMenuButton<_SelectionAction>(
            onSelected: _handleSelectionAction,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _SelectionAction.moveToNewFolder,
                child: ListTile(
                  leading: const Icon(Icons.create_new_folder_outlined),
                  title: Text("move_to_new_folder".tr),
                ),
              ),
              PopupMenuItem(
                value: _SelectionAction.moveToExistingFolder,
                child: ListTile(
                  leading: const Icon(Icons.drive_file_move_outline),
                  title: Text("move_to_existing_folder".tr),
                ),
              ),
              PopupMenuItem(
                value: _SelectionAction.deselect,
                child: ListTile(
                  leading: const Icon(Icons.deselect),
                  title: Text("deselect".tr),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (controller.isInFolder) {
      final folder = controller.currentFolder.value!;
      return AppBar(
        leading: BackButton(onPressed: controller.closeFolder),
        title: Text(folder.name),
        titleSpacing: 16,
        actions: [
          IconButton(
            onPressed: () =>
                controller.pageState.value = PageState.bookshelfSearch,
            icon: const Icon(Icons.search),
            tooltip: "search".tr,
          ),
          IconButton(
            onPressed: _syncBookshelf,
            icon: const Icon(Icons.sync),
            tooltip: "sync_bookshelf".tr,
          ),
          PopupMenuButton<_FolderAction>(
            onSelected: (value) => _handleFolderAction(value, folder),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _FolderAction.toggleView,
                child: Obx(
                  () => ListTile(
                    leading: Icon(
                      controller.useListView.value
                          ? Icons.grid_view_outlined
                          : Icons.view_list_outlined,
                    ),
                    title: Text(
                      controller.useListView.value
                          ? "grid_view".tr
                          : "list_view".tr,
                    ),
                  ),
                ),
              ),
              PopupMenuItem(
                value: _FolderAction.sort,
                child: ListTile(
                  leading: const Icon(Icons.sort_outlined),
                  title: Text(
                    _sortTypeText(controller.sortTypeForClassId(folder.id)),
                  ),
                ),
              ),
              PopupMenuItem(
                value: _FolderAction.batchManage,
                child: ListTile(
                  leading: const Icon(Icons.checklist_outlined),
                  title: Text("batch_manage".tr),
                ),
              ),
              if (!folder.smartFolder)
                PopupMenuItem(
                  value: _FolderAction.createChild,
                  child: ListTile(
                    leading: const Icon(Icons.create_new_folder_outlined),
                    title: Text("new_child_bookshelf".tr),
                  ),
                ),
              if (!folder.builtIn)
                if (folder.smartFolder)
                  PopupMenuItem(
                    value: _FolderAction.editSmart,
                    child: ListTile(
                      leading: const Icon(Icons.tune_outlined),
                      title: Text("编辑筛选条件"),
                    ),
                  ),
              if (!folder.builtIn)
                PopupMenuItem(
                  value: _FolderAction.rename,
                  child: ListTile(
                    leading: const Icon(Icons.drive_file_rename_outline),
                    title: Text("rename_bookshelf".tr),
                  ),
                ),
              if (!folder.builtIn)
                PopupMenuItem(
                  value: _FolderAction.delete,
                  child: ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: Text("delete_bookshelf".tr),
                  ),
                ),
            ],
          ),
        ],
      );
    }

    return AppBar(
      title: Text("bookshelf".tr),
      titleSpacing: 16,
      actions: [
        Obx(
          () => IconButton(
            onPressed: controller.toggleFolderHomeViewMode,
            icon: Icon(
              controller.useFolderListView.value
                  ? Icons.grid_view_outlined
                  : Icons.view_list_outlined,
            ),
            tooltip: controller.useFolderListView.value
                ? "grid_view".tr
                : "list_view".tr,
          ),
        ),
        IconButton(
          onPressed: _syncBookshelf,
          icon: const Icon(Icons.sync),
          tooltip: "sync_bookshelf".tr,
        ),
        IconButton(
          onPressed: () =>
              controller.pageState.value = PageState.bookshelfSearch,
          icon: const Icon(Icons.search),
          tooltip: "search".tr,
        ),
      ],
    );
  }

  Widget _buildFolderList(BuildContext context) {
    return Obx(() {
      final folders = controller.rootFolders;
      if (folders.isEmpty) return const LoadingPage();
      if (!controller.useFolderListView.value) {
        return _buildFolderGrid(context, folders);
      }
      return ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: folders.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final folder = folders[index];
          return ListTile(
            leading: _folderLeading(folder),
            title: Row(
              children: [
                Expanded(child: Text(folder.name)),
                if (folder.hasUpdate || folder.hasNew)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      folder.hasNew ? "new_content".tr : "updated".tr,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Text(_folderSubtitle(folder)),
            trailing: PopupMenuButton<_FolderAction>(
              onSelected: (value) => _handleFolderAction(value, folder),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: _FolderAction.cover,
                  child: ListTile(
                    leading: const Icon(Icons.image_outlined),
                    title: Text("bookshelf_cover".tr),
                  ),
                ),
                PopupMenuItem(
                  value: _FolderAction.sort,
                  child: ListTile(
                    leading: const Icon(Icons.sort_outlined),
                    title: Text(
                      _sortTypeText(controller.sortTypeForClassId(folder.id)),
                    ),
                  ),
                ),
                if (!folder.builtIn)
                  if (folder.smartFolder)
                    PopupMenuItem(
                      value: _FolderAction.editSmart,
                      child: ListTile(
                        leading: const Icon(Icons.tune_outlined),
                        title: Text("编辑筛选条件"),
                      ),
                    ),
                if (!folder.builtIn)
                  PopupMenuItem(
                    value: _FolderAction.rename,
                    child: ListTile(
                      leading: const Icon(Icons.drive_file_rename_outline),
                      title: Text("rename_bookshelf".tr),
                    ),
                  ),
                if (!folder.builtIn && !folder.smartFolder)
                  PopupMenuItem(
                    value: _FolderAction.createChild,
                    child: ListTile(
                      leading: const Icon(Icons.create_new_folder_outlined),
                      title: Text("new_child_bookshelf".tr),
                    ),
                  ),
                if (!folder.builtIn)
                  PopupMenuItem(
                    value: _FolderAction.delete,
                    child: ListTile(
                      leading: const Icon(Icons.delete_outline),
                      title: Text("delete_bookshelf".tr),
                    ),
                  ),
              ],
            ),
            onTap: () => controller.openFolder(folder),
          );
        },
      );
    });
  }

  Widget _buildFolderGrid(BuildContext context, List<BookshelfFolder> folders) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        kPageHorizontalPadding,
        10,
        kPageHorizontalPadding,
        10,
      ),
      child: ResponsiveGridList(
        minItemWidth: 148,
        horizontalGridSpacing: 8,
        verticalGridSpacing: 8,
        children: folders.map((folder) {
          return _FolderGridCard(
            folder: folder,
            leading: _folderLeading(folder),
            subtitle: _folderSubtitle(folder),
            onTap: () => controller.openFolder(folder),
            onAction: (action) => _handleFolderAction(action, folder),
          );
        }).toList(),
      ),
    );
  }

  Widget? _buildFab(BuildContext context) {
    if (controller.isSelectionMode.value) {
      return FloatingActionButton.extended(
        onPressed: _showMoveSelectionSheet,
        icon: const Icon(Icons.drive_file_move_outline),
        label: Text("move_books".tr),
      );
    }
    if (controller.isInFolder) {
      return FloatingActionButton(
        onPressed: currentTabController.enterSelectionMode,
        tooltip: "batch_manage".tr,
        child: const Icon(Icons.checklist_outlined),
      );
    }
    return FloatingActionButton.extended(
      onPressed: _showAddFolderSheet,
      icon: const Icon(Icons.add),
      label: Text("add_bookshelf".tr),
    );
  }

  Widget? _buildBottomBar(BuildContext context) {
    if (controller.isSelectionMode.value && context.isLargeScreen()) {
      return CommonWidgets.bookshelfBottomActionBar(
        currentTabController,
        controller,
      );
    }
    return null;
  }

  Future<void> _syncBookshelf() async {
    showSnackBar(message: "refresh_bookshelf_tip".tr, context: Get.context!);
    final string = await controller.refreshBookshelf();
    showSnackBar(message: string, context: Get.context!);
  }

  void _handleFolderAction(_FolderAction action, BookshelfFolder folder) {
    switch (action) {
      case _FolderAction.toggleView:
        controller.toggleCurrentViewMode();
      case _FolderAction.sort:
        _showFolderSortDialog(folder);
      case _FolderAction.cover:
        _showFolderCoverSheet(folder);
      case _FolderAction.batchManage:
        currentTabController.enterSelectionMode();
      case _FolderAction.editSmart:
        _showSmartShelfDialog(folder: folder);
      case _FolderAction.rename:
        _showRenameFolderDialog(folder);
      case _FolderAction.delete:
        _showDeleteFolderDialog(folder);
      case _FolderAction.createChild:
        _showCreateChildFolderDialog(folder);
    }
  }

  Future<void> _showFolderCoverSheet(BookshelfFolder folder) async {
    await Get.bottomSheet(
      SafeArea(
        child: Material(
          color: Theme.of(Get.context!).colorScheme.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text("bookshelf_cover_from_book".tr),
                onTap: () {
                  Get.back();
                  _showFolderBookCoverDialog(folder);
                },
              ),
              ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: Text("bookshelf_cover_upload".tr),
                onTap: () async {
                  Get.back();
                  final ok = await controller.setFolderCoverFromUploadedFile(
                    folder,
                  );
                  if (!ok) {
                    showSnackBar(
                      message: "bookshelf_cover_upload_failed".tr,
                      context: Get.context!,
                    );
                  }
                },
              ),
              if (folder.cover != null)
                ListTile(
                  leading: const Icon(Icons.restart_alt_outlined),
                  title: Text("bookshelf_cover_reset".tr),
                  onTap: () {
                    Get.back();
                    controller.resetFolderCover(folder);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showFolderBookCoverDialog(BookshelfFolder folder) async {
    final items = await controller.getFolderCoverCandidates(folder);
    if (items.isEmpty) {
      showSnackBar(
        message: "bookshelf_cover_no_book_cover".tr,
        context: Get.context!,
      );
      return;
    }
    await Get.dialog<void>(
      AlertDialog(
        title: Text("bookshelf_cover_from_book".tr),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 120,
              childAspectRatio: 0.68,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return InkWell(
                borderRadius: BorderRadius.circular(kCardBorderRadius),
                onTap: () {
                  controller.setFolderCoverFromBook(folder, item);
                  Get.back();
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(kCardBorderRadius),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: item.img,
                        httpHeaders: Request.userAgent,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.58),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(5),
                            child: Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _handleSelectionAction(_SelectionAction action) {
    switch (action) {
      case _SelectionAction.moveToNewFolder:
        _showCreateFolderFromSelectionDialog();
      case _SelectionAction.moveToExistingFolder:
        _showMoveSelectionToExistingFolderDialog();
      case _SelectionAction.deselect:
        currentTabController.deselect();
    }
  }

  Future<void> _showFolderSortDialog(BookshelfFolder folder) async {
    final value = await Get.dialog<BookshelfSortType>(
      RadioListDialog<BookshelfSortType>(
        value: controller.sortTypeForClassId(folder.id),
        values: [
          (BookshelfSortType.added, "bookshelf_sort_added".tr),
          (BookshelfSortType.update, "bookshelf_sort_update".tr),
          (BookshelfSortType.title, "bookshelf_sort_title".tr),
          (BookshelfSortType.recentRead, "bookshelf_sort_recent".tr),
        ],
        title: "bookshelf_sort_type".tr,
      ),
    );
    if (value == null) return;
    controller.setSortTypeForClassId(folder.id, value);
  }

  String _sortTypeText(BookshelfSortType type) => switch (type) {
    BookshelfSortType.update => "bookshelf_sort_update".tr,
    BookshelfSortType.title => "bookshelf_sort_title".tr,
    BookshelfSortType.added => "bookshelf_sort_added".tr,
    BookshelfSortType.recentRead => "bookshelf_sort_recent".tr,
  };

  Widget _folderLeading(BookshelfFolder folder) {
    final source = switch (folder.id) {
      BookshelfController.defaultClassId => NovelSource.wenku8,
      BookshelfController.yamiboClassId => NovelSource.yamibo,
      BookshelfController.esjClassId => NovelSource.esj,
      _ => null,
    };
    if (source != null) return SourceMark(source: source);
    return Icon(_folderIcon(folder));
  }

  IconData _folderIcon(BookshelfFolder folder) {
    if (folder.id == BookshelfController.recentSmartId) {
      return Icons.history_outlined;
    }
    if (folder.smartFolder) return Icons.auto_awesome_outlined;
    return Icons.folder_outlined;
  }

  Future<void> _showAddFolderSheet() async {
    await Get.bottomSheet(
      SafeArea(
        child: Material(
          color: Theme.of(Get.context!).colorScheme.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.create_new_folder_outlined),
                title: Text("new_bookshelf".tr),
                subtitle: Text("normal_bookshelf_desc".tr),
                onTap: () {
                  Get.back();
                  _showCreateFolderDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome_outlined),
                title: Text("smart_bookshelf".tr),
                subtitle: Text("advanced_smart_bookshelf_desc".tr),
                onTap: () {
                  Get.back();
                  _showSmartShelfDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMoveSelectionSheet() async {
    await Get.bottomSheet(
      SafeArea(
        child: Material(
          color: Theme.of(Get.context!).colorScheme.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.create_new_folder_outlined),
                title: Text("move_to_new_folder".tr),
                onTap: () {
                  Get.back();
                  _showCreateFolderFromSelectionDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.drive_file_move_outline),
                title: Text("move_to_existing_folder".tr),
                onTap: () {
                  Get.back();
                  _showMoveSelectionToExistingFolderDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateFolderDialog() async {
    final name = await _askFolderName("new_bookshelf".tr);
    if (name == null) return;
    await controller.createFolder(name);
  }

  Future<void> _showCreateChildFolderDialog(BookshelfFolder parent) async {
    final name = await _askFolderName("new_child_bookshelf".tr);
    if (name == null) return;
    final folder = await controller.createFolder(name, parentId: parent.id);
    if (folder != null) controller.openFolder(folder);
  }

  Future<void> _showSmartShelfDialog({BookshelfFolder? folder}) async {
    final editing = folder != null;
    final config = editing
        ? controller.smartConfigForFolder(folder)
        : const SmartShelfConfig();
    final group = config.groups.isEmpty
        ? const SmartShelfConditionGroup()
        : config.groups.first;
    final nameController = TextEditingController(
      text: editing ? folder.name.replaceFirst(RegExp(r'\s*\(\d+\)$'), '') : '',
    );
    final tagsController = TextEditingController(
      text: group.conditions
          .where((item) => item.type == SmartShelfConditionType.tag)
          .map((item) => item.value)
          .join(', '),
    );
    final authorController = TextEditingController(
      text:
          group.conditions
              .firstWhereOrNull(
                (item) => item.type == SmartShelfConditionType.author,
              )
              ?.value ??
          '',
    );
    final titleController = TextEditingController(
      text:
          group.conditions
              .firstWhereOrNull(
                (item) => item.type == SmartShelfConditionType.title,
              )
              ?.value ??
          '',
    );
    var matchAll = group.mode != SmartShelfMatchMode.any;
    var subscription = config.isSubscription;
    final sources = <NovelSource>{
      ...(config.sources.isEmpty ? NovelSource.values : config.sources),
    };
    await Get.dialog<void>(
      StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(editing ? "编辑智能书架" : "smart_bookshelf".tr),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "标签支持用中文逗号、英文逗号或空格分隔。开启“全部匹配”时需要同时满足所有条件；关闭后任意条件命中即可。订阅模式会在书架同步时按标签从已选来源拉取新条目。",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: "bookshelf_name".tr),
                ),
                TextField(
                  controller: tagsController,
                  decoration: InputDecoration(labelText: "tag_name".tr),
                ),
                TextField(
                  controller: authorController,
                  decoration: InputDecoration(labelText: "author".tr),
                ),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(labelText: "title".tr),
                ),
                SwitchListTile(
                  value: matchAll,
                  onChanged: (value) => setState(() => matchAll = value),
                  title: Text("smart_match_all".tr),
                  dense: true,
                ),
                SwitchListTile(
                  value: subscription,
                  onChanged: (value) => setState(() => subscription = value),
                  title: Text("smart_subscription_mode".tr),
                  dense: true,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 6),
                  child: Text(
                    "来源范围",
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: NovelSource.values
                      .map(
                        (source) => FilterChip(
                          label: Text(source.titleKey.tr),
                          selected: sources.contains(source),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                sources.add(source);
                              } else {
                                sources.remove(source);
                              }
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: Get.back, child: Text("cancel".tr)),
            TextButton(
              onPressed: () async {
                final tags = tagsController.text
                    .split(RegExp(r'[,，\s]+'))
                    .where((item) => item.trim().isNotEmpty)
                    .toList();
                final conditions = <SmartShelfCondition>[
                  for (final tag in tags)
                    SmartShelfCondition(
                      type: SmartShelfConditionType.tag,
                      value: tag,
                    ),
                  if (authorController.text.trim().isNotEmpty)
                    SmartShelfCondition(
                      type: SmartShelfConditionType.author,
                      value: authorController.text.trim(),
                    ),
                  if (titleController.text.trim().isNotEmpty)
                    SmartShelfCondition(
                      type: SmartShelfConditionType.title,
                      value: titleController.text.trim(),
                    ),
                ];
                final nextConfig = SmartShelfConfig(
                  kind: subscription
                      ? SmartShelfKind.subscription
                      : SmartShelfKind.local,
                  mode: SmartShelfMatchMode.all,
                  groups: [
                    SmartShelfConditionGroup(
                      mode: matchAll
                          ? SmartShelfMatchMode.all
                          : SmartShelfMatchMode.any,
                      conditions: conditions,
                    ),
                  ],
                  sources: sources.toList(),
                  subscriptionTags: tags,
                );
                final name = nameController.text.trim().isEmpty
                    ? "smart_bookshelf".tr
                    : nameController.text.trim();
                if (editing) {
                  await controller.updateSmartShelf(
                    folder: folder,
                    name: name,
                    config: nextConfig,
                  );
                } else {
                  await controller.createSmartShelf(
                    name: name,
                    config: nextConfig,
                  );
                }
                Get.back();
              },
              child: Text("confirm".tr),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateFolderFromSelectionDialog() async {
    final name = await _askFolderName("move_to_new_folder".tr);
    if (name == null) return;
    final selectedAids = currentTabController.getSelectedAids();
    final folder = await controller.createFolder(
      name,
      aids: selectedAids,
      parentId: controller.currentNormalFolderId,
    );
    if (folder == null) return;
    currentTabController.exitSelectionMode();
    controller.openFolder(folder);
  }

  Future<void> _showMoveSelectionToExistingFolderDialog() async {
    final target = await _selectTargetFolder(
      excludedFolderId: controller.currentClassId,
    );
    if (target == null) return;
    await controller.moveBooksToFolder(
      currentTabController.getSelectedAids(),
      target.id,
    );
    currentTabController.exitSelectionMode();
    controller.openFolder(target);
  }

  Future<void> _showDeleteFolderDialog(BookshelfFolder folder) async {
    if (folder.smartFolder) {
      final delete = await Get.dialog<bool>(
        AlertDialog(
          title: Text("delete_bookshelf".tr),
          content: Text("delete_smart_bookshelf_confirm".tr),
          actions: [
            TextButton(onPressed: Get.back, child: Text("cancel".tr)),
            TextButton(
              onPressed: () => Get.back(result: true),
              child: Text("delete_bookshelf".tr),
            ),
          ],
        ),
      );
      if (delete != true) return;
      await controller.deleteFolder(folder);
      if (controller.currentFolder.value?.id == folder.id) {
        controller.closeFolder();
      }
      return;
    }

    final action = await Get.dialog<_DeleteFolderAction>(
      AlertDialog(
        title: Text("delete_bookshelf".tr),
        content: Text("delete_bookshelf_confirm".tr),
        actions: [
          TextButton(onPressed: Get.back, child: Text("cancel".tr)),
          TextButton(
            onPressed: () => Get.back(result: _DeleteFolderAction.deleteBooks),
            child: Text("delete_books".tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: _DeleteFolderAction.migrate),
            child: Text("migrate_books".tr),
          ),
        ],
      ),
    );
    if (action == null) return;

    String? migrateToClassId;
    if (action == _DeleteFolderAction.migrate) {
      final target = await _selectTargetFolder(excludedFolderId: folder.id);
      if (target == null) return;
      migrateToClassId = target.id;
    }

    await controller.deleteFolder(folder, migrateToClassId: migrateToClassId);
    if (controller.currentFolder.value?.id == folder.id) {
      controller.closeFolder();
    }
  }

  Future<BookshelfFolder?> _selectTargetFolder({
    String? excludedFolderId,
  }) async {
    final folders = controller.getMoveTargetFolders(
      excludedFolderId: excludedFolderId,
    );
    if (folders.isEmpty) {
      showSnackBar(message: "no_migration_target".tr, context: Get.context!);
      return null;
    }
    return Get.dialog<BookshelfFolder>(
      AlertDialog(
        title: Text("select_migration_target".tr),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: folders.length,
            itemBuilder: (context, index) {
              final folder = folders[index];
              return ListTile(
                leading: _folderLeading(folder),
                title: Text(controller.folderDisplayName(folder)),
                subtitle: Text(
                  "bookshelf_item_count".trParams({"count": "${folder.count}"}),
                ),
                onTap: () => Get.back(result: folder),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showRenameFolderDialog(BookshelfFolder folder) async {
    final name = await _askFolderName(
      "rename_bookshelf".tr,
      initial: folder.name,
    );
    if (name == null) return;
    await controller.renameFolder(folder, name);
  }

  Future<String?> _askFolderName(
    String title, {
    String initial = '',
    String? label,
  }) async {
    final textController = TextEditingController(text: initial);
    return Get.dialog<String>(
      AlertDialog(
        title: Text(title),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: InputDecoration(labelText: label ?? "bookshelf_name".tr),
          onSubmitted: (value) => Get.back(result: value),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: Text("cancel".tr)),
          TextButton(
            onPressed: () => Get.back(result: textController.text),
            child: Text("confirm".tr),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenFolderBody(BuildContext context) {
    final folder = controller.currentFolder.value!;
    final content = BookshelfContentView(
      classId: controller.currentClassId,
      isSmartFolder: folder.smartFolder,
      smartFolderAids: folder.smartFolderAids,
    );
    if (folder.smartFolder) return content;
    return Column(
      children: [
        Obx(() {
          final children = controller.currentChildFolders;
          if (children.isEmpty) return const SizedBox.shrink();
          return Material(
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: children
                  .map(
                    (child) => ListTile(
                      leading: _folderLeading(child),
                      title: Text(child.name),
                      subtitle: Text(_folderSubtitle(child)),
                      trailing: PopupMenuButton<_FolderAction>(
                        onSelected: (value) =>
                            _handleFolderAction(value, child),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: _FolderAction.cover,
                            child: ListTile(
                              leading: const Icon(Icons.image_outlined),
                              title: Text("bookshelf_cover".tr),
                            ),
                          ),
                          PopupMenuItem(
                            value: _FolderAction.sort,
                            child: ListTile(
                              leading: const Icon(Icons.sort_outlined),
                              title: Text(
                                _sortTypeText(
                                  controller.sortTypeForClassId(child.id),
                                ),
                              ),
                            ),
                          ),
                          if (!child.builtIn && child.smartFolder)
                            PopupMenuItem(
                              value: _FolderAction.editSmart,
                              child: ListTile(
                                leading: const Icon(Icons.tune_outlined),
                                title: Text("编辑筛选条件"),
                              ),
                            ),
                          PopupMenuItem(
                            value: _FolderAction.rename,
                            child: ListTile(
                              leading: const Icon(
                                Icons.drive_file_rename_outline,
                              ),
                              title: Text("rename_bookshelf".tr),
                            ),
                          ),
                          PopupMenuItem(
                            value: _FolderAction.createChild,
                            child: ListTile(
                              leading: const Icon(
                                Icons.create_new_folder_outlined,
                              ),
                              title: Text("new_child_bookshelf".tr),
                            ),
                          ),
                          PopupMenuItem(
                            value: _FolderAction.delete,
                            child: ListTile(
                              leading: const Icon(Icons.delete_outline),
                              title: Text("delete_bookshelf".tr),
                            ),
                          ),
                        ],
                      ),
                      onTap: () => controller.openFolder(child),
                    ),
                  )
                  .toList(),
            ),
          );
        }),
        Expanded(child: content),
      ],
    );
  }

  String _folderSubtitle(BookshelfFolder folder) {
    final books = "bookshelf_item_count".trParams({"count": "${folder.count}"});
    if (folder.childCount <= 0) return books;
    final children = "child_bookshelf_count".trParams({
      "count": "${folder.childCount}",
    });
    return "$books · $children";
  }
}

enum _FolderAction {
  toggleView,
  sort,
  cover,
  batchManage,
  editSmart,
  rename,
  delete,
  createChild,
}

enum _SelectionAction { moveToNewFolder, moveToExistingFolder, deselect }

enum _DeleteFolderAction { deleteBooks, migrate }

class _FolderGridCard extends StatelessWidget {
  const _FolderGridCard({
    required this.folder,
    required this.leading,
    required this.subtitle,
    required this.onTap,
    required this.onAction,
  });

  final BookshelfFolder folder;
  final Widget leading;
  final String subtitle;
  final VoidCallback onTap;
  final ValueChanged<_FolderAction> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AspectRatio(
      aspectRatio: 0.82,
      child: Card(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kCardBorderRadius),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _FolderCoverView(folder: folder, fallback: leading),
                    if (folder.hasUpdate || folder.hasNew)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            child: Text(
                              folder.hasNew ? "new_content".tr : "updated".tr,
                              style: TextStyle(
                                color: theme.colorScheme.onPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: PopupMenuButton<_FolderAction>(
                        onSelected: onAction,
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: _FolderAction.cover,
                            child: ListTile(
                              leading: const Icon(Icons.image_outlined),
                              title: Text("bookshelf_cover".tr),
                            ),
                          ),
                          PopupMenuItem(
                            value: _FolderAction.sort,
                            child: ListTile(
                              leading: const Icon(Icons.sort_outlined),
                              title: Text("bookshelf_sort_type".tr),
                            ),
                          ),
                          if (!folder.builtIn)
                            if (folder.smartFolder)
                              PopupMenuItem(
                                value: _FolderAction.editSmart,
                                child: ListTile(
                                  leading: const Icon(Icons.tune_outlined),
                                  title: Text("编辑筛选条件"),
                                ),
                              ),
                          if (!folder.builtIn)
                            PopupMenuItem(
                              value: _FolderAction.rename,
                              child: ListTile(
                                leading: const Icon(
                                  Icons.drive_file_rename_outline,
                                ),
                                title: Text("rename_bookshelf".tr),
                              ),
                            ),
                          if (!folder.builtIn && !folder.smartFolder)
                            PopupMenuItem(
                              value: _FolderAction.createChild,
                              child: ListTile(
                                leading: const Icon(
                                  Icons.create_new_folder_outlined,
                                ),
                                title: Text("new_child_bookshelf".tr),
                              ),
                            ),
                          if (!folder.builtIn)
                            PopupMenuItem(
                              value: _FolderAction.delete,
                              child: ListTile(
                                leading: const Icon(Icons.delete_outline),
                                title: Text("delete_bookshelf".tr),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderCoverView extends StatelessWidget {
  const _FolderCoverView({required this.folder, required this.fallback});

  final BookshelfFolder folder;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final cover = folder.cover;
    if (cover == null) return _FolderIconCover(child: fallback);
    return switch (cover.type) {
      BookshelfFolderCoverType.file => Image.file(
        File(cover.value),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _FolderIconCover(child: fallback),
      ),
      BookshelfFolderCoverType.book => CachedNetworkImage(
        imageUrl: cover.value,
        httpHeaders: Request.userAgent,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => _FolderIconCover(child: fallback),
      ),
    };
  }
}

class _FolderIconCover extends StatelessWidget {
  const _FolderIconCover({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: IconTheme.merge(
          data: IconThemeData(color: theme.colorScheme.primary, size: 58),
          child: SizedBox.square(dimension: 58, child: FittedBox(child: child)),
        ),
      ),
    );
  }
}
