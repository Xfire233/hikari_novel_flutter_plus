import 'dart:async';

import 'package:get/get.dart';

import '../../models/cache_status.dart';
import '../../models/chapter_cache_task.dart';
import '../../network/chapter_downloader.dart';

class CacheQueueController extends GetxService {
  final downloader = ChapterDownloader();

  final RxList<ChapterCacheTask> tasks = <ChapterCacheTask>[].obs;
  final int concurrency;

  bool _isProcessing = false;
  final Map<String, Future> _running = {};

  CacheQueueController({this.concurrency = 1});

  Future<void> addTask(ChapterCacheTask task) async {
    final index = tasks.indexWhere((item) => item.uuid == task.uuid);
    if (index != -1) {
      final old = tasks[index];
      old.title = task.title;
      old.onCompleted = task.onCompleted;
      if (old.status == CacheStatus.failed ||
          old.status == CacheStatus.canceled ||
          old.status == CacheStatus.paused) {
        old.status = CacheStatus.pending;
        old.progress = 0;
        downloader.clearCancel(old.uuid);
      }
      tasks[index] = old;
    } else {
      tasks.add(task);
    }
    startProcessing();
  }

  Future<void> removeTask(String uuid) async {
    downloader.cancel(uuid);
    tasks.removeWhere((task) => task.uuid == uuid);
  }

  Future<void> startProcessing() async {
    if (_isProcessing) return;
    _isProcessing = true;
    unawaited(_processLoop());
  }

  Future<void> _processLoop() async {
    while (_isProcessing) {
      if (_running.length >= concurrency) {
        await Future.delayed(const Duration(milliseconds: 300));
        continue;
      }

      final pending = tasks
          .where((task) => task.status == CacheStatus.pending)
          .toList();
      if (pending.isEmpty) {
        _isProcessing = false;
        break;
      }

      final task = pending.first;
      task.status = CacheStatus.downloading;
      task.progress = 0;
      tasks.refresh();

      final future = _runTask(task).whenComplete(() {
        _running.remove(task.uuid);
      });
      _running[task.uuid] = future;

      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _runTask(ChapterCacheTask task) async {
    try {
      await downloader.download(
        taskId: task.uuid,
        aid: task.aid,
        cid: task.cid,
        onProgress: (received, total) {
          if (total > 0) {
            task.progress = (received / total).clamp(0.0, 1.0);
          } else {
            task.progress = -1;
          }
          tasks.refresh();
        },
      );

      task.status = CacheStatus.completed;
      task.progress = 1;
      tasks.remove(task);
      tasks.refresh();
      task.onCompleted?.call(task.cid);
    } catch (e) {
      if (e.toString().contains('canceled')) {
        if (task.status != CacheStatus.paused) {
          task.status = CacheStatus.canceled;
        }
      } else {
        task.status = CacheStatus.failed;
      }
      tasks.refresh();
    }
  }

  Future<void> pauseTask(String uuid) async {
    downloader.cancel(uuid);
    final index = tasks.indexWhere((task) => task.uuid == uuid);
    if (index != -1) {
      final task = tasks[index];
      task.status = CacheStatus.paused;
      tasks[index] = task;
    }
  }

  Future<void> resumeTask(String uuid) async {
    final index = tasks.indexWhere((task) => task.uuid == uuid);
    if (index != -1) {
      final task = tasks[index];
      if (task.status == CacheStatus.paused ||
          task.status == CacheStatus.failed ||
          task.status == CacheStatus.canceled) {
        task.status = CacheStatus.pending;
        task.progress = 0;
        downloader.clearCancel(uuid);
        tasks[index] = task;
        startProcessing();
      }
    }
  }

  Future<void> cancelTask(String uuid) async {
    downloader.cancel(uuid);
    final index = tasks.indexWhere((task) => task.uuid == uuid);
    if (index != -1) {
      final task = tasks[index];
      task.status = CacheStatus.canceled;
      tasks[index] = task;
    }
  }

  Future<void> startAll() async {
    for (final task in tasks) {
      if (task.status != CacheStatus.completed &&
          task.status != CacheStatus.downloading) {
        task.status = CacheStatus.pending;
        task.progress = 0;
        downloader.clearCancel(task.uuid);
      }
    }
    tasks.refresh();
    startProcessing();
  }

  Future<void> pauseAll() async {
    _isProcessing = false;
    for (final uuid in _running.keys) {
      downloader.cancel(uuid);
    }
    for (final task in tasks) {
      if (task.status == CacheStatus.downloading) {
        task.status = CacheStatus.paused;
      }
    }
    tasks.refresh();
  }

  Future<void> clearAll() async {
    _isProcessing = false;
    downloader.cancelAll();
    _running.clear();
    tasks.clear();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = tasks.toList();
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    tasks.assignAll(list);
  }
}
