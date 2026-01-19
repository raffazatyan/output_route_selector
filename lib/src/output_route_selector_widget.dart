import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A widget that shows native iOS system-style audio output selection menu.
///
/// Uses your custom Flutter widget as the visual, with an invisible native
/// UIButton overlay to handle taps and show the real UIMenu.
///
/// **Key Features:**
/// - Use any Flutter widget as the icon (Icon, Image, AssetGenImage, etc.)
/// - Real UIMenu with glass/blur effect (iOS 14+ style)
/// - Shows checkmarks for active audio output
/// - SF Symbols icons in the menu for each device type
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
                  'transparent': true, // No visible icon, just tap handler
                },
                creationParamsCodec: const StandardMessageCodec(),
              ),
            ),
          ],
        ),
      );
    }

    // Fallback for non-iOS platforms
    return SizedBox(
      width: effectiveWidth,
      height: effectiveHeight,
      child: Center(child: child),
    );
  }
}

/// Legacy widget that uses MethodChannel approach.
///
/// **Note:** This approach cannot show the native UIMenu because UIMenu
/// requires a real user tap on a UIKit view. Use [AudioOutputSelector] instead.
@Deprecated('Use AudioOutputSelector instead for proper UIMenu support')
class AudioOutputSelectorLegacy extends StatelessWidget {
  /// The child widget to wrap.
  final Widget child;

  /// Creates an [AudioOutputSelectorLegacy] widget.
  const AudioOutputSelectorLegacy({super.key, required this.child});

  static const MethodChannel _channel = MethodChannel('output_route_selector');

  Future<void> _showNativeMenu(BuildContext context) async {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Offset position = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    final double x = position.dx + (size.width / 2);
    final double y = position.dy + (size.height / 2);

    try {
      await _channel.invokeMethod('showAudioOutputMenu', {'x': x, 'y': y});
    } on PlatformException catch (e) {
      debugPrint('Error showing audio output menu: ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: () => _showNativeMenu(context), child: child);
  }
}
