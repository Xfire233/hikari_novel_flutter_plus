import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/source_config.dart';
import 'package:hikari_novel_flutter/service/local_storage_service.dart';

class SourceConfigService extends GetxService {
  static SourceConfigService get instance => Get.find<SourceConfigService>();

  final RxMap<NovelSource, SourceSyncConfig> configs =
      <NovelSource, SourceSyncConfig>{}.obs;

  void init() {
    final storage = LocalStorageService.instance;
    if (storage.hasSourceSyncConfigs()) {
      configs.assignAll(storage.getSourceSyncConfigs());
      return;
    }

    configs.assignAll({
      for (final source in NovelSource.values)
        source: SourceSyncConfig.defaults(
          source,
          enabled: _legacySourceEnabled(source),
        ),
    });
    storage.setSourceSyncConfigs(configs);
  }

  bool get hasAnyEnabledSource => configs.values.any((item) => item.enabled);

  List<NovelSource> get enabledSources => NovelSource.values
      .where((source) => configs[source]?.enabled == true)
      .toList();

  SourceSyncConfig configOf(NovelSource source) =>
      configs[source] ?? SourceSyncConfig.defaults(source);

  bool isEnabled(NovelSource source) => configOf(source).enabled;

  bool shouldPullOnlineToLocal(NovelSource source) {
    final config = configOf(source);
    return config.enabled && config.pullOnlineToLocal;
  }

  bool shouldPushLocalToRemote(NovelSource source) {
    final config = configOf(source);
    return config.enabled && config.pushLocalToRemote;
  }

  void setSourceEnabled(NovelSource source, bool enabled) =>
      updateSource(source, configOf(source).copyWith(enabled: enabled));

  void setPullOnlineToLocal(NovelSource source, bool enabled) => updateSource(
    source,
    configOf(source).copyWith(pullOnlineToLocal: enabled),
  );

  void setPushLocalToRemote(NovelSource source, bool enabled) => updateSource(
    source,
    configOf(source).copyWith(pushLocalToRemote: enabled),
  );

  void setRemoteTarget(NovelSource source, String folderId) => updateSource(
    source,
    configOf(source).copyWith(targetRemoteFolderId: folderId),
  );

  void setRemoveRemoteWhenLocalDeleted(NovelSource source, bool enabled) =>
      updateSource(
        source,
        configOf(source).copyWith(removeRemoteWhenLocalDeleted: enabled),
      );

  void updateSource(NovelSource source, SourceSyncConfig config) {
    configs[source] = config;
    LocalStorageService.instance.setSourceSyncConfigs(configs);
  }

  void saveInitialSources(Iterable<NovelSource> sources) {
    final enabled = sources.toSet();
    configs.assignAll({
      for (final source in NovelSource.values)
        source: configOf(source).copyWith(enabled: enabled.contains(source)),
    });
    LocalStorageService.instance.setSourceSyncConfigs(configs);
  }

  bool isLocallyHidden(NovelSource source, String aid) => LocalStorageService
      .instance
      .getSourceLocalHiddenAids(source)
      .contains(aid);

  void hideLocalFavorite(NovelSource source, String aid) {
    final hidden = LocalStorageService.instance.getSourceLocalHiddenAids(
      source,
    );
    hidden.add(aid);
    LocalStorageService.instance.setSourceLocalHiddenAids(source, hidden);
  }

  void restoreLocalFavorite(NovelSource source, String aid) {
    final hidden = LocalStorageService.instance.getSourceLocalHiddenAids(
      source,
    );
    if (!hidden.remove(aid)) return;
    LocalStorageService.instance.setSourceLocalHiddenAids(source, hidden);
  }

  bool _legacySourceEnabled(NovelSource source) {
    final storage = LocalStorageService.instance;
    return switch (source) {
      NovelSource.wenku8 => storage.getCookie() != null,
      NovelSource.esj => storage.getEsjCookie() != null,
      NovelSource.yamibo => storage.getYamiboCookie() != null,
    };
  }
}
