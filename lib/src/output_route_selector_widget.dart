import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _methodChannel = MethodChannel('output_route_selector/methods');

/// A widget that shows native audio output selection menu.
///
/// Uses your custom Flutter widget as the visual, with native menu on tap.
///
/// **Platforms:**
/// - **iOS**: Shows UIMenu with glass/blur effect (iOS 14+ style)
/// - **Android**: Shows WhatsApp-style bottom sheet dialog
///
/// **Key Features:**
/// - Use any Flutter widget as the icon (Icon, Image, AssetGenImage, etc.)
/// - Native system dialogs on both platforms
/// - Shows checkmarks for active audio output
/// - Automatically updates when audio route changes
///
/// Example:
/// ```dart
/// AudioOutputSelector(
///   width: 24,
///   height: 24,
///   child: Icon(Icons.speaker, size: 24),
/// )
/// ```
///
/// With AssetGenImage:
/// ```dart
/// AudioOutputSelector(
///   width: 24,
///   height: 24,
///   child: Assets.icons.speaker.image(width: 24, height: 24),
/// )
/// ```
class AudioOutputSelector extends StatelessWidget {
  /// The widget to display as the button icon.
  /// Can be Icon, Image, AssetGenImage, or any other widget.
  final Widget child;

  /// Width of the button. Default is 44.
  final double width;

  /// Height of the button. Default is 44.
  final double height;

  /// Shorthand for setting both width and height.
  /// If provided, overrides [width] and [height].
  final double? size;

  /// Creates an [AudioOutputSelector] widget.
  ///
  /// On iOS, this renders your [child] widget with an invisible native
  /// UIButton overlay that shows the UIMenu when tapped.
  ///
  /// On Android, this renders your [child] widget that shows native dialog on tap.
  ///
  /// On other platforms, it displays the [child] widget without menu functionality.
  const AudioOutputSelector({
    super.key,
    required this.child,
    this.width = 44,
    this.height = 44,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = size ?? width;
    final effectiveHeight = size ?? height;

    // Use PlatformView on iOS for real UIMenu support (required for App Store)
    if (Platform.isIOS) {
      return SizedBox(
        width: effectiveWidth,
        height: effectiveHeight,
        child: Stack(
          children: [
            // Flutter widget (your icon/image)
            Positioned.fill(child: Center(child: child)),
            // Invisible native button overlay for UIMenu
            Positioned.fill(
              child: UiKitView(
                viewType: 'audio_output_button',
                creationParams: {
                  'width': effectiveWidth,
                  'height': effectiveHeight,
                  'transparent': true,
                },
                creationParamsCodec: const StandardMessageCodec(),
              ),
            ),
          ],
        ),
      );
    }

    // On Android, use GestureDetector + MethodChannel (simpler, no PlatformView needed)
    if (Platform.isAndroid) {
      return _AndroidAudioOutputSelector(
        width: effectiveWidth,
        height: effectiveHeight,
        child: child,
      );
    }

    // Fallback for other platforms
    return SizedBox(
      width: effectiveWidth,
      height: effectiveHeight,
      child: Center(child: child),
    );
  }
}

/// Android-specific widget that handles positioning correctly
class _AndroidAudioOutputSelector extends StatefulWidget {
  final double width;
  final double height;
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
  final GlobalKey _key = GlobalKey();

  void _showDialog() {
    final RenderBox? renderBox =
        _key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _methodChannel.invokeMethod('showAudioOutputDialog', {
      'x': position.dx.toInt(),
      'y': position.dy.toInt(),
      'width': size.width.toInt(),
      'height': size.height.toInt(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _key,
      onTap: _showDialog,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Center(child: widget.child),
      ),
    );
  }
}
