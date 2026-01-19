import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A widget wrapper that shows a native audio output selector menu when tapped.
///
/// This widget wraps any child widget and makes it tappable to show a native
/// iOS menu with available audio output devices.
///
/// Example:
/// ```dart
/// AudioOutputSelector(
///   child: Icon(Icons.volume_up),
/// )
/// ```
class AudioOutputSelector extends StatelessWidget {
  /// The child widget to wrap. This widget will be tappable to show the menu.
  final Widget child;

  /// Creates an [AudioOutputSelector] widget.
  const AudioOutputSelector({
    super.key,
    required this.child,
  });

  static const MethodChannel _channel =
      MethodChannel('output_route_selector');

  Future<void> _showNativeMenu(BuildContext context) async {
    // Get the position of the widget on screen
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Offset position = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    // Calculate center point of the widget for menu positioning
    final double x = position.dx + (size.width / 2);
    final double y = position.dy + (size.height / 2);

    try {
      await _channel.invokeMethod('showAudioOutputMenu', {
        'x': x,
        'y': y,
      });
    } on PlatformException catch (e) {
      debugPrint('Error showing audio output menu: ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showNativeMenu(context),
      child: child,
    );
  }
}
