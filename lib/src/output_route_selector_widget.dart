import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Method channel for communicating with native Android code.
const _methodChannel = MethodChannel('output_route_selector/methods');

/// A widget that shows native audio output selection menu.
///
/// Wrap any widget with [AudioOutputSelector] and it will show a native
/// audio output picker when tapped. The widget automatically takes the
/// size of its child.
///
/// **Platforms:**
/// - **iOS**: Shows UIMenu with glass/blur effect (iOS 14+ style)
/// - **Android**: Shows popup dialog with theme support
///
/// Example:
/// ```dart
/// AudioOutputSelector(
///   child: Icon(Icons.speaker, size: 24),
/// )
/// ```
///
/// With AssetGenImage:
/// ```dart
/// AudioOutputSelector(
///   child: Assets.icons.speaker.image(width: 24, height: 24),
/// )
/// ```
class AudioOutputSelector extends StatefulWidget {
  /// The widget to display as the button.
  /// Can be Icon, Image, Container, or any other widget.
  /// The selector will automatically take the size of this widget.
  final Widget child;

  const AudioOutputSelector({super.key, required this.child});

  @override
  State<AudioOutputSelector> createState() => _AudioOutputSelectorState();
}

class _AudioOutputSelectorState extends State<AudioOutputSelector> {
  /// Measured size of the child widget. Null until first frame renders.
  Size? _childSize;

  /// Key used to find and measure the child widget's RenderBox.
  final GlobalKey _childKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Schedule measurement after the first frame is rendered.
    // This ensures the child widget has been laid out and has a size.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureChild());
  }

  /// Measures the child widget's size using its RenderBox.
  /// Called after the first frame to get actual rendered dimensions.
  void _measureChild() {
    // Get the RenderBox from the child's context using the GlobalKey.
    final renderBox =
        _childKey.currentContext?.findRenderObject() as RenderBox?;

    // Only update if we got a valid RenderBox with a size.
    if (renderBox != null && renderBox.hasSize) {
      setState(() {
        // Store the measured size for building the platform-specific widget.
        _childSize = renderBox.size;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // First render: show child with GlobalKey to measure its size.
    // After measurement, _childSize will be set and we'll rebuild.
    if (_childSize == null) {
      return KeyedSubtree(key: _childKey, child: widget.child);
    }

    // Extract measured dimensions.
    final width = _childSize!.width;
    final height = _childSize!.height;

    // iOS: Use UiKitView (PlatformView) for native UIMenu support.
    // UIMenu requires a real UIButton which can't be created from Flutter.
    if (Platform.isIOS) {
      return SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            // Bottom layer: Flutter child widget (visible to user).
            Positioned.fill(child: Center(child: widget.child)),

            // Top layer: Invisible native UIButton that captures taps
            // and shows the UIMenu. Must be on top to receive touches.
            Positioned.fill(
              child: UiKitView(
                // Registered view type in iOS plugin.
                viewType: 'audio_output_button',
                // Pass size to native side for proper hit testing.
                creationParams: {
                  'width': width,
                  'height': height,
                  'transparent':
                      true, // Button is invisible, child shows through.
                },
                creationParamsCodec: const StandardMessageCodec(),
              ),
            ),
          ],
        ),
      );
    }

    // Android: Use GestureDetector + MethodChannel.
    // Android doesn't need PlatformView - we just call native code to show dialog.
    if (Platform.isAndroid) {
      return _AndroidAudioOutputSelector(
        width: width,
        height: height,
        child: widget.child,
      );
    }

    // Fallback for unsupported platforms: just show the child.
    return widget.child;
  }
}

/// Android-specific implementation that shows native popup dialog.
/// Uses MethodChannel to call Kotlin code that displays the dialog.
class _AndroidAudioOutputSelector extends StatefulWidget {
  /// Width of the touch area.
  final double width;

  /// Height of the touch area.
  final double height;

  /// The widget to display.
  final Widget child;

  const _AndroidAudioOutputSelector({
    required this.width,
    required this.height,
    required this.child,
  });

  @override
  State<_AndroidAudioOutputSelector> createState() =>
      _AndroidAudioOutputSelectorState();
}

class _AndroidAudioOutputSelectorState
    extends State<_AndroidAudioOutputSelector> {
  /// Key used to find widget's position on screen.
  final GlobalKey _key = GlobalKey();

  @override
  void dispose() {
    // Close the dialog when widget is disposed (e.g., screen popped).
    _methodChannel.invokeMethod('dismissAudioOutputDialog');
    super.dispose();
  }

  /// Shows the native Android audio output dialog.
  /// Calculates widget position and passes it to native code
  /// so the dialog can appear near the button.
  void _showDialog() {
    // Get the RenderBox to find position on screen.
    final RenderBox? renderBox =
        _key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    // Convert local position (0,0) to global screen coordinates.
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    // Call native Kotlin code to show the dialog.
    // Pass position and size so dialog appears near the button.
    _methodChannel.invokeMethod('showAudioOutputDialog', {
      'x': position.dx.toInt(), // X position on screen.
      'y': position.dy.toInt(), // Y position on screen.
      'width': size.width.toInt(), // Widget width for positioning.
      'height': size.height.toInt(), // Widget height for positioning.
    });
  }

  @override
  Widget build(BuildContext context) {
    // GestureDetector captures taps and calls _showDialog.
    return GestureDetector(
      key: _key, // Key for finding position.
      onTap: _showDialog, // Show native dialog on tap.
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Center(child: widget.child),
      ),
    );
  }
}
