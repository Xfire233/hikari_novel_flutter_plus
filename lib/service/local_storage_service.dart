import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/hive_registrar.g.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../models/common/language.dart';
import '../models/common/wenku8_node.dart';
import '../models/dual_page_mode.dart';
import '../models/reader_direction.dart';
import '../models/source_config.dart';
import '../models/user_info.dart';

class LocalStorageService extends GetxService {
  static LocalStorageService get instance => Get.find<LocalStorageService>();

  late final Box<dynamic> _setting;
  late final Box<dynamic> _loginInfo;
  late final Box<dynamic> _reader;
  final RxInt loginRevision = 0.obs;

  static const String kCookie = "cookie",
      kYamiboCookie = "yamiboCookie",
      kEsjCookie = "esjCookie",
      kUserInfo = "user_info",
      kLanguage = "language",
      kWenku8Node = "wenku8Node",
      kIsDynamicColor = "isDynamicColor",
      kCustomColor = "customColor",
      kRecentThemeColors = "recentThemeColors",
      kThemeMode = "themeMode",
      kIsRelativeTime = "isRelativeTime",
      kReaderDirection = "readerDirection",
      kReaderFontSize = "readerFontSize",
      kReaderLineSpacing = "readerLineSpacing",
      kReaderWakeLock = "readerWakeLock",
      kReaderLeftMargin = "readerLeftMargin",
      kReaderTopMargin = "readerTopMargin",
      kReaderRightMargin = "readerRightMargin",
      kReaderBottomMargin = "readerBottomMargin",
      kReaderDualPageMode = "readerDualPageMode",
      kReaderDualPageSpacing = "readerDualPageSpacing",
      kReaderImmersionMode = "readerImmersionMode",
      kReaderStatusBar = "readerStatusBar",
      kReaderDayBgColor = "readerDayBgColor",
      kReaderDayTextColor = "readerDayTextColor",
      kReaderNightBgColor = "readerNightBgColor",
      kReaderNightTextColor = "readerNightTextColor",
      kRecentReaderTextColors = "recentReaderTextColors",
      kRecentReaderBgColors = "recentReaderBgColors",
      kReaderDayBgImage = "readerDayBgImage",
      kReaderNightBgImage = "readerNightBgImage",
      kReaderTextFamily = "readerTextFamily",
      kReaderTextStyleFilePath = "readerTextStyleFilePath",
      kReaderPageTurningAnimation = "readerPageTurningAnimation",
      kReaderTtsEnabled = "readerTtsEnabled",
      kReaderTtsEngine = "readerTtsEngine",
      kReaderTtsVoice = "readerTtsVoice",
      kReaderTtsRate = "readerTtsRate",
      kDevModeEnabled = "devModeEnabled",
      kReaderTtsPitch = "readerTtsPitch",
      kReaderTtsVolume = "readerTtsVolume",
      kReaderParaIndent = "readerParaIndent",
      kReaderParaSpacing = "readerParaSpacing",
      kReaderBottomStatusBarHorizontalSpacing =
          "readerBottomStatusBarHorizontalSpacing",
      kReaderVolumeKeyTurning = "readerVolumeKeyTurning",
      kReaderEInkMode = "readerEInkMode",
      kBrowsingEInkMode = "browsingEInkMode",
      kBookshelfRecentCount = "bookshelfRecentCount",
      kBookshelfSortType = "bookshelfSortType",
      kBookshelfSortTypes = "bookshelfSortTypes",
      kBookshelfAidOrders = "bookshelfAidOrders",
      kBookshelfViewModes = "bookshelfViewModes",
      kBookshelfFolderCovers = "bookshelfFolderCovers",
      kBookshelfFolders = "bookshelfFolders",
      kSmartShelfMemberships = "smartShelfMemberships",
      kSourceTagUseCounts = "sourceTagUseCounts",
      kWenku8LastCategory = "wenku8LastCategory",
      kWenku8LastCategorySort = "wenku8LastCategorySort",
      kWenku8LastRanking = "wenku8LastRanking",
      kSourceSyncConfigs = "sourceSyncConfigs",
      kSourceLocalHiddenAids = "sourceLocalHiddenAids";

  Future<void> init() async {
    final Directory dir = await getApplicationSupportDirectory();
    final String path = dir.path;
    Hive.init("$path/hive");
    Hive.registerAdapters();
    _setting = await Hive.openBox("setting");
    _loginInfo = await Hive.openBox("loginInfo");
    _reader = await Hive.openBox("reader");
  }

  void setCookie(String? value) {
    _loginInfo.put(kCookie, value);
    loginRevision.value++;
  }

  String? getCookie() => _loginInfo.get(kCookie);

  void setYamiboCookie(String? value) {
    _loginInfo.put(kYamiboCookie, value);
    loginRevision.value++;
  }

  String? getYamiboCookie() => _loginInfo.get(kYamiboCookie);

  void setEsjCookie(String? value) {
    _loginInfo.put(kEsjCookie, value);
    loginRevision.value++;
  }

