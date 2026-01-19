# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.4] - 2026-01-19

### Added
- Custom SVG icon support for Bluetooth devices
- Smart icon detection: AirPods use SF Symbol, other Bluetooth devices use custom bluetooth_speaker.svg
- Asset catalog with bluetooth_speaker icon

### Changed
- Bluetooth devices now show appropriate icons based on device name

## [1.0.3] - 2026-01-19

### Added
- Native PlatformView implementation for real UIMenu support
- System-style glass menu with SF Symbols icons and checkmarks
- Support for custom Flutter widgets as button icons (Icon, Image, AssetGenImage)
- Separate `width` and `height` parameters, plus `size` shorthand

### Fixed
- Added @available(iOS 14.0, *) annotation to support iOS 14.0+
- Fixed Logger availability issue
- Fixed UIMenu not opening (now uses real UIKit button with PlatformView)

### Changed
- Minimum iOS version set to 14.0
- AudioOutputSelector now uses transparent native button overlay for proper UIMenu presentation
- Improved topViewController detection for modal scenarios

## [1.0.2] - 2026-01-19

### Changed
- Minimum iOS version updated to 15.0 (was 12.0)

## [1.0.1] - 2026-01-19

### Fixed
- Fixed native menu not appearing when tapping AudioOutputSelector widget
- Changed from UIMenu to UIAlertController for reliable menu presentation
- Added proper iPad support with popover positioning

## [1.0.0] - 2026-01-19

### Added
- Initial release
- iOS support for audio output route selection
- Support for Speaker, Receiver, Wired Headset, and Bluetooth devices
- `getAvailableAudioOutputs()` method to get all available audio devices
- `changeAudioOutput()` method to switch between audio outputs
- `onAudioRouteChanged` stream to listen for real-time route changes
- `AudioOutputSelector` widget - Native iOS UIMenu widget for easy audio output selection
- `AudioModel` class with device information
- `AudioDeviceType` enum for device types
- `AudioRouteChangeEvent` class for route change notifications
- Extension methods for user-friendly device names
- Automatic detection of route changes from Control Center, Dynamic Island, and device connect/disconnect
- Smart retry mechanism (3 attempts with increasing delays) to ensure route changes are properly detected
- Automatic refresh of outputs after every route change
- Native iOS menu with checkmarks for active devices
- Comprehensive error handling with PlatformException
- Full documentation and examples with event listening and widget usage
