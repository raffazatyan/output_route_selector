import 'package:flutter/services.dart';
import 'audio_model.dart';

/// Platform service for listening to audio output route changes.
///
/// This class provides a stream of the currently active audio device.
/// All audio output selection is handled natively via the [AudioOutputSelector] widget.
///
/// Usage:
/// ```dart
/// OutputRouteSelector.instance.onAudioRouteChanged.listen((device) {
///   if (device != null) {
///     print('Active device: ${device.outputName}');
///   }
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

  Stream<AudioModel?>? _eventStream;

  /// Listen to audio route change events.
  ///
  /// Returns a stream of [AudioModel] representing the currently active
  /// audio device. Returns `null` if no device info is available.
  ///
  /// Example:
  /// ```dart
  /// OutputRouteSelector.instance.onAudioRouteChanged.listen((device) {
  ///   if (device != null) {
  ///     print('Active: ${device.outputName}');
  ///     print('Type: ${device.deviceType}');
  ///   }
  /// });
  /// ```
  Stream<AudioModel?> get onAudioRouteChanged {
    _eventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) {
          final map = Map<String, dynamic>.from(event as Map);

          // Only return AudioModel if activeDevice is present
          if (map['activeDevice'] != null) {
            return AudioModel.fromJson(
              Map<String, dynamic>.from(map['activeDevice'] as Map),
            );
          }
          return null;
        })
        .where((device) => device != null); // Filter out nulls

    return _eventStream!;
  }
}
