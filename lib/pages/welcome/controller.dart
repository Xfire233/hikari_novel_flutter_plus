import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/common/wenku8_node.dart';
import 'package:hikari_novel_flutter/models/source_config.dart';
import 'package:hikari_novel_flutter/router/route_path.dart';
import 'package:hikari_novel_flutter/service/local_storage_service.dart';
import 'package:hikari_novel_flutter/service/source_config_service.dart';

class WelcomeController extends GetxController {
  Wenku8Node wenku8Node = LocalStorageService.instance.getWenku8Node();
  final RxList<NovelSource> selectedSources =
      SourceConfigService.instance.enabledSources.obs;

  bool get hasSelectedSource => selectedSources.isNotEmpty;

  void changeWenku8Node(Wenku8Node n) {
    wenku8Node = n;
    LocalStorageService.instance.setWenku8Node(n);
  }

  bool isSourceSelected(NovelSource source) => selectedSources.contains(source);

  void toggleSource(NovelSource source, bool selected) {
    if (selected) {
      if (!selectedSources.contains(source)) selectedSources.add(source);
    } else {
      selectedSources.remove(source);
    }
  }

  void startApp() {
    if (!hasSelectedSource) return;
    SourceConfigService.instance.saveInitialSources(selectedSources);
    Get.offAllNamed(RoutePath.main);
  }
}
