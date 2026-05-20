import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/resource.dart';
import 'package:hikari_novel_flutter/service/local_storage_service.dart';

import '../../base/base_select_list_page_controller.dart';
import '../../models/novel_cover.dart';
import '../../network/api.dart';
import '../../network/parser.dart';

class CategoryController extends BaseSelectListPageController<NovelCover> {
  RxString category =
      (LocalStorageService.instance.getWenku8LastCategory() ?? "school".tr).obs;
  RxString sortText = "sort_by_update".tr.obs;
  String sortValue =
      LocalStorageService.instance.getWenku8LastCategorySort() ?? "0";

  @override
  void onInit() {
    super.onInit();

    //监听参数变化
    everAll([category, sortText], (_) {
      LocalStorageService.instance.setWenku8LastCategory(category.value);
      LocalStorageService.instance.setWenku8LastCategorySort(sortValue);
      getPage(false);
    });
    getPage(false);
  }

  @override
  Future<Resource> getData(int index) => Api.getNovelByCategory(
    category: category.value,
    sort: sortValue,
    index: index,
  );

  @override
  List<NovelCover> getParser(String html) => Parser.parseToList(html);
}
