import 'package:flutter/services.dart';
import 'audio_model.dart';

/// Platform service for managing audio output route selection.
class OutputRouteSelector {
  static const MethodChannel _channel =
      MethodChannel('output_route_selector');
  
  static const EventChannel _eventChannel =
      EventChannel('output_route_selector/events');
  
  static Stream<AudioRouteChangeEvent>? _eventStream;

  /// Get the list of available audio output devices.
  ///
  /// Returns a list of [AudioModel] objects representing all available
  /// audio output devices, including their current active state.
  ///
  /// Example:
  /// ```dart
  /// final devices = await OutputRouteSelector.getAvailableAudioOutputs();
  /// for (final device in devices) {
  ///   print('${device.outputName}: ${device.isActive}');
  /// }
  /// ```
  static Future<List<AudioModel>> getAvailableAudioOutputs() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getAvailableAudioOutputs',
      );

      if (result == null) {
        return [];
      }

      return result.map((item) {
        final jsonModel = AudioModel.fromJson(
          Map<String, dynamic>.from(item as Map),
        );
        return jsonModel;
      }).toList();
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Failed to get available audio outputs: ${e.message}',
        details: e.details,
      );
    }
  }

  /// Change the audio output route to the specified device.
  ///
  /// [deviceModel] - The audio device model to switch to. The device's
  /// title will be used to identify which output to activate.
  ///
  /// Throws [PlatformException] if the device is not found or if there's
  /// an error changing the audio route.
  ///
  /// Example:
  /// ```dart
  /// final devices = await OutputRouteSelector.getAvailableAudioOutputs();
  /// final speaker = devices.firstWhere((d) => d.deviceType == AudioDeviceType.speaker);
  /// await OutputRouteSelector.changeAudioOutput(speaker);
  /// ```
  static Future<void> changeAudioOutput(AudioModel deviceModel) async {
    try {
      await _channel.invokeMethod<void>(
        'changeAudioOutput',
        {'deviceTitle': deviceModel.title},
      );
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: 'Failed to change audio output: ${e.message}',
        details: e.details,
      );
    }
  }

  /// Listen to audio route change events.
  ///
  /// Returns a stream of [AudioRouteChangeEvent] objects that notify when
  /// the audio output route changes (e.g., user switches from Control Center,
  /// connects/disconnects Bluetooth device, plugs in headphones).
  ///
  /// Example:
  /// ```dart
  /// OutputRouteSelector.onAudioRouteChanged.listen((event) {
  ///   print('Audio route changed: ${event.reason}');
  ///   if (event.activeDevice != null) {
  ///     print('Active device: ${event.activeDevice!.outputName}');
  ///   }
  /// });
  /// ```
  static Stream<AudioRouteChangeEvent> get onAudioRouteChanged {
    _eventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => AudioRouteChangeEvent.fromMap(
              Map<String, dynamic>.from(event as Map),
            ));
    return _eventStream!;
  }
}

/// Event emitted when the audio route changes.
class AudioRouteChangeEvent {
  /// The event type (always "audioRouteChanged")
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
  final int reason;

  /// The currently active device after the route change (if available)
  final AudioModel? activeDevice;

  AudioRouteChangeEvent({
    required this.event,
    required this.reason,
    this.activeDevice,
  });

  factory AudioRouteChangeEvent.fromMap(Map<String, dynamic> map) {
    AudioModel? device;
    if (map['activeDevice'] != null) {
      device = AudioModel.fromJson(
        Map<String, dynamic>.from(map['activeDevice'] as Map),
      );
    }

    return AudioRouteChangeEvent(
      event: map['event'] as String,
      reason: map['reason'] as int,
      activeDevice: device,
    );
  }

  /// Returns a user-friendly description of the route change reason.
  String get reasonDescription {
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
