# output_route_selector Example

Demonstrates how to use the output_route_selector plugin.

## Features Demonstrated

1. **Widget-based selector** - Simple way to show native audio output menu
2. **Manual device list** - Display all available devices with custom UI
3. **Real-time updates** - Listen to route change events
4. **Device icons** - Show appropriate icons for each device type

## Getting Started

### Prerequisites

- Flutter 3.3.0 or higher
- iOS device or simulator (iOS 12.0+)

### Running the Example

1. Navigate to the example directory:
```bash
cd example
```

2. Get dependencies:
```bash
flutter pub get
```

3. Run on iOS:
```bash
flutter run
```

## Usage Examples

### Widget-based (Easiest)

```dart
AudioOutputSelector(
  child: ElevatedButton.icon(
    icon: Icon(Icons.volume_up),
    label: Text('Select Audio Output'),
    onPressed: null, // Wrapper handles tap
  ),
)
```

### Manual Control

```dart
// Get available devices
final devices = await OutputRouteSelector.getAvailableAudioOutputs();

// Switch to a device
await OutputRouteSelector.changeAudioOutput(device);

// Listen to route changes
OutputRouteSelector.onAudioRouteChanged.listen((event) {
  print('Route changed: ${event.reasonDescription}');
  if (event.activeDevice != null) {
    print('Active: ${event.activeDevice!.outputName}');
  }
});
```

## Testing

1. Run the app on an iOS device
2. Tap the "Select Audio Output" button to see the native menu
3. Connect/disconnect Bluetooth devices to see real-time updates
4. Use the device list to manually switch outputs
5. Check the event log at the bottom to see route change notifications

## Learn More

For more information, check out the main package documentation:
https://pub.dev/packages/output_route_selector
