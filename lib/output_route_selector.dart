/// A Flutter plugin to select audio output routes on iOS devices.
///
/// This plugin allows you to:
/// - Get a list of available audio output devices (speaker, receiver, bluetooth, wired headset)
/// - Switch between different audio output routes
/// - Check which device is currently active
/// - Show a native iOS menu to select audio output
///
/// Example usage:
/// ```dart
/// import 'package:output_route_selector/output_route_selector.dart';
///
/// // Get available devices
/// final devices = await OutputRouteSelector.getAvailableAudioOutputs();
///
/// // Switch to speaker
/// final speaker = devices.firstWhere((d) => d.deviceType == AudioDeviceType.speaker);
/// await OutputRouteSelector.changeAudioOutput(speaker);
///
/// // Or use the widget wrapper to show native menu
/// AudioOutputSelector(
///   child: Icon(Icons.volume_up),
/// )
/// ```
// ignore: unnecessary_library_name
library output_route_selector;

export 'src/audio_device_type.dart';
export 'src/audio_model.dart';
export 'src/output_route_selector_platform.dart';
export 'src/output_route_selector_widget.dart';
