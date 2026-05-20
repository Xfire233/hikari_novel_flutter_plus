import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/cache_status.dart';
import '../../models/chapter_cache_task.dart';
import 'controller.dart';

class CacheQueuePage extends StatelessWidget {
  CacheQueuePage({super.key});

  final controller = Get.put(CacheQueueController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("view_cache_queue".tr),
        titleSpacing: 16,
        actions: [
          IconButton(
            icon: Icon(Icons.play_circle_outline),
            onPressed: () => controller.startAll(),
          ),
          IconButton(
            icon: Icon(Icons.pause_circle_outline),
            onPressed: () => controller.pauseAll(),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline),
            onPressed: () => controller.clearAll(),
          ),
        ],
      ),
      body: Obx(() {
        final list = controller.tasks;
        if (list.isEmpty) return Center(child: Text("no_cache_task".tr));
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (ctx, idx) {
            final t = list[idx];
            return Card.filled(
              child: Column(
                children: [
                  _buildTile(t),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 0,
                    ),
                    child: t.progress >= 0 && t.progress <= 1
                        ? LinearProgressIndicator(value: t.progress)
                        : LinearProgressIndicator(),
                  ),
                ],
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildTile(ChapterCacheTask t) {
    String subtitle = statusToString(t.status).tr;
    if (t.progress >= 0 && t.progress <= 1) {
      subtitle += " · ${(t.progress * 100).toStringAsFixed(0)}%";
    } else if (t.progress == -1) {
      subtitle += " · ${"unknownProgress".tr}";
    }

    return ListTile(
      isThreeLine: true,
      title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text("${"chapter".tr}id:${t.cid}\n$subtitle"),
      trailing: Wrap(
        spacing: 4,
        children: [
          if (t.status == CacheStatus.pending)
            IconButton(
              icon: Icon(Icons.play_arrow),
              onPressed: () => controller.resumeTask(t.uuid),
            ),
          if (t.status == CacheStatus.downloading)
            IconButton(
              icon: Icon(Icons.pause),
              onPressed: () => controller.pauseTask(t.uuid),
            ),
          if (t.status == CacheStatus.failed)
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: () => controller.resumeTask(t.uuid),
            ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () => controller.removeTask(t.uuid),
          ),
        ],
      ),
    );
  }
}
