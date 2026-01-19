import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A widget that shows native audio output selection menu.
///
/// Uses your custom Flutter widget as the visual, with an invisible native
/// button overlay to handle taps and show the platform-specific menu.
///
/// **Platforms:**
/// - **iOS**: Shows UIMenu with glass/blur effect (iOS 14+ style)
/// - **Android**: Shows MediaRouteChooserDialog for audio output selection
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
  /// On Android, this renders your [child] widget with an invisible native
  /// View overlay that shows MediaRouteChooserDialog when tapped.
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

    // Use PlatformView on iOS for real UIMenu support
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

    // Use PlatformView on Android for MediaRouteChooserDialog
    if (Platform.isAndroid) {
      return SizedBox(
        width: effectiveWidth,
        height: effectiveHeight,
        child: Stack(
          children: [
            // Flutter widget (your icon/image)
            Positioned.fill(child: Center(child: child)),
            // Invisible native view overlay for dialog trigger
            Positioned.fill(
              child: AndroidView(
                viewType: 'audio_output_button',
                creationParams: {
                  'width': effectiveWidth,
                  'height': effectiveHeight,
                },
                creationParamsCodec: const StandardMessageCodec(),
              ),
            ),
          ],
        ),
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