  String? getEsjCookie() => _loginInfo.get(kEsjCookie);

  void setUserInfo(UserInfo value) {
    _setting.put(kUserInfo, value);
    loginRevision.value++;
  }

  void clearUserInfo() {
    _setting.delete(kUserInfo);
    loginRevision.value++;
  }

  UserInfo? getUserInfo() => _setting.get(kUserInfo);

  void setThemeMode(ThemeMode tm) => _setting.put(kThemeMode, tm.index);

  ThemeMode getThemeMode() =>
      ThemeMode.values[_setting.get(
        kThemeMode,
        defaultValue: ThemeMode.system.index,
      )];

  void setCustomColor(Color color) =>
      _setting.put(kCustomColor, color.toARGB32());

  Color getCustomColor() =>
      Color(_setting.get(kCustomColor, defaultValue: Colors.blue.toARGB32()));

  List<Color> getRecentThemeColors() =>
      _getRecentColors(_setting, kRecentThemeColors);

  void addRecentThemeColor(Color color) =>
      _addRecentColor(_setting, kRecentThemeColors, color);

  void setIsDynamicColor(bool enabled) =>
      _setting.put(kIsDynamicColor, enabled);

  bool getIsDynamicColor() =>
      _setting.get(kIsDynamicColor, defaultValue: false);

  void setIsRelativeTime(bool enabled) =>
      _setting.put(kIsRelativeTime, enabled);

  bool getIsRelativeTime() =>
      _setting.get(kIsRelativeTime, defaultValue: false);

  void setLanguage(Language value) => _setting.put(kLanguage, value.index);

  Language getLanguage() =>
      Language.values[_setting.get(
        kLanguage,
        defaultValue: Language.followSystem.index,
      )];

  void setWenku8Node(Wenku8Node value) =>
      _setting.put(kWenku8Node, value.index);

  Wenku8Node getWenku8Node() =>
      Wenku8Node.values[_setting.get(
        kWenku8Node,
        defaultValue: Wenku8Node.wwwWenku8Cc.index,
      )];

  ReaderDirection getReaderDirection() =>
      ReaderDirection.values[_reader.get(
        kReaderDirection,
        defaultValue: ReaderDirection.upToDown.index,
      )];

  void setReaderDirection(ReaderDirection value) =>
      _reader.put(kReaderDirection, value.index);

  double getReaderFontSize() =>
      _reader.get(kReaderFontSize, defaultValue: 16.0);

  void setReaderFontSize(double value) => _reader.put(kReaderFontSize, value);

  double getReaderLineSpacing() =>
      _reader.get(kReaderLineSpacing, defaultValue: 1.5);

  void setReaderLineSpacing(double value) =>
      _reader.put(kReaderLineSpacing, value);

  bool getReaderWakeLock() => _reader.get(kReaderWakeLock, defaultValue: false);

  void setReaderWakeLock(bool enabled) => _reader.put(kReaderWakeLock, enabled);

  double getReaderLeftMargin() =>
      _reader.get(kReaderLeftMargin, defaultValue: 20.0);

  void setReaderLeftMargin(double value) =>
      _reader.put(kReaderLeftMargin, value);

  double getReaderTopMargin() =>
      _reader.get(kReaderTopMargin, defaultValue: 20.0);

  void setReaderTopMargin(double value) => _reader.put(kReaderTopMargin, value);

  double getReaderRightMargin() =>
      _reader.get(kReaderRightMargin, defaultValue: 20.0);

  void setReaderRightMargin(double value) =>
      _reader.put(kReaderRightMargin, value);

  double getReaderBottomMargin() =>
      _reader.get(kReaderBottomMargin, defaultValue: 20.0);

  void setReaderBottomMargin(double value) =>
      _reader.put(kReaderBottomMargin, value);

  DualPageMode getReaderDualPageMode() =>
      DualPageMode.values[_reader.get(
        kReaderDualPageMode,
        defaultValue: DualPageMode.auto.index,
      )];

  void setReaderDualPageMode(DualPageMode value) =>
      _reader.put(kReaderDualPageMode, value.index);

  double getReaderDualPageSpacing() =>
      _reader.get(kReaderDualPageSpacing, defaultValue: 20.0);

  void setReaderDualPageSpacing(double value) =>
      _reader.put(kReaderDualPageSpacing, value);

  bool getReaderImmersionMode() =>
      _reader.get(kReaderImmersionMode, defaultValue: false);

  void setReaderImmersionMode(bool enabled) =>
      _reader.put(kReaderImmersionMode, enabled);

  bool getReaderStatusBar() =>
      _reader.get(kReaderStatusBar, defaultValue: true);

  void setReaderStatusBar(bool enabled) =>
      _reader.put(kReaderStatusBar, enabled);

  String? getReaderTextFamily() =>
      _reader.get(kReaderTextFamily, defaultValue: null);

  void setReaderTextFamily(String? value) =>
      _reader.put(kReaderTextFamily, value);

  String? getReaderTextStyleFilePath() =>
      _reader.get(kReaderTextStyleFilePath, defaultValue: null);

