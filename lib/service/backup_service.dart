import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../common/database/database.dart';
import 'db_service.dart';
import 'local_storage_service.dart';
import 'source_config_service.dart';

class BackupSectionOptions {
  const BackupSectionOptions({
    required this.auth,
    required this.appSettings,
    required this.readerSettings,
    required this.bookshelf,
    required this.readingData,
  });

  const BackupSectionOptions.all()
    : auth = true,
      appSettings = true,
      readerSettings = true,
      bookshelf = true,
      readingData = true;

  final bool auth;
  final bool appSettings;
  final bool readerSettings;
  final bool bookshelf;
  final bool readingData;

  bool get hasAny =>
      auth || appSettings || readerSettings || bookshelf || readingData;

  Map<String, bool> toJson() => {
    'auth': auth,
    'appSettings': appSettings,
    'readerSettings': readerSettings,
    'bookshelf': bookshelf,
    'readingData': readingData,
  };
}

class BackupService extends GetxService {
  static BackupService get instance => Get.find<BackupService>();

  static const format = 'hikari_novel_backup';
  static const schemaVersion = 1;

  Future<String?> exportBackup(BackupSectionOptions options) async {
    if (!options.hasAny) return null;
    final info = await PackageInfo.fromPlatform();
    final storage = LocalStorageService.instance;
    final payload = <String, dynamic>{};

    if (options.auth) payload['auth'] = storage.exportAuthBackup();
    if (options.appSettings) {
      payload['appSettings'] = storage.exportAppSettingsBackup();
    }
    if (options.readerSettings) {
      payload['readerSettings'] = storage.exportReaderSettingsBackup();
    }
    if (options.bookshelf) {
      payload['bookshelf'] = await _exportBookshelf();
    }
    if (options.readingData) {
      payload['readingData'] = await _exportReadingData();
    }

    final document = {
      'format': format,
      'schemaVersion': schemaVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'app': {
        'name': info.appName,
        'packageName': info.packageName,
        'version': info.version,
        'buildNumber': info.buildNumber,
      },
      'sections': options.toJson(),
      'payload': payload,
    };
    final jsonText = const JsonEncoder.withIndent('  ').convert(document);
    final fileName =
        'Hikari-Novel-Backup-${DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-')}.json';
    return FilePicker.platform.saveFile(
      dialogTitle: 'export_backup'.tr,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: Uint8List.fromList(utf8.encode(jsonText)),
    );
  }

  Future<bool> importBackup(BackupSectionOptions options) async {
    if (!options.hasAny) return false;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) return false;

    final bytes = file.bytes ?? await File(file.path!).readAsBytes();
    final root = jsonDecode(utf8.decode(bytes));
    if (root is! Map || root['format'] != format) {
      throw const FormatException('Unsupported backup file');
    }
    final payload = root['payload'];
    if (payload is! Map) throw const FormatException('Invalid backup payload');

    final storage = LocalStorageService.instance;
    if (options.auth && payload['auth'] is Map) {
      storage.importAuthBackup(Map<String, dynamic>.from(payload['auth']));
    }
    if (options.appSettings && payload['appSettings'] is Map) {
      storage.importAppSettingsBackup(
        Map<String, dynamic>.from(payload['appSettings']),
      );
    }
    if (options.readerSettings && payload['readerSettings'] is Map) {
      storage.importReaderSettingsBackup(
        Map<String, dynamic>.from(payload['readerSettings']),
      );
    }
    if (options.bookshelf && payload['bookshelf'] is Map) {
      await _importBookshelf(Map<String, dynamic>.from(payload['bookshelf']));
    }
    if (options.readingData && payload['readingData'] is Map) {
      await _importReadingData(
        Map<String, dynamic>.from(payload['readingData']),
      );
    }
    SourceConfigService.instance.configs.assignAll(
      storage.getSourceSyncConfigs(),
    );
    Get.forceAppUpdate();
    return true;
  }

  Future<Map<String, dynamic>> _exportBookshelf() async {
    final storage = LocalStorageService.instance;
    return {
      'items': (await DBService.instance.getAllBookshelf())
          .map((item) => item.toJson())
          .toList(),
      'folders': storage.getBookshelfFolders(),
      'sortTypes': storage.getBookshelfSortTypes(),
      'aidOrders': storage.getBookshelfAidOrders(),
    };
  }

  Future<Map<String, dynamic>> _exportReadingData() async {
    return {
      'readHistory': (await DBService.instance.getAllReadHistory())
          .map((item) => item.toJson())
          .toList(),
      'browsingHistory': (await DBService.instance.getAllBrowsingHistory())
          .map((item) => item.toJson())
          .toList(),
      'searchHistory': (await DBService.instance.getAllSearchHistoryItems())
          .map((item) => item.toJson())
          .toList(),
      'novelDetails': (await DBService.instance.getAllNovelDetails())
          .map((item) => item.toJson())
          .toList(),
    };
  }

  Future<void> _importBookshelf(Map<String, dynamic> data) async {
    final items = data['items'];
    if (items is List) {
      for (final item in items.whereType<Map>()) {
        final json = Map<String, dynamic>.from(item);
        json['rating'] ??= 0.0;
        await DBService.instance.upsertBookshelf(
          BookshelfEntityData.fromJson(json),
        );
      }
    }
    LocalStorageService.instance.importAppSettingsBackup({
      if (data['folders'] != null) 'bookshelfFolders': data['folders'],
      if (data['sortTypes'] != null) 'bookshelfSortTypes': data['sortTypes'],
      if (data['aidOrders'] != null) 'bookshelfAidOrders': data['aidOrders'],
    });
  }

  Future<void> _importReadingData(Map<String, dynamic> data) async {
    final readHistory = data['readHistory'];
    if (readHistory is List) {
      for (final item in readHistory.whereType<Map>()) {
        await DBService.instance.upsertReadHistoryDirectly(
          ReadHistoryEntityData.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }
    final browsingHistory = data['browsingHistory'];
    if (browsingHistory is List) {
      for (final item in browsingHistory.whereType<Map>()) {
        await DBService.instance.upsertBrowsingHistory(
          BrowsingHistoryEntityData.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }
    final novelDetails = data['novelDetails'];
    if (novelDetails is List) {
      for (final item in novelDetails.whereType<Map>()) {
        await DBService.instance.upsertNovelDetail(
          NovelDetailEntityData.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }
    final searchHistory = data['searchHistory'];
    if (searchHistory is List) {
      for (final item in searchHistory.whereType<Map>()) {
        await DBService.instance.upsertSearchHistory(
          SearchHistoryEntityData.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }
  }
}
