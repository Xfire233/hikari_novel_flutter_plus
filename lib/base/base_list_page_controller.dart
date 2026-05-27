import 'dart:async';

import 'package:easy_refresh/easy_refresh.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/widgets/state_page.dart';

import '../models/page_state.dart';
import '../models/resource.dart';
import '../network/parser.dart';

abstract class BaseListPageController<T> extends GetxController {
  static const _pageRequestTimeout = Duration(seconds: 45);

  final EasyRefreshController easyRefreshController = EasyRefreshController();

  /// ###### 页面初始状态
  abstract Rx<PageState> pageState;
  String errorMsg = "";

  int _maxNum = 1;
  int _index = 0;
  bool _hasKnownMaxNum = true;
  final RxList<T> data = RxList();

  int get pageIndex => _index <= 0 ? 1 : _index;

  bool get canPreviousPage => _index > 1;

  bool get canNextPage => !_hasKnownMaxNum || _index < _maxNum;

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
      _hasKnownMaxNum = true;
    }
    if (_hasKnownMaxNum && _index >= _maxNum) {
      return IndicatorResult.noMore;
    }

    _index += 1;
    final result = await _getDataWithTimeout(_index);

    switch (result) {
      case Success():
        {
          final parsed = getParser(result.data);
          if (!loadMore) {
            final maxNum = Parser.getMaxNum(result.data);
            _hasKnownMaxNum = maxNum > 0;
            _maxNum = _hasKnownMaxNum
                ? maxNum
                : (parsed.isEmpty ? 1 : _index + 1);
          }
          if (!loadMore && parsed.isEmpty) {
            pageState.value = PageState.error;
            errorMsg = '没有解析到内容，可能是站点返回了空页面、验证页或页面结构已变化。';
            if (_index > 0) {
              _index -= 1;
            }
            return IndicatorResult.fail;
          }
          if (loadMore && parsed.isEmpty) {
            _index -= 1;
            _maxNum = _index;
            _hasKnownMaxNum = true;
            return IndicatorResult.noMore;
          }
          data.addAll(parsed);
          if (!_hasKnownMaxNum && _index >= _maxNum) {
            _maxNum = _index + 1;
          }

          pageState.value = PageState.success;
          return IndicatorResult.success;
        }
      case Error():
        {
          errorMsg = result.error.toString();
          if (!loadMore) {
            pageState.value = PageState.error;
          } else {
            _resetLoadFooterAfterFailure();
            final context = Get.context;
            if (context != null && context.mounted) {
              showSnackBar(message: result.error.toString(), context: context);
            }
          }
          if (_index > 0) {
            _index -= 1;
          }
          return IndicatorResult.fail;
        }
    }
  }

  Future<IndicatorResult> getBrowsingPage(int page) async {
    final target = _hasKnownMaxNum ? page.clamp(1, _maxNum).toInt() : page;
    pageState.value = PageState.loading;
    final result = await _getDataWithTimeout(target);

    switch (result) {
      case Success():
        final parsed = getParser(result.data);
        if (target == 1) {
          final maxNum = Parser.getMaxNum(result.data);
          _hasKnownMaxNum = maxNum > 0;
          _maxNum = _hasKnownMaxNum
              ? maxNum
              : (parsed.isEmpty ? 1 : target + 1);
        }
        if (parsed.isEmpty) {
          if (!_hasKnownMaxNum && target > 1) {
            _maxNum = target - 1;
            _hasKnownMaxNum = true;
            return IndicatorResult.noMore;
          }
          pageState.value = PageState.error;
          errorMsg = '没有解析到内容，可能是站点返回了空页面、验证页或页面结构已变化。';
          return IndicatorResult.fail;
        }
        data
          ..clear()
          ..addAll(parsed);
        _index = target;
        if (!_hasKnownMaxNum && _index >= _maxNum) {
          _maxNum = _index + 1;
        }
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

  Future<Resource> _getDataWithTimeout(int index) {
    return getData(index).timeout(
      _pageRequestTimeout,
      onTimeout: () => Error('页面请求超时，请切换网络或稍后重试。'),
    );
  }

  void _resetLoadFooterAfterFailure() {
    unawaited(
      Future<void>.delayed(
        const Duration(milliseconds: 120),
        easyRefreshController.resetFooter,
      ),
    );
  }
}
