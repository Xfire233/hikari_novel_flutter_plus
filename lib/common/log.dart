import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class Log {
  static final Logger _logger = Logger(
    printer: PrefixPrinter(
      PrettyPrinter(methodCount: 3, dateTimeFormat: DateTimeFormat.dateAndTime),
    ),
  );

  static void t(dynamic message) {
    if (!kDebugMode) return;
    _logger.t(message);
  }

  static void d(dynamic message) {
    if (!kDebugMode) return;
    _logger.d(message);
  }

  static void i(dynamic message) {
    _logger.i(message);
  }

  static void w(dynamic message) {
    _logger.w(message);
  }

  static void e(dynamic message) {
    _logger.e(message);
  }

  static void f(dynamic message) {
    _logger.f(message);
  }
}
