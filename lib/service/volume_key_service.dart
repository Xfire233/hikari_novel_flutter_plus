import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class VolumeKeyService {
  static const _channel = EventChannel('hikari/volume_keys');

  static Stream<String> get volumeKeyStream {
    if (!Platform.isAndroid) return const Stream.empty();
    return _channel.receiveBroadcastStream().cast<String>();
  }
}
