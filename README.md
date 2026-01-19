# output_route_selector

A Flutter plugin to select and manage audio output routes on iOS devices. Supports speaker, receiver (earpiece), wired headsets, and Bluetooth devices.

## Features

- 🔊 Get a list of all available audio output devices
- 🔄 Switch between different audio outputs programmatically
- ✅ Check which device is currently active
- 🎧 Support for Speaker, Receiver (iPhone), Wired Headset, and Bluetooth devices
- 📡 **Real-time audio route change events** - Listen to route changes from Control Center, Dynamic Island, device connect/disconnect
- 🎯 **Native iOS menu widget** - Show a native UIMenu to select audio output with a simple tap
- 📱 iOS-only (macOS support coming soon)

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  output_route_selector: ^1.0.0
```

Then run:

```bash
flutter pub get
```

## iOS Setup

No additional setup required! The plugin works out of the box on iOS 12.0+.

## Usage

### Import the package

```dart
import 'package:output_route_selector/output_route_selector.dart';
```

### Get available audio outputs

```dart
final devices = await OutputRouteSelector.getAvailableAudioOutputs();

for (final device in devices) {
  print('Device: ${device.outputName}');
  print('Type: ${device.deviceType}');
  print('Active: ${device.isActive}');
  print('---');
}
```

### Switch to a specific audio output

```dart
// Get available devices
final devices = await OutputRouteSelector.getAvailableAudioOutputs();

// Switch to speaker
final speaker = devices.firstWhere(
  (d) => d.deviceType == AudioDeviceType.speaker
);
await OutputRouteSelector.changeAudioOutput(speaker);

// Switch to Bluetooth device
final bluetooth = devices.firstWhere(
  (d) => d.deviceType == AudioDeviceType.bluetooth
);
await OutputRouteSelector.changeAudioOutput(bluetooth);
```

### Check device type

```dart
final devices = await OutputRouteSelector.getAvailableAudioOutputs();

for (final device in devices) {
  switch (device.deviceType) {
    case AudioDeviceType.speaker:
      print('Built-in speaker');
      break;
    case AudioDeviceType.receiver:
      print('iPhone receiver (earpiece)');
      break;
    case AudioDeviceType.wiredHeadset:
      print('Wired headset or headphones');
      break;
    case AudioDeviceType.bluetooth:
      print('Bluetooth device: ${device.title}');
      break;
  }
}
```

### Use extensions for convenience

```dart
final devices = await OutputRouteSelector.getAvailableAudioOutputs();

for (final device in devices) {
  // Get user-friendly name
  print(device.outputName); // "iPhone" instead of "receiver" on iOS
  
  // Check if device is external (wired or bluetooth)
  if (device.hasOtherConnection) {
    print('External device connected: ${device.outputName}');
  }
}
```

### Show native iOS menu (Easiest way!)

```dart
import 'package:output_route_selector/output_route_selector.dart';

// Wrap any widget to make it show the native audio output menu
AudioOutputSelector(
  child: IconButton(
    icon: Icon(Icons.volume_up),
    onPressed: null, // No need - wrapper handles tap
  ),
)

// Or with a custom widget
AudioOutputSelector(
  child: Container(
    padding: EdgeInsets.all(12),
    child: Row(
      children: [
        Icon(Icons.speaker),
        SizedBox(width: 8),
        Text('Audio Output'),
      ],
    ),
  ),
)
```

The native menu automatically:
- Shows all available audio outputs
- Indicates which output is currently active (checkmark)
- Closes after selection
- Updates in real-time when devices connect/disconnect

### Listen to audio route changes

```dart
// Subscribe to route change events
final subscription = OutputRouteSelector.onAudioRouteChanged.listen((event) {
  print('Audio route changed: ${event.reasonDescription}');
  
  if (event.activeDevice != null) {
    print('Now playing on: ${event.activeDevice!.outputName}');
  }
  
  // Reload devices if needed
  final devices = await OutputRouteSelector.getAvailableAudioOutputs();
  setState(() {
    _devices = devices;
  });
});

