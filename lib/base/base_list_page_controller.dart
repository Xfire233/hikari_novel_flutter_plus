import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/widgets/state_page.dart';

import '../models/page_state.dart';
import '../models/resource.dart';
import '../network/parser.dart';

abstract class BaseListPageController<T> extends GetxController {
  /// ###### 页面初始状态
  abstract Rx<PageState> pageState;
  String errorMsg = "";

  int _maxNum = 1;
  int _index = 0;
  final RxList<T> data = RxList();

  int get pageIndex => _index <= 0 ? 1 : _index;

  bool get canPreviousPage => _index > 1;

  bool get canNextPage => _index < _maxNum;

  @override
  void onReady() {
    super.onReady();
    getPage(false);
  }

  Future<Resource> getData(int index);

  List<T> getParser(String html);

  Future<IndicatorResult> getPage(bool loadMore) async {
    if (!loadMore) {
      pageState.value = PageState.loading;
      data.clear();
      _index = 0;
    }
    if (_index >= _maxNum) return IndicatorResult.noMore;

    _index += 1;
    final result = await getData(_index);

    switch (result) {
      case Success():
        {
          if (!loadMore) _maxNum = Parser.getMaxNum(result.data);
          data.addAll(getParser(result.data));

          pageState.value = PageState.success;
          return IndicatorResult.success;
        }
      case Error():
        {
          if (!loadMore) {
            pageState.value = PageState.error;
            errorMsg = result.error;
          } else {
            showErrorDialog(result.error.toString(), [
              TextButton(onPressed: Get.back, child: Text("confirm".tr)),
            ]);
          }
          if (_index > 0) {
            _index -= 1;
          }
          return IndicatorResult.fail;
        }
    }
  }

  Future<IndicatorResult> getBrowsingPage(int page) async {
    final target = page.clamp(1, _maxNum).toInt();
    pageState.value = PageState.loading;
    final result = await getData(target);

    switch (result) {
      case Success():
        if (target == 1) _maxNum = Parser.getMaxNum(result.data);
        data
          ..clear()
          ..addAll(getParser(result.data));
        _index = target;
        pageState.value = PageState.success;
        return IndicatorResult.success;
      case Error():
        pageState.value = PageState.error;
        errorMsg = result.error.toString();
        return IndicatorResult.fail;
    }
  }

  Future<IndicatorResult> getPreviousBrowsingPage() {
    if (!canPreviousPage) return Future.value(IndicatorResult.noMore);
    return getBrowsingPage(_index - 1);
  }

  Future<IndicatorResult> getNextBrowsingPage() {
    if (!canNextPage) return Future.value(IndicatorResult.noMore);
    return getBrowsingPage(_index + 1);
  }
}
