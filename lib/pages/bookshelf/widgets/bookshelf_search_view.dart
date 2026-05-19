import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/page_state.dart';
import 'package:hikari_novel_flutter/pages/bookshelf/controller.dart';
import 'package:hikari_novel_flutter/router/app_sub_router.dart';
import 'package:hikari_novel_flutter/widgets/state_page.dart';
import 'package:responsive_grid_list/responsive_grid_list.dart';

import '../../../widgets/novel_cover_card.dart';

class BookshelfSearchView extends StatelessWidget {
  BookshelfSearchView({super.key});

  final controller = Get.put(BookshelfSearchController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: controller.back),
        title: SizedBox(
          height: kToolbarHeight,
          child: TextField(
            controller: controller.searchTextEditController,
            textAlignVertical: TextAlignVertical.center,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: "keyword".tr,
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  controller.searchTextEditController.clear();
                  controller.data.clear();
                  controller.pageState.value = PageState.placeholder;
                },
              ),
              border: InputBorder.none,
            ),
            onChanged: (text) {
              if (text.isEmpty) {
                controller.data.clear();
                controller.pageState.value = PageState.placeholder;
                return;
              }
              controller.getBookshelfByKeyword();
            },
          ),
        ),
        titleSpacing: 16,
      ),
      body: Obx(
        () => AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(
            key: ValueKey('bookshelf-search-${controller.pageState.value}'),
            child: _buildBodyState(),
          ),
        ),
      ),
    );
  }

  Widget _buildBodyState() {
    return switch (controller.pageState.value) {
      PageState.success =>
        controller.data.isEmpty == true
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                child: ResponsiveGridList(
                  minItemWidth: 100,
                  horizontalGridSpacing: 4,
                  verticalGridSpacing: 4,
                  children: controller.data.map((item) {
                    return BookshelfCoverCard(
                      bookshelfNovelInfo: item,
                      onTap: () => AppSubRouter.toNovelDetail(aid: item.aid),
                      onLongPress: () {},
                      onRatingChanged: (rating) =>
                          controller.setRating(item.aid, rating),
                    );
                  }).toList(),
                ),
              ),
      PageState.empty => EmptyPage(),
      _ => const SizedBox.shrink(),
    };
  }
}
