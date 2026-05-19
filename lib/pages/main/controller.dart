import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/pages/bookshelf/view.dart';
import 'package:hikari_novel_flutter/pages/my/view.dart';

import '../home/view.dart';

class MainController extends GetxController {
  List<Widget> pages = <Widget>[];
  RxInt selectedIndex = 0.obs;

  RxBool showContent = false.obs;

  RxBool showBookshelfBottomActionBar = false.obs;

  @override
  void onInit() {
    super.onInit();

    pages = [HomePage(), BookshelfPage(), MyPage()];
  }
}