  void setReaderTextStyleFilePath(String? value) =>
      _reader.put(kReaderTextStyleFilePath, value);

  bool getReaderPageTurningAnimation() =>
      _reader.get(kReaderPageTurningAnimation, defaultValue: true);

  void setReaderPageTurningAnimation(bool enabled) =>
      _reader.put(kReaderPageTurningAnimation, enabled);

  Color? getReaderDayBgColor() {
    final result = _reader.get(kReaderDayBgColor, defaultValue: null);
    return result == null ? null : Color(result);
  }

  void setReaderDayBgColor(Color? value) =>
      _reader.put(kReaderDayBgColor, value?.toARGB32());

  Color? getReaderDayTextColor() {
    final result = _reader.get(kReaderDayTextColor, defaultValue: null);
    return result == null ? null : Color(result);
  }

  void setReaderDayTextColor(Color? value) =>
      _reader.put(kReaderDayTextColor, value?.toARGB32());

  Color? getReaderNightBgColor() {
    final result = _reader.get(kReaderNightBgColor, defaultValue: null);
    return result == null ? null : Color(result);
  }

  void setReaderNightBgColor(Color? value) =>
      _reader.put(kReaderNightBgColor, value?.toARGB32());

  Color? getReaderNightTextColor() {
    final result = _reader.get(kReaderNightTextColor, defaultValue: null);
    return result == null ? null : Color(result);
  }

  void setReaderNightTextColor(Color? value) =>
      _reader.put(kReaderNightTextColor, value?.toARGB32());

  List<Color> getRecentReaderTextColors() =>
      _getRecentColors(_reader, kRecentReaderTextColors);

  void addRecentReaderTextColor(Color color) =>
      _addRecentColor(_reader, kRecentReaderTextColors, color);

  List<Color> getRecentReaderBgColors() =>
      _getRecentColors(_reader, kRecentReaderBgColors);

  void addRecentReaderBgColor(Color color) =>
      _addRecentColor(_reader, kRecentReaderBgColors, color);

  String? getReaderDayBgImage() =>
      _reader.get(kReaderDayBgImage, defaultValue: null);

  void setReaderDayBgImage(String? value) =>
      _reader.put(kReaderDayBgImage, value);

  String? getReaderNightBgImage() =>
      _reader.get(kReaderNightBgImage, defaultValue: null);

  void setReaderNightBgImage(String? value) =>
      _reader.put(kReaderNightBgImage, value);

  bool getReaderTtsEnabled() =>
      _reader.get(kReaderTtsEnabled, defaultValue: false);

  void setReaderTtsEnabled(bool enabled) =>
      _reader.put(kReaderTtsEnabled, enabled);

  String? getReaderTtsEngine() => _reader.get(kReaderTtsEngine);

  void setReaderTtsEngine(String? value) =>
      _reader.put(kReaderTtsEngine, value);

