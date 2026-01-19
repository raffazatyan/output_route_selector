# Output Route Selector

A Flutter plugin that provides native iOS audio output selection with a system-style UIMenu.

## Features

- **Native UIMenu** - Real iOS system menu with glass/blur effect
- **Automatic device detection** - Speaker, Receiver, Bluetooth, Wired Headset
- **SF Symbols icons** - AirPods, speaker, iPhone, headphones icons
- **Custom Bluetooth icon** - SVG support for non-AirPods devices
- **Real-time events** - Stream notifications when audio route changes
- **Zero Flutter-side management** - All device handling is native

## Installation

```yaml
dependencies:
  output_route_selector: ^1.0.5
```

## iOS Setup

Add to your `Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Required for audio routing</string>
```

Minimum iOS version: **14.0**

## Usage

### 1. Add the Widget

```dart
import 'package:output_route_selector/output_route_selector.dart';

// Simple usage
AudioOutputSelector(
  size: 44,
  child: Icon(Icons.volume_up, size: 24),
)

// With custom dimensions
AudioOutputSelector(
  width: 50,
  height: 50,
  child: Icon(Icons.speaker, size: 30, color: Colors.blue),
)

// With AssetGenImage
AudioOutputSelector(
  size: 44,
  child: Assets.icons.speaker.image(width: 24, height: 24),
)
```

### 2. Listen to Events

```dart
OutputRouteSelector.instance.onAudioRouteChanged.listen((device) {
  if (device != null) {
    print('Active: ${device.outputName}');
    print('Type: ${device.deviceType}');
  }
});
```

## Complete Example

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:output_route_selector/output_route_selector.dart';

class AudioDemo extends StatefulWidget {
  @override
  State<AudioDemo> createState() => _AudioDemoState();
}

class _AudioDemoState extends State<AudioDemo> {
  StreamSubscription<AudioModel?>? _subscription;
  String _currentDevice = 'Unknown';

  @override
  void initState() {
    super.initState();
    _subscription = OutputRouteSelector.instance.onAudioRouteChanged.listen((device) {
      if (device != null) {
        setState(() {
          _currentDevice = device.outputName;
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AudioOutputSelector(
          size: 64,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Icon(Icons.volume_up, size: 32, color: Colors.blue),
          ),
        ),
        SizedBox(height: 16),
        Text('Current: $_currentDevice'),
      ],
    );
  }
}
```

## API Reference

### AudioOutputSelector

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `child` | `Widget` | required | The widget to display as button |
| `width` | `double` | 44 | Button width |
| `height` | `double` | 44 | Button height |
| `size` | `double?` | null | Shorthand for width & height |

### OutputRouteSelector

| Property | Description |
|----------|-------------|
| `instance` | Singleton instance |
| `onAudioRouteChanged` | Stream of `AudioModel?` - the active device |

### AudioModel

| Property | Type | Description |
|----------|------|-------------|
| `title` | `String` | Device identifier |
| `isActive` | `bool` | Whether device is active |
| `deviceType` | `AudioDeviceType` | Type of device |
| `outputName` | `String` | User-friendly name |

### AudioDeviceType

- `speaker` - Built-in speaker
- `receiver` - iPhone earpiece
- `wiredHeadset` - Wired headphones
- `bluetooth` - Bluetooth device

## Menu Icons

| Device | Icon |
|--------|------|
| Speaker | `speaker.wave.2.fill` |
| iPhone | `iphone` |
| Headphones | `headphones` |
| AirPods | `airpodspro` |
| Other Bluetooth | Custom SVG / `hifispeaker.fill` |

## Platform Support

| Platform | Status |
|----------|--------|
| iOS | ✅ Full support (14.0+) |
| Android | ✅ Full support (API 21+) |
| Web | ❌ Not applicable |

## Android Setup

Add to your `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
```

## License

MIT License - see LICENSE file