// Don't forget to cancel when done
subscription.cancel();
```

**Route change reasons:**
- User switches output from Control Center or Dynamic Island
- Bluetooth device connects/disconnects
- Wired headphones plugged in/unplugged
- System category changes

**Retry mechanism:**
The plugin uses a smart retry mechanism (3 attempts with delays: 0.1s, 0.2s, 0.3s) to ensure route changes are properly detected, as iOS sometimes takes time to update the audio route after a change.

## API Reference

### `AudioOutputSelector`

A widget that wraps any child and shows a native iOS menu when tapped.

```dart
AudioOutputSelector({
  required Widget child,
})
```

**Properties:**
- `child` (Widget) - The widget to wrap (will be tappable)

**Behavior:**
- Tap opens native iOS UIMenu at widget position
- Menu shows all available audio outputs
- Active output is marked with checkmark
- Auto-closes after selection
- Automatically refreshes when routes change

### `AudioModel`

Represents an audio output device.

**Properties:**
- `title` (String) - Device name (e.g., "speaker", "AirPods Pro")
- `isActive` (bool) - Whether this device is currently active
- `deviceType` (AudioDeviceType) - Type of the device

**Extensions:**
- `outputName` (String) - User-friendly device name
- `hasOtherConnection` (bool) - True if device is wired headset or Bluetooth

### `AudioDeviceType`

Enum representing device types:
- `speaker` - Built-in speaker
- `receiver` - Built-in receiver (earpiece on iPhone)
- `wiredHeadset` - Wired headset or headphones
- `bluetooth` - Bluetooth audio device

### `OutputRouteSelector`

Main service class for managing audio routes.

**Methods:**

#### `getAvailableAudioOutputs()`

Returns a list of all available audio output devices.

```dart
static Future<List<AudioModel>> getAvailableAudioOutputs()
```

**Returns:** `Future<List<AudioModel>>`

**Throws:** `PlatformException` if there's an error getting devices

#### `changeAudioOutput(AudioModel device)`

Switches the audio output to the specified device.

```dart
static Future<void> changeAudioOutput(AudioModel device)
```

**Parameters:**
- `device` - The AudioModel to switch to

**Throws:** `PlatformException` if device not found or error switching

#### `onAudioRouteChanged`

Stream of audio route change events.

```dart
static Stream<AudioRouteChangeEvent> get onAudioRouteChanged
```

**Returns:** `Stream<AudioRouteChangeEvent>` - Stream of route change events

**Event properties:**
- `event` (String) - Event type ("audioRouteChanged")
- `reason` (int) - Route change reason code
- `reasonDescription` (String) - Human-readable reason
- `activeDevice` (AudioModel?) - Currently active device (if available)

**Route change reasons:**
- `2` - New device available (e.g., Bluetooth connected)
- `3` - Old device unavailable (e.g., headphones unplugged)
- `4` - Category change
- `5` - Override (e.g., user changed from Control Center)

## Example

### Simple Example (Using Widget)

```dart
import 'package:flutter/material.dart';
import 'package:output_route_selector/output_route_selector.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Audio Output')),
        body: Center(
          child: AudioOutputSelector(
            child: ElevatedButton.icon(
              icon: Icon(Icons.volume_up),
              label: Text('Select Audio Output'),
              onPressed: null, // Wrapper handles tap
            ),
          ),
        ),
      ),
    );
  }
}
```

### Advanced Example (Manual Control)

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:output_route_selector/output_route_selector.dart';

class AudioOutputSelector extends StatefulWidget {
  @override
  _AudioOutputSelectorState createState() => _AudioOutputSelectorState();
}

class _AudioOutputSelectorState extends State<AudioOutputSelector> {
  List<AudioModel> _devices = [];
  StreamSubscription<AudioRouteChangeEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _loadDevices();
    _setupRouteChangeListener();
  }

  void _setupRouteChangeListener() {
    _subscription = OutputRouteSelector.onAudioRouteChanged.listen((event) {
      print('Route changed: ${event.reasonDescription}');
      if (event.activeDevice != null) {
        print('Active: ${event.activeDevice!.outputName}');
      }
      _loadDevices(); // Refresh device list
    });
  }

  Future<void> _loadDevices() async {
    final devices = await OutputRouteSelector.getAvailableAudioOutputs();
    setState(() {
      _devices = devices;
    });
  }

  Future<void> _selectDevice(AudioModel device) async {
    await OutputRouteSelector.changeAudioOutput(device);
    await _loadDevices(); // Refresh to update active state
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        final device = _devices[index];
        return ListTile(
          title: Text(device.outputName),
          trailing: device.isActive
              ? Icon(Icons.check, color: Colors.green)
              : null,
          onTap: () => _selectDevice(device),
        );
      },
    );
  }
}
```

## Platform Support

| Platform | Support |
|----------|---------|
| iOS      | ✅ 12.0+ |
| Android  | ❌ Coming soon |
| macOS    | ❌ Coming soon |
| Web      | ❌ Not supported |
| Windows  | ❌ Not supported |
| Linux    | ❌ Not supported |

## Error Handling

The plugin throws `PlatformException` with the following error codes:

- `INVALID_ARGUMENTS` - Missing required parameters
- `NO_INPUTS` - No audio inputs available
- `DEVICE_NOT_FOUND` - Specified device not found
- `AUDIO_ROUTE_ERROR` - Error changing audio route

```dart
try {
  await OutputRouteSelector.changeAudioOutput(device);
} on PlatformException catch (e) {
  print('Error: ${e.code} - ${e.message}');
}
```

## License

MIT License - see LICENSE file for details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Issues

If you encounter any issues or have feature requests, please file them on the [GitHub issue tracker](https://github.com/raffazatyan/output_route_selector/issues).
