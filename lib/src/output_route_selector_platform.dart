import 'package:flutter/services.dart';
import 'audio_model.dart';

/// Platform service for listening to audio output route changes.
///
/// This class provides a stream of events when the audio output route changes.
/// All audio output selection is handled natively via the [AudioOutputSelector] widget.
///
/// Usage:
/// ```dart
/// OutputRouteSelector.instance.onAudioRouteChanged.listen((event) {
///   print('Active device: ${event.activeDevice?.outputName}');
/// });
/// ```
class OutputRouteSelector {
  /// Singleton instance
  static final OutputRouteSelector instance = OutputRouteSelector._();

  /// Private constructor
  OutputRouteSelector._();

  final EventChannel _eventChannel = const EventChannel(
    'output_route_selector/events',
  );

  Stream<AudioRouteChangeEvent>? _eventStream;

  /// Listen to audio route change events.
  ///
  /// Returns a stream of [AudioRouteChangeEvent] objects that notify when
  /// the audio output route changes (e.g., user selects from native menu,
  /// connects/disconnects Bluetooth device, plugs in headphones).
  ///
  /// Example:
  /// ```dart
  /// OutputRouteSelector.instance.onAudioRouteChanged.listen((event) {
  ///   print('Audio route changed: ${event.reasonDescription}');
  ///   if (event.activeDevice != null) {
  ///     print('Active device: ${event.activeDevice!.outputName}');
  ///   }
  /// });
  /// ```
  Stream<AudioRouteChangeEvent> get onAudioRouteChanged {
    _eventStream ??= _eventChannel.receiveBroadcastStream().map(
      (event) => AudioRouteChangeEvent.fromMap(
        Map<String, dynamic>.from(event as Map),
      ),
    );
    return _eventStream!;
  }
}

/// Event emitted when the audio route changes.
class AudioRouteChangeEvent {
  /// The event type (e.g., "audioRouteChanged", "audioOutputsRefreshed")
  final String event;

  /// The reason for the route change (iOS AVAudioSession.RouteChangeReason)
  /// Common values:
  /// - 1: Unknown
  /// - 2: New device available
  /// - 3: Old device unavailable
  /// - 4: Category change
  /// - 5: Override
  /// - 6: Wake from sleep
  /// - 7: No suitable route for category
  /// - 8: Route configuration change
  final int? reason;

  /// The currently active device after the route change (if available)
  final AudioModel? activeDevice;

  AudioRouteChangeEvent({required this.event, this.reason, this.activeDevice});

  factory AudioRouteChangeEvent.fromMap(Map<String, dynamic> map) {
    AudioModel? device;
    if (map['activeDevice'] != null) {
      device = AudioModel.fromJson(
        Map<String, dynamic>.from(map['activeDevice'] as Map),
      );
    }

    return AudioRouteChangeEvent(
      event: map['event'] as String,
      reason: map['reason'] as int?,
      activeDevice: device,
    );
  }

  /// Returns a user-friendly description of the route change reason.
  String get reasonDescription {
    if (reason == null) return 'Refresh';

    switch (reason) {
      case 1:
        return 'Unknown';
      case 2:
        return 'New device available';
      case 3:
        return 'Old device unavailable';
      case 4:
        return 'Category change';
      case 5:
        return 'Override';
      case 6:
        return 'Wake from sleep';
      case 7:
        return 'No suitable route for category';
      case 8:
        return 'Route configuration change';
      default:
        return 'Unknown ($reason)';
    }
  }

  @override
  String toString() {
    return 'AudioRouteChangeEvent(event: $event, reason: $reasonDescription, activeDevice: $activeDevice)';
  }
}
