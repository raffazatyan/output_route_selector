import 'dart:async';
import 'package:flutter/material.dart';
import 'package:output_route_selector/output_route_selector.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audio Output Selector Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AudioOutputDemo(),
    );
  }
}

class AudioOutputDemo extends StatefulWidget {
  const AudioOutputDemo({super.key});

  @override
  State<AudioOutputDemo> createState() => _AudioOutputDemoState();
}

class _AudioOutputDemoState extends State<AudioOutputDemo> {
  List<AudioModel> _devices = [];
  StreamSubscription<AudioRouteChangeEvent>? _subscription;
  String _lastEvent = 'No events yet';

  @override
  void initState() {
    super.initState();
    _loadDevices();
    _setupRouteChangeListener();
  }

  void _setupRouteChangeListener() {
    _subscription = OutputRouteSelector.onAudioRouteChanged.listen((event) {
      setState(() {
        _lastEvent = 
            'Route changed: ${event.reasonDescription}\n'
            'Active: ${event.activeDevice?.outputName ?? 'Unknown'}';
      });
      _loadDevices();
    });
  }

  Future<void> _loadDevices() async {
    try {
      final devices = await OutputRouteSelector.getAvailableAudioOutputs();
      setState(() {
        _devices = devices;
      });
    } catch (e) {
      debugPrint('Error loading devices: $e');
    }
  }

  Future<void> _selectDevice(AudioModel device) async {
    try {
      await OutputRouteSelector.changeAudioOutput(device);
      await _loadDevices();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Audio Output Selector'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDevices,
          ),
        ],
      ),
      body: Column(
        children: [
          // Widget-based selector (easiest way)
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Widget-based Selector',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Tap the button to show native menu:'),
                  const SizedBox(height: 12),
                  Center(
                    child: AudioOutputSelector(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.volume_up),
                        label: const Text('Select Audio Output'),
                        onPressed: null, // Wrapper handles tap
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Manual device list
          Expanded(
            child: Card(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Available Devices',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _devices.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            itemCount: _devices.length,
                            itemBuilder: (context, index) {
                              final device = _devices[index];
                              return ListTile(
                                leading: Icon(
                                  _getDeviceIcon(device.deviceType),
                                  color: device.isActive
                                      ? Colors.blue
                                      : Colors.grey,
                                ),
                                title: Text(device.outputName),
                                subtitle: Text(
                                  device.deviceType.name.toUpperCase(),
                                ),
                                trailing: device.isActive
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      )
                                    : null,
                                onTap: () => _selectDevice(device),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),

          // Event log
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[200],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Last Event:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  _lastEvent,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getDeviceIcon(AudioDeviceType type) {
    switch (type) {
      case AudioDeviceType.speaker:
        return Icons.volume_up;
      case AudioDeviceType.receiver:
        return Icons.phone_iphone;
      case AudioDeviceType.wiredHeadset:
        return Icons.headset;
      case AudioDeviceType.bluetooth:
        return Icons.bluetooth_audio;
    }
  }
}
