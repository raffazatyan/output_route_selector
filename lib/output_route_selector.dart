/// A Flutter plugin to select audio output routes on iOS devices.
///
/// This plugin provides a native iOS UIMenu for audio output selection.
/// All device management is handled natively - Flutter only receives events.
///
/// ## Usage
///
/// 1. Add the [AudioOutputSelector] widget where you want the audio button:
/// ```dart
/// AudioOutputSelector(
///   size: 44,
///   child: Icon(Icons.volume_up),
/// )
/// ```
///
/// 2. Listen to audio route changes:
/// ```dart
/// OutputRouteSelector.instance.onAudioRouteChanged.listen((device) {
///   if (device != null) {
///     print('Active device: ${device.outputName}');
///   }
/// });
/// ```
///
/// That's it! The native menu shows all available devices with proper icons
/// and checkmarks. Device switching is handled automatically.
// ignore: unnecessary_library_name
library output_route_selector;

export 'src/audio_device_type.dart';
export 'src/audio_model.dart';
export 'src/output_route_selector_platform.dart';
export 'src/output_route_selector_widget.dart';
