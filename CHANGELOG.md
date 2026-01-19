# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
