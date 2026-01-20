# Changelog

## [2.0.0] - 2026-01-20

### Added
- Auto-sizing: Widget automatically takes the size of its child (no need to specify width/height)
- Initial audio state: Sends current audio route immediately when stream is subscribed
- Live dialog updates: Android dialog updates in real-time when devices connect/disconnect
- Theme support: Android dialog adapts to Light/Dark mode
- `AudioDeviceType.airpods`: New device type for AirPods (detected by name)
- Auto-dismiss: Android dialog closes when widget is disposed (e.g., screen popped)

### Changed
- Simplified API: Only `child` parameter required, size is automatic
- Improved Android dialog positioning and styling

### Fixed
- Android: Dialog now updates when Bluetooth devices connect/disconnect while open
- Android: Correct audio route reported after device disconnection
- Android: Dialog closes properly when navigating away from screen
