import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// Bounded, memory-only samples for device acceptance runs. No remote analytics.
class PlaybackTelemetry {
  static const _channel = EventChannel('app.social_discovery/playback_metrics');
  final samples = <Map<String, dynamic>>[];
  StreamSubscription<dynamic>? _subscription;
  void start() {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.iOS ||
        _subscription != null) {
      return;
    }
    _subscription = _channel.receiveBroadcastStream().listen((event) {
      samples.add(Map<String, dynamic>.from(event as Map));
      if (samples.length > 500) samples.removeAt(0);
    }, onError: (Object _) {});
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    samples.clear();
  }
}
