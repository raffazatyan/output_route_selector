# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-01-19

### Added
- **Android support!** Full audio output selection on Android
- MediaRouteChooserDialog for native Android audio output selection
- Bluetooth, speaker, receiver, and wired headset support on Android
- PlatformView implementation for Android (same API as iOS)

### Changed
- Updated description to include Android support

## [1.0.9] - 2026-01-19

### Fixed
- Fixed Swift syntax error (missing closing brace)

## [1.0.8] - 2026-01-19

### Fixed
- Event now fires only after successful route change from native menu
- Removed duplicate/unnecessary events (audioOutputsRefreshed)
- Events without activeDevice are now filtered out
- Single event per route change with AudioModel

## [1.0.7] - 2026-01-19

### Changed
- Simplified event stream: now returns `AudioModel?` instead of `AudioRouteChangeEvent`
- Removed `AudioRouteChangeEvent` class - no longer needed
- Stream filters out null events automatically
- Cleaner API: just get the active device directly

## [1.0.6] - 2026-01-19

### Changed
- `OutputRouteSelector` now uses singleton pattern: `OutputRouteSelector.instance`
- Updated API: `OutputRouteSelector.instance.onAudioRouteChanged`

## [1.0.5] - 2026-01-19

### Changed
- **Breaking:** Removed `getAvailableAudioOutputs()` and `changeAudioOutput()` methods
- All device management now handled natively via `AudioOutputSelector` widget
- Flutter only receives events via `onAudioRouteChanged` stream
- Simplified API - just add widget and listen to events
- Removed deprecated `AudioOutputSelectorLegacy` widget
- Cleaned up unused MethodChannel handlers

### Improved
- Simplified README with cleaner examples
- Better documentation

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
