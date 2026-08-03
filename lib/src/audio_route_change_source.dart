/// Where an audio route change came from.
enum AudioRouteChangeSource {
  /// User picked a device in the native menu (iOS UIMenu) or dialog (Android).
  ///
  /// Only these selections become a pending selection that can be re-applied
  /// later — a system change must never overwrite the user's intent.
  userSelection,

  /// The OS changed the route: device plugged/unplugged, Control Center,
  /// Dynamic Island, or another audio engine (e.g. a call SDK) reconfiguring
  /// the session on connect.
  system,

  /// First snapshot pushed right after the event stream is listened to.
  initial,

  /// Result of re-applying the pending selection.
  pendingRestore,
}

/// Parses the `source` field of a native event payload.
AudioRouteChangeSource audioRouteChangeSourceFromString(String? value) {
  return switch (value) {
    'userSelection' => AudioRouteChangeSource.userSelection,
    'initial' => AudioRouteChangeSource.initial,
    'pendingRestore' => AudioRouteChangeSource.pendingRestore,
    _ => AudioRouteChangeSource.system,
  };
}

/// Serializes a source for the native side.
String audioRouteChangeSourceToString(AudioRouteChangeSource source) {
  return switch (source) {
    AudioRouteChangeSource.userSelection => 'userSelection',
    AudioRouteChangeSource.system => 'system',
    AudioRouteChangeSource.initial => 'initial',
    AudioRouteChangeSource.pendingRestore => 'pendingRestore',
  };
}
