import 'audio_model.dart';
import 'audio_route_change_source.dart';

/// A single audio route change reported by the native side.
class AudioRouteEvent {
  /// The device that is active after the change. `null` when the native side
  /// could not resolve a device.
  final AudioModel? device;

  /// What caused the change.
  final AudioRouteChangeSource source;

  const AudioRouteEvent({required this.device, required this.source});

  /// Creates an [AudioRouteEvent] from a raw native event map.
  factory AudioRouteEvent.fromJson(Map<String, dynamic> json) {
    final rawDevice = json['activeDevice'];

    return AudioRouteEvent(
      device: rawDevice == null
          ? null
          : AudioModel.fromJson(Map<String, dynamic>.from(rawDevice as Map)),
      source: audioRouteChangeSourceFromString(json['source'] as String?),
    );
  }

  @override
  String toString() => 'AudioRouteEvent(device: $device, source: $source)';
}
