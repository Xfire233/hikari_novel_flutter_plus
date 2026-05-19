enum NovelSource {
  wenku8,
  esj,
  yamibo;

  String get id => name;

  String get titleKey => switch (this) {
    NovelSource.wenku8 => 'wenku8',
    NovelSource.esj => 'esjzone',
    NovelSource.yamibo => 'yamibo_forum',
  };
}

class SourceSyncConfig {
  final NovelSource source;
  final bool enabled;
  final bool pullOnlineToLocal;
  final bool pushLocalToRemote;
  final String targetRemoteFolderId;
  final bool removeRemoteWhenLocalDeleted;

  const SourceSyncConfig({
    required this.source,
    required this.enabled,
    required this.pullOnlineToLocal,
    required this.pushLocalToRemote,
    required this.targetRemoteFolderId,
    required this.removeRemoteWhenLocalDeleted,
  });

  factory SourceSyncConfig.defaults(
    NovelSource source, {
    bool enabled = false,
  }) {
    return SourceSyncConfig(
      source: source,
      enabled: enabled,
      pullOnlineToLocal: true,
      pushLocalToRemote: false,
      targetRemoteFolderId: switch (source) {
        NovelSource.wenku8 => '0',
        NovelSource.esj => 'default',
        NovelSource.yamibo => 'default',
      },
      removeRemoteWhenLocalDeleted: false,
    );
  }

  factory SourceSyncConfig.fromJson(Map<dynamic, dynamic> json) {
    final source = NovelSource.values.firstWhere(
      (item) => item.id == '${json['source']}',
      orElse: () => NovelSource.wenku8,
    );
    final fallback = SourceSyncConfig.defaults(source);
    return SourceSyncConfig(
      source: source,
      enabled: json['enabled'] is bool
          ? json['enabled'] as bool
          : fallback.enabled,
      pullOnlineToLocal: json['pullOnlineToLocal'] is bool
          ? json['pullOnlineToLocal'] as bool
          : fallback.pullOnlineToLocal,
      pushLocalToRemote: json['pushLocalToRemote'] is bool
          ? json['pushLocalToRemote'] as bool
          : fallback.pushLocalToRemote,
      targetRemoteFolderId:
          '${json['targetRemoteFolderId'] ?? fallback.targetRemoteFolderId}',
      removeRemoteWhenLocalDeleted: json['removeRemoteWhenLocalDeleted'] is bool
          ? json['removeRemoteWhenLocalDeleted'] as bool
          : fallback.removeRemoteWhenLocalDeleted,
    );
  }

  Map<String, dynamic> toJson() => {
    'source': source.id,
    'enabled': enabled,
    'pullOnlineToLocal': pullOnlineToLocal,
    'pushLocalToRemote': pushLocalToRemote,
    'targetRemoteFolderId': targetRemoteFolderId,
    'removeRemoteWhenLocalDeleted': removeRemoteWhenLocalDeleted,
  };

  SourceSyncConfig copyWith({
    bool? enabled,
    bool? pullOnlineToLocal,
    bool? pushLocalToRemote,
    String? targetRemoteFolderId,
    bool? removeRemoteWhenLocalDeleted,
  }) {
    return SourceSyncConfig(
      source: source,
      enabled: enabled ?? this.enabled,
      pullOnlineToLocal: pullOnlineToLocal ?? this.pullOnlineToLocal,
      pushLocalToRemote: pushLocalToRemote ?? this.pushLocalToRemote,
      targetRemoteFolderId: targetRemoteFolderId ?? this.targetRemoteFolderId,
      removeRemoteWhenLocalDeleted:
          removeRemoteWhenLocalDeleted ?? this.removeRemoteWhenLocalDeleted,
    );
  }
}
