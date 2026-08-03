import 'package:flutter/services.dart';

import 'audio_model.dart';
import 'audio_route_event.dart';
import 'output_route_middleware.dart';

/// Method channel shared by the Android picker dialog and the route-control
/// API available on both platforms.
const MethodChannel outputRouteSelectorMethodChannel = MethodChannel(
  'output_route_selector/methods',
);

/// Platform service for listening to audio output route changes.
///
/// This class provides a stream of the currently active audio device.
/// All audio output selection is handled natively via the `AudioOutputSelector`
/// widget; [selectAudioOutput] switches the route without opening the picker.
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

  Stream<AudioRouteEvent>? _routeEventStream;
  Stream<AudioModel?>? _eventStream;

  /// Listen to audio route changes together with what caused them.
  ///
  /// Unlike [onAudioRouteChanged], this stream also emits events whose
  /// [AudioRouteEvent.device] is `null`, and exposes
  /// [AudioRouteEvent.source] so a user selection can be told apart from a
  /// system-driven change.
  Stream<AudioRouteEvent> get onAudioRouteEvent {
    _routeEventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map(
          (event) =>
              AudioRouteEvent.fromJson(Map<String, dynamic>.from(event as Map)),
        )
        .asBroadcastStream();

    return _routeEventStream!;
  }

  /// Listen to audio route changes — the route the UI should show.
  ///
  /// Backed by [OutputRouteMiddleware]: listening to this stream starts the
  /// guard that keeps a user's pick alive across call state changes, and
  /// cancelling the last subscription stops it.
  ///
  /// While a pick is being defended, the transient drops caused by a call SDK
  /// reconfiguring the audio session are **not** emitted — the UI keeps showing
  /// the picked device instead of flickering to receiver and back. If the pick
  /// cannot be held, the real route is emitted so the UI stops lying, and the
  /// outcome of every attempt is available on
  /// `OutputRouteMiddleware.instance.onEnforcement`.
  ///
  /// Use [onAudioRouteEvent] or [rawAudioRouteChanged] for the unfiltered feed.
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
  Stream<AudioModel?> get onAudioRouteChanged =>
      OutputRouteMiddleware.instance.effectiveRoute;

  /// Every route change reported by the platform, unfiltered — including the
  /// transient drops that [onAudioRouteChanged] hides.
  Stream<AudioModel?> get rawAudioRouteChanged {
    _eventStream ??= onAudioRouteEvent
        .map((event) => event.device)
        .where((device) => device != null); // Filter out nulls

    return _eventStream!;
  }

  /// Reads the active device straight from the native audio session, without
  /// waiting for an event.
  Future<AudioModel?> getCurrentRoute() async {
    final result = await outputRouteSelectorMethodChannel
        .invokeMapMethod<String, dynamic>('getCurrentRoute');

    if (result == null) {
      return null;
    }

    return AudioModel.fromJson(result);
  }

  /// Switches the output route programmatically, without opening the native
  /// picker.
  ///
  /// [title] must match a device title reported by this plugin: `speaker`,
  /// `receiver`, `wiredHeadset`, or a Bluetooth device name. [deviceType] is
  /// used by Android to pick the switching strategy; iOS derives it from
  /// [title].
  ///
  /// Returns the device that is actually active after the switch — the OS can
  /// refuse one (e.g. receiver while headphones are plugged in), so the result
  /// may differ from what was requested.
  Future<AudioModel?> selectAudioOutput({
    required String title,
    String? deviceType,
  }) async {
    final result = await outputRouteSelectorMethodChannel
        .invokeMapMethod<String, dynamic>('selectAudioOutput', {
          'title': title,
          if (deviceType != null) 'deviceType': deviceType,
        });

    if (result == null) {
      return null;
    }

    return AudioModel.fromJson(result);
  }
}
