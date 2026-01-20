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
  StreamSubscription<AudioModel?>? _subscription;
  final List<String> _eventLog = [];
  AudioModel? _currentDevice;

  @override
  void initState() {
    super.initState();
    _setupRouteChangeListener();
  }

  void _setupRouteChangeListener() {
    _subscription = OutputRouteSelector.instance.onAudioRouteChanged.listen((
      device,
    ) {
      if (device != null) {
        setState(() {
          _currentDevice = device;
          _eventLog.insert(
            0,
            '${DateTime.now().toString().substring(11, 19)} - ${device.outputName}',
          );
          // Keep only last 10 events
          if (_eventLog.length > 10) {
            _eventLog.removeLast();
          }
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Audio Output Selector'),
      ),
      body: Column(
        children: [
          // Native audio output button
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    'Tap to select audio output',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  // Native iOS button with UIMenu
                  AudioOutputSelector(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: const Icon(
                        Icons.volume_up,
                        size: 32,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_currentDevice != null) ...[
                    Text(
                      'Current: ${_currentDevice!.outputName}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _currentDevice!.deviceType.name.toUpperCase(),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ] else
                    const Text(
                      'Tap the button above',
                      style: TextStyle(color: Colors.grey),
                    ),
                ],
              ),
            ),
          ),

          // Event log
          Expanded(
            child: Card(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Event Log',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _eventLog.isEmpty
                        ? const Center(
                            child: Text(
                              'No events yet.\nSelect an audio output to see events.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _eventLog.length,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Text(
                                  _eventLog[index],
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontFamily: 'monospace',
                                    color: index == 0
                                        ? Colors.blue
                                        : Colors.grey[700],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
