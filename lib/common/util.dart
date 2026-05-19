import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/service/local_storage_service.dart';
import 'package:jiffy/jiffy.dart';

import '../models/common/language.dart';

class Util {
  static String getDateTime(String dateStr) {
    if (!LocalStorageService.instance.getIsRelativeTime()) {
      return dateStr;
    }
    final inputDate = DateTime.parse(dateStr);
    return Jiffy.parse(inputDate.toString()).fromNow();
  }

  static Locale getCurrentLocale() {
    final language = LocalStorageService.instance.getLanguage();
    if (language == Language.followSystem) {
      if (Get.deviceLocale == const Locale('zh', 'CN')) {
        return const Locale('zh', 'CN');
      } else if (Get.deviceLocale == const Locale('zh', 'TW')) {
        return const Locale('zh', 'TW');
      } else {
        return const Locale('zh', 'CN');
      }
    }
    return switch (language) {
      Language.simplifiedChinese => const Locale('zh', 'CN'),
      Language.traditionalChinese => const Locale('zh', 'TW'),
      _ => const Locale('zh', 'CN'),
    };
  }
}