  Map<String, String>? getReaderTtsVoice() {
    final v = _reader.get(kReaderTtsVoice);
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), val.toString()));
    }
    return null;
  }

  void setReaderTtsVoice(Map<String, String>? value) =>
      _reader.put(kReaderTtsVoice, value);

  double getReaderTtsRate() => _reader.get(kReaderTtsRate, defaultValue: 0.5);

  void setReaderTtsRate(double value) => _reader.put(kReaderTtsRate, value);

  double getReaderTtsPitch() => _reader.get(kReaderTtsPitch, defaultValue: 1.0);

  void setReaderTtsPitch(double value) => _reader.put(kReaderTtsPitch, value);

  double getReaderTtsVolume() =>
      _reader.get(kReaderTtsVolume, defaultValue: 1.0);

  void setReaderTtsVolume(double value) => _reader.put(kReaderTtsVolume, value);

  bool getDevModeEnabled() =>
      _setting.get(kDevModeEnabled, defaultValue: false);

  void setDevModeEnabled(bool value) => _setting.put(kDevModeEnabled, value);

  int getReaderParaIndent() => _reader.get(kReaderParaIndent, defaultValue: 1);

  void setReaderParaIndent(int value) => _reader.put(kReaderParaIndent, value);

  int getReaderParaSpacing() =>
      _reader.get(kReaderParaSpacing, defaultValue: 25);

  void setReaderParaSpacing(int value) =>
      _reader.put(kReaderParaSpacing, value);

  int getReaderBottomStatusBarHorizontalSpacing() =>
      _reader.get(kReaderBottomStatusBarHorizontalSpacing, defaultValue: 25);

  void setReaderBottomStatusBarHorizontalSpacing(int value) =>
      _reader.put(kReaderBottomStatusBarHorizontalSpacing, value);

  bool getReaderVolumeKeyTurning() =>
      _reader.get(kReaderVolumeKeyTurning, defaultValue: false);

  void setReaderVolumeKeyTurning(bool enabled) =>
      _reader.put(kReaderVolumeKeyTurning, enabled);

  bool getReaderEInkMode() => _reader.get(kReaderEInkMode, defaultValue: false);

  void setReaderEInkMode(bool enabled) => _reader.put(kReaderEInkMode, enabled);

  bool getBrowsingEInkMode() =>
      _setting.get(kBrowsingEInkMode, defaultValue: false);

  void setBrowsingEInkMode(bool enabled) =>
      _setting.put(kBrowsingEInkMode, enabled);

  int getBookshelfRecentCount() =>
      _setting.get(kBookshelfRecentCount, defaultValue: 12);

  void setBookshelfRecentCount(int value) =>
      _setting.put(kBookshelfRecentCount, value);

  int getBookshelfSortType() =>
      _setting.get(kBookshelfSortType, defaultValue: 2);

  void setBookshelfSortType(int value) =>
      _setting.put(kBookshelfSortType, value);

  int getBookshelfSortTypeForClassId(String classId) {
    final value = getBookshelfSortTypes()[classId];
    return value ?? getBookshelfSortType();
  }

  void setBookshelfSortTypeForClassId(String classId, int value) {
    final types = getBookshelfSortTypes();
    types[classId] = value;
    _setting.put(kBookshelfSortTypes, types);
  }

  Map<String, int> getBookshelfSortTypes() {
    final raw = _setting.get(kBookshelfSortTypes, defaultValue: const {});
    if (raw is! Map) return {};
    return raw.map((key, value) {
      final intValue = value is int ? value : int.tryParse('$value') ?? 0;
      return MapEntry('$key', intValue);
    });
  }

  List<String> syncBookshelfAidOrder(String classId, Iterable<String> aids) {
    final aidList = aids.toList();
    final aidSet = aidList.toSet();
    final orders = getBookshelfAidOrders();
    final current = orders[classId] ?? const <String>[];
    final next = [
      for (final aid in current)
        if (aidSet.contains(aid)) aid,
    ];
    final known = next.toSet();
    for (final aid in aidList) {
      if (known.add(aid)) next.add(aid);
    }
    orders[classId] = next;
    _setting.put(kBookshelfAidOrders, orders);
    return next;
  }

  void setBookshelfAidOrder(String classId, Iterable<String> aids) {
    final seen = <String>{};
    final orders = getBookshelfAidOrders();
    orders[classId] = [
      for (final aid in aids)
        if (seen.add(aid)) aid,
    ];
    _setting.put(kBookshelfAidOrders, orders);
  }

  Map<String, List<String>> getBookshelfAidOrders() {
    final raw = _setting.get(kBookshelfAidOrders, defaultValue: const {});
    if (raw is! Map) return {};
    return raw.map((key, value) {
      final list = value is Iterable
          ? value.map((item) => '$item').toList()
          : const <String>[];
      return MapEntry('$key', list);
    });
  }

  List<Map<String, String>> getBookshelfFolders() {
    final raw = _setting.get(kBookshelfFolders, defaultValue: const []);
    if (raw is! List) return [];
    return raw.whereType<Map>().map((item) {
      return item.map((key, value) => MapEntry('$key', '$value'));
    }).toList();
  }

  void setBookshelfFolders(List<Map<String, String>> value) =>
      _setting.put(kBookshelfFolders, value);

  Map<String, List<Map<String, String>>> getSmartShelfMemberships() {
    final raw = _setting.get(kSmartShelfMemberships, defaultValue: const {});
    if (raw is! Map) return {};
    final result = <String, List<Map<String, String>>>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is! Iterable) continue;
      result['${entry.key}'] = value.whereType<Map>().map((item) {
        return item.map((key, value) => MapEntry('$key', '$value'));
      }).toList();
    }
    return result;
  }

  List<Map<String, String>> getSmartShelfMembership(String shelfId) =>
      getSmartShelfMemberships()[shelfId] ?? const [];

  void setSmartShelfMembership(
    String shelfId,
    List<Map<String, String>> items,
  ) {
    final memberships = getSmartShelfMemberships();
    memberships[shelfId] = items;
    _setting.put(kSmartShelfMemberships, memberships);
  }

  void clearSmartShelfNewMarks(String shelfId) {
    final items = getSmartShelfMembership(shelfId);
    if (items.isEmpty) return;
    setSmartShelfMembership(
      shelfId,
      items.map((item) => {...item, 'isNew': 'false'}).toList(),
    );
  }

  Map<String, int> getSourceTagUseCounts(String sourceId) {
    final raw = _setting.get(kSourceTagUseCounts, defaultValue: const {});
    if (raw is! Map) return {};
    final sourceRaw = raw[sourceId];
    if (sourceRaw is! Map) return {};
    return sourceRaw.map((key, value) {
      final count = value is int ? value : int.tryParse('$value') ?? 0;
      return MapEntry('$key', count);
    });
  }

  void increaseSourceTagUseCount(String sourceId, String tag) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) return;
    final raw = _setting.get(kSourceTagUseCounts, defaultValue: const {});
    final next = <String, Map<String, int>>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        final value = entry.value;
        if (value is Map) {
          next['${entry.key}'] = value.map((key, value) {
            final count = value is int ? value : int.tryParse('$value') ?? 0;
            return MapEntry('$key', count);
          });
        }
      }
    }
    final counts = next[sourceId] ?? <String, int>{};
    counts[trimmed] = (counts[trimmed] ?? 0) + 1;
    next[sourceId] = counts;
    _setting.put(kSourceTagUseCounts, next);
  }

  String? getWenku8LastCategory() => _setting.get(kWenku8LastCategory);

  void setWenku8LastCategory(String value) =>
      _setting.put(kWenku8LastCategory, value);

  String? getWenku8LastCategorySort() => _setting.get(kWenku8LastCategorySort);

  void setWenku8LastCategorySort(String value) =>
      _setting.put(kWenku8LastCategorySort, value);

  String? getWenku8LastRanking() => _setting.get(kWenku8LastRanking);

  void setWenku8LastRanking(String value) =>
      _setting.put(kWenku8LastRanking, value);

  Map<String, bool> getBookshelfViewModes() {
    final raw = _setting.get(kBookshelfViewModes, defaultValue: const {});
    if (raw is! Map) return {};
    return raw.map((key, value) => MapEntry('$key', value == true));
  }

  bool? getBookshelfUseListViewForClassId(String classId) {
    return getBookshelfViewModes()[classId];
  }

  void setBookshelfUseListViewForClassId(String classId, bool useListView) {
    final modes = getBookshelfViewModes();
    modes[classId] = useListView;
    _setting.put(kBookshelfViewModes, modes);
  }

  Map<String, Map<String, String>> getBookshelfFolderCovers() {
    final raw = _setting.get(kBookshelfFolderCovers, defaultValue: const {});
    if (raw is! Map) return {};
    final result = <String, Map<String, String>>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is Map) {
        result['${entry.key}'] = value.map(
          (key, item) => MapEntry('$key', '$item'),
        );
      }
    }
    return result;
  }

  Map<String, String>? getBookshelfFolderCover(String classId) {
    return getBookshelfFolderCovers()[classId];
  }

  void setBookshelfFolderCover(String classId, Map<String, String>? cover) {
    final covers = getBookshelfFolderCovers();
    if (cover == null || cover.isEmpty) {
      covers.remove(classId);
    } else {
      covers[classId] = cover;
    }
    _setting.put(kBookshelfFolderCovers, covers);
  }

  bool hasSourceSyncConfigs() => _setting.containsKey(kSourceSyncConfigs);

  Map<NovelSource, SourceSyncConfig> getSourceSyncConfigs() {
    final raw = _setting.get(kSourceSyncConfigs, defaultValue: const []);
    final configs = {
      for (final source in NovelSource.values)
        source: SourceSyncConfig.defaults(source),
    };
    if (raw is! List) return configs;
    for (final item in raw.whereType<Map>()) {
      final config = SourceSyncConfig.fromJson(item);
      configs[config.source] = config;
    }
    return configs;
  }

  void setSourceSyncConfigs(Map<NovelSource, SourceSyncConfig> value) {
    _setting.put(
      kSourceSyncConfigs,
      value.values.map((item) => item.toJson()).toList(),
    );
  }

  Set<String> getSourceLocalHiddenAids(NovelSource source) {
    final raw = _setting.get(kSourceLocalHiddenAids, defaultValue: const {});
    if (raw is! Map) return {};
    final sourceRaw = raw[source.id];
    if (sourceRaw is! List) return {};
    return sourceRaw.map((item) => '$item').toSet();
  }

  void setSourceLocalHiddenAids(NovelSource source, Set<String> aids) {
    final raw = _setting.get(kSourceLocalHiddenAids, defaultValue: const {});
    final next = <String, List<String>>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        final value = entry.value;
        if (value is List) {
          next['${entry.key}'] = value.map((item) => '$item').toList();
        }
      }
    }
    next[source.id] = aids.toList();
    _setting.put(kSourceLocalHiddenAids, next);
  }

  Map<String, dynamic> exportAuthBackup() => {
    'cookies': {
      'wenku8': getCookie(),
      'esj': getEsjCookie(),
      'yamibo': getYamiboCookie(),
    },
    'wenku8UserInfo': _userInfoToJson(getUserInfo()),
  };

  void importAuthBackup(Map<String, dynamic> data) {
    final cookies = data['cookies'];
    if (cookies is Map) {
      setCookie(_nullableString(cookies['wenku8']));
      setEsjCookie(_nullableString(cookies['esj']));
      setYamiboCookie(_nullableString(cookies['yamibo']));
    }
    final userInfo = data['wenku8UserInfo'];
    if (userInfo is Map) {
      setUserInfo(_userInfoFromJson(userInfo));
    }
  }

  Map<String, dynamic> exportAppSettingsBackup() => {
    'language': getLanguage().index,
    'themeMode': getThemeMode().index,
    'dynamicColor': getIsDynamicColor(),
    'customColor': getCustomColor().toARGB32(),
    'recentThemeColors': _colorValues(getRecentThemeColors()),
    'relativeTime': getIsRelativeTime(),
    'wenku8Node': getWenku8Node().index,
    'browsingEInkMode': getBrowsingEInkMode(),
    'devModeEnabled': getDevModeEnabled(),
    'bookshelfRecentCount': getBookshelfRecentCount(),
    'bookshelfSortType': getBookshelfSortType(),
    'bookshelfSortTypes': getBookshelfSortTypes(),
    'bookshelfAidOrders': getBookshelfAidOrders(),
    'bookshelfViewModes': getBookshelfViewModes(),
    'bookshelfFolderCovers': getBookshelfFolderCovers(),
    'bookshelfFolders': getBookshelfFolders(),
    'smartShelfMemberships': getSmartShelfMemberships(),
    'sourceTagUseCounts': _setting.get(
      kSourceTagUseCounts,
      defaultValue: const {},
    ),
    'wenku8LastCategory': getWenku8LastCategory(),
    'wenku8LastCategorySort': getWenku8LastCategorySort(),
    'wenku8LastRanking': getWenku8LastRanking(),
    'sourceSyncConfigs': getSourceSyncConfigs().values
        .map((item) => item.toJson())
        .toList(),
    'sourceLocalHiddenAids': {
      for (final source in NovelSource.values)
        source.id: getSourceLocalHiddenAids(source).toList(),
    },
  };

  void importAppSettingsBackup(Map<String, dynamic> data) {
    final language = _intAt(data, 'language');
    if (language != null &&
        language >= 0 &&
        language < Language.values.length) {
      setLanguage(Language.values[language]);
    }
    final themeMode = _intAt(data, 'themeMode');
    if (themeMode != null &&
        themeMode >= 0 &&
        themeMode < ThemeMode.values.length) {
      setThemeMode(ThemeMode.values[themeMode]);
    }
    final customColor = _intAt(data, 'customColor');
    if (customColor != null) setCustomColor(Color(customColor));
    _setRecentColors(_setting, kRecentThemeColors, data['recentThemeColors']);
    _setBool(data, 'dynamicColor', setIsDynamicColor);
    _setBool(data, 'relativeTime', setIsRelativeTime);
    _setBool(data, 'browsingEInkMode', setBrowsingEInkMode);
    _setBool(data, 'devModeEnabled', setDevModeEnabled);
    final wenku8Node = _intAt(data, 'wenku8Node');
    if (wenku8Node != null &&
        wenku8Node >= 0 &&
        wenku8Node < Wenku8Node.values.length) {
      setWenku8Node(Wenku8Node.values[wenku8Node]);
    }
    final recentCount = _intAt(data, 'bookshelfRecentCount');
    if (recentCount != null) setBookshelfRecentCount(recentCount);
    final sortType = _intAt(data, 'bookshelfSortType');
    if (sortType != null) setBookshelfSortType(sortType);
    final sortTypes = data['bookshelfSortTypes'];
    if (sortTypes is Map) {
      _setting.put(
        kBookshelfSortTypes,
        sortTypes.map((key, value) {
          final intValue = value is int ? value : int.tryParse('$value') ?? 0;
          return MapEntry('$key', intValue);
        }),
      );
    }
    final aidOrders = data['bookshelfAidOrders'];
    if (aidOrders is Map) {
      _setting.put(
        kBookshelfAidOrders,
        aidOrders.map(
          (key, value) => MapEntry(
            '$key',
            value is Iterable ? value.map((item) => '$item').toList() : [],
          ),
        ),
      );
    }
    final viewModes = data['bookshelfViewModes'];
    if (viewModes is Map) {
      _setting.put(
        kBookshelfViewModes,
        viewModes.map((key, value) => MapEntry('$key', value == true)),
      );
    }
    final folderCovers = data['bookshelfFolderCovers'];
    if (folderCovers is Map) {
      _setting.put(
        kBookshelfFolderCovers,
        folderCovers.map((key, value) {
          final cover = value is Map
              ? value.map((coverKey, coverValue) {
                  return MapEntry('$coverKey', '$coverValue');
                })
              : <String, String>{};
          return MapEntry('$key', cover);
        }),
      );
    }
    final folders = data['bookshelfFolders'];
    if (folders is List) {
      setBookshelfFolders(
        folders
            .whereType<Map>()
            .map((item) => item.map((key, value) => MapEntry('$key', '$value')))
            .toList(),
      );
    }
    final memberships = data['smartShelfMemberships'];
    if (memberships is Map) {
      _setting.put(
        kSmartShelfMemberships,
        memberships.map((key, value) {
          return MapEntry(
            '$key',
            value is Iterable
                ? value.whereType<Map>().map((item) {
                    return item.map((k, v) => MapEntry('$k', '$v'));
                  }).toList()
                : const <Map<String, String>>[],
          );
        }),
      );
    }
    final tagCounts = data['sourceTagUseCounts'];
    if (tagCounts is Map) {
      _setting.put(kSourceTagUseCounts, tagCounts);
    }
    final lastCategory = data['wenku8LastCategory'];
    if (lastCategory is String) setWenku8LastCategory(lastCategory);
    final lastCategorySort = data['wenku8LastCategorySort'];
    if (lastCategorySort is String) {
      setWenku8LastCategorySort(lastCategorySort);
    }
    final lastRanking = data['wenku8LastRanking'];
    if (lastRanking is String) setWenku8LastRanking(lastRanking);
    final sourceConfigs = data['sourceSyncConfigs'];
    if (sourceConfigs is List) {
      final configs = {
        for (final source in NovelSource.values)
          source: SourceSyncConfig.defaults(source),
      };
      for (final item in sourceConfigs.whereType<Map>()) {
        final config = SourceSyncConfig.fromJson(item);
        configs[config.source] = config;
      }
      setSourceSyncConfigs(configs);
    }
    final hidden = data['sourceLocalHiddenAids'];
    if (hidden is Map) {
      for (final source in NovelSource.values) {
        final value = hidden[source.id];
        if (value is Iterable) {
          setSourceLocalHiddenAids(
            source,
            value.map((item) => '$item').toSet(),
          );
        }
      }
    }
  }

  Map<String, dynamic> exportReaderSettingsBackup() => {
    'direction': getReaderDirection().index,
    'fontSize': getReaderFontSize(),
    'lineSpacing': getReaderLineSpacing(),
    'wakeLock': getReaderWakeLock(),
    'margins': {
      'left': getReaderLeftMargin(),
      'top': getReaderTopMargin(),
      'right': getReaderRightMargin(),
      'bottom': getReaderBottomMargin(),
    },
    'dualPageMode': getReaderDualPageMode().index,
    'dualPageSpacing': getReaderDualPageSpacing(),
    'immersionMode': getReaderImmersionMode(),
    'showStatusBar': getReaderStatusBar(),
    'textFamily': getReaderTextFamily(),
    'textStyleFilePath': getReaderTextStyleFilePath(),
    'pageTurningAnimation': getReaderPageTurningAnimation(),
    'dayBgColor': getReaderDayBgColor()?.toARGB32(),
    'dayTextColor': getReaderDayTextColor()?.toARGB32(),
    'nightBgColor': getReaderNightBgColor()?.toARGB32(),
    'nightTextColor': getReaderNightTextColor()?.toARGB32(),
    'recentTextColors': _colorValues(getRecentReaderTextColors()),
    'recentBgColors': _colorValues(getRecentReaderBgColors()),
    'dayBgImage': getReaderDayBgImage(),
    'nightBgImage': getReaderNightBgImage(),
    'ttsEnabled': getReaderTtsEnabled(),
    'ttsEngine': getReaderTtsEngine(),
    'ttsVoice': getReaderTtsVoice(),
    'ttsRate': getReaderTtsRate(),
    'ttsPitch': getReaderTtsPitch(),
    'ttsVolume': getReaderTtsVolume(),
    'paraIndent': getReaderParaIndent(),
    'paraSpacing': getReaderParaSpacing(),
    'bottomStatusBarHorizontalSpacing':
        getReaderBottomStatusBarHorizontalSpacing(),
    'volumeKeyTurning': getReaderVolumeKeyTurning(),
    'readerEInkMode': getReaderEInkMode(),
  };

  void importReaderSettingsBackup(Map<String, dynamic> data) {
    final direction = _intAt(data, 'direction');
    if (direction != null &&
        direction >= 0 &&
        direction < ReaderDirection.values.length) {
      setReaderDirection(ReaderDirection.values[direction]);
    }
    _setDouble(data, 'fontSize', setReaderFontSize);
    _setDouble(data, 'lineSpacing', setReaderLineSpacing);
    _setBool(data, 'wakeLock', setReaderWakeLock);
    final margins = data['margins'];
    if (margins is Map) {
      _setDouble(margins, 'left', setReaderLeftMargin);
      _setDouble(margins, 'top', setReaderTopMargin);
      _setDouble(margins, 'right', setReaderRightMargin);
      _setDouble(margins, 'bottom', setReaderBottomMargin);
    }
    final dualPageMode = _intAt(data, 'dualPageMode');
    if (dualPageMode != null &&
        dualPageMode >= 0 &&
        dualPageMode < DualPageMode.values.length) {
      setReaderDualPageMode(DualPageMode.values[dualPageMode]);
    }
    _setDouble(data, 'dualPageSpacing', setReaderDualPageSpacing);
    _setBool(data, 'immersionMode', setReaderImmersionMode);
    _setBool(data, 'showStatusBar', setReaderStatusBar);
    setReaderTextFamily(_nullableString(data['textFamily']));
    setReaderTextStyleFilePath(_nullableString(data['textStyleFilePath']));
    _setBool(data, 'pageTurningAnimation', setReaderPageTurningAnimation);
    setReaderDayBgColor(_nullableColor(data['dayBgColor']));
    setReaderDayTextColor(_nullableColor(data['dayTextColor']));
    setReaderNightBgColor(_nullableColor(data['nightBgColor']));
    setReaderNightTextColor(_nullableColor(data['nightTextColor']));
    _setRecentColors(
      _reader,
      kRecentReaderTextColors,
      data['recentTextColors'],
    );
    _setRecentColors(_reader, kRecentReaderBgColors, data['recentBgColors']);
    setReaderDayBgImage(_nullableString(data['dayBgImage']));
    setReaderNightBgImage(_nullableString(data['nightBgImage']));
    _setBool(data, 'ttsEnabled', setReaderTtsEnabled);
    setReaderTtsEngine(_nullableString(data['ttsEngine']));
    final ttsVoice = data['ttsVoice'];
    setReaderTtsVoice(
      ttsVoice is Map
          ? ttsVoice.map((key, value) => MapEntry('$key', '$value'))
          : null,
    );
    _setDouble(data, 'ttsRate', setReaderTtsRate);
    _setDouble(data, 'ttsPitch', setReaderTtsPitch);
    _setDouble(data, 'ttsVolume', setReaderTtsVolume);
    final paraIndent = _intAt(data, 'paraIndent');
    if (paraIndent != null) setReaderParaIndent(paraIndent);
    final paraSpacing = _intAt(data, 'paraSpacing');
    if (paraSpacing != null) setReaderParaSpacing(paraSpacing);
    final bottomSpacing = _intAt(data, 'bottomStatusBarHorizontalSpacing');
    if (bottomSpacing != null) {
      setReaderBottomStatusBarHorizontalSpacing(bottomSpacing);
    }
    _setBool(data, 'volumeKeyTurning', setReaderVolumeKeyTurning);
    _setBool(data, 'readerEInkMode', setReaderEInkMode);
  }

  List<Color> _getRecentColors(Box<dynamic> box, String key) {
    final value = box.get(key);
    if (value is! Iterable) return const [];
    return value
        .map((item) => item is int ? item : int.tryParse('$item'))
        .whereType<int>()
        .map(Color.new)
        .toList(growable: false);
  }

  void _addRecentColor(Box<dynamic> box, String key, Color color) {
    final argb = color.toARGB32();
    final next = <int>[
      argb,
      ..._getRecentColors(
        box,
        key,
      ).map((item) => item.toARGB32()).where((item) => item != argb),
    ].take(8).toList(growable: false);
    box.put(key, next);
  }

  List<int> _colorValues(List<Color> colors) =>
      colors.map((item) => item.toARGB32()).toList(growable: false);

  void _setRecentColors(Box<dynamic> box, String key, dynamic value) {
    if (value is! Iterable) return;
    final colors = value
        .map((item) => item is int ? item : int.tryParse('$item'))
        .whereType<int>()
        .take(8)
        .toList(growable: false);
    box.put(key, colors);
  }

  Map<String, dynamic>? _userInfoToJson(UserInfo? value) => value == null
      ? null
      : {
          'avatar': value.avatar,
          'uid': value.uid,
          'username': value.username,
          'userLevel': value.userLevel,
          'email': value.email,
          'registerDate': value.registerDate,
          'contribution': value.contribution,
          'experience': value.experience,
          'point': value.point,
          'maxBookshelfNum': value.maxBookshelfNum,
          'maxRecommendNum': value.maxRecommendNum,
        };

  UserInfo _userInfoFromJson(Map<dynamic, dynamic> json) => UserInfo(
    avatar: '${json['avatar'] ?? ''}',
    uid: '${json['uid'] ?? ''}',
    username: '${json['username'] ?? ''}',
    userLevel: '${json['userLevel'] ?? ''}',
    email: '${json['email'] ?? ''}',
    registerDate: '${json['registerDate'] ?? ''}',
    contribution: '${json['contribution'] ?? ''}',
    experience: '${json['experience'] ?? ''}',
    point: '${json['point'] ?? ''}',
    maxBookshelfNum: '${json['maxBookshelfNum'] ?? ''}',
    maxRecommendNum: '${json['maxRecommendNum'] ?? ''}',
  );

  String? _nullableString(dynamic value) => value == null ? null : '$value';

  int? _intAt(Map<dynamic, dynamic> data, String key) {
    final value = data[key];
    return value is int ? value : int.tryParse('$value');
  }

  double? _doubleAt(Map<dynamic, dynamic> data, String key) {
    final value = data[key];
    return value is num ? value.toDouble() : double.tryParse('$value');
  }

  void _setBool(
    Map<dynamic, dynamic> data,
    String key,
    void Function(bool value) setter,
  ) {
    final value = data[key];
    if (value is bool) setter(value);
  }

  void _setDouble(
    Map<dynamic, dynamic> data,
    String key,
    void Function(double value) setter,
  ) {
    final value = _doubleAt(data, key);
    if (value != null) setter(value);
  }

  Color? _nullableColor(dynamic value) {
    if (value == null) return null;
    final intValue = value is int ? value : int.tryParse('$value');
    return intValue == null ? null : Color(intValue);
  }
}
