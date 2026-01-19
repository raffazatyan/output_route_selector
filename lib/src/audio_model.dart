import 'dart:io';
import 'audio_device_type.dart';

/// Model representing an audio output device.
class AudioModel {
  /// The title/name of the audio device.
  final String title;

  /// Whether this device is currently active.
  final bool isActive;

  /// The type of audio device.
  final AudioDeviceType deviceType;

  /// Creates an [AudioModel].
  const AudioModel({
    required this.title,
    required this.isActive,
    required this.deviceType,
  });

  /// Creates an [AudioModel] from a JSON map.
  factory AudioModel.fromJson(Map<String, dynamic> json) {
    return AudioModel(
      title: json['title'] as String,
      isActive: json['isActive'] as bool,
      deviceType: _deviceTypeFromString(json['deviceType'] as String),
    );
  }

  /// Converts this [AudioModel] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'isActive': isActive,
      'deviceType': _deviceTypeToString(deviceType),
    };
  }

  /// Creates a copy of this [AudioModel] with the given fields replaced.
  AudioModel copyWith({
    String? title,
    bool? isActive,
    AudioDeviceType? deviceType,
  }) {
    return AudioModel(
      title: title ?? this.title,
      isActive: isActive ?? this.isActive,
      deviceType: deviceType ?? this.deviceType,
    );
  }

  static AudioDeviceType _deviceTypeFromString(String type) {
    switch (type.toLowerCase()) {
      case 'speaker':
        return AudioDeviceType.speaker;
      case 'receiver':
        return AudioDeviceType.receiver;
      case 'wiredheadset':
        return AudioDeviceType.wiredHeadset;
      case 'bluetooth':
        return AudioDeviceType.bluetooth;
      default:
        throw ArgumentError('Unknown device type: $type');
    }
  }

  static String _deviceTypeToString(AudioDeviceType type) {
    switch (type) {
      case AudioDeviceType.speaker:
        return 'speaker';
      case AudioDeviceType.receiver:
        return 'receiver';
      case AudioDeviceType.wiredHeadset:
        return 'wiredHeadset';
      case AudioDeviceType.bluetooth:
        return 'bluetooth';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioModel &&
        other.title == title &&
        other.isActive == isActive &&
        other.deviceType == deviceType;
  }

  @override
  int get hashCode => Object.hash(title, isActive, deviceType);

  @override
  String toString() {
    return 'AudioModel(title: $title, isActive: $isActive, deviceType: $deviceType)';
  }
}

/// Extension on [AudioModel] providing additional functionality.
extension AudioModelExtension on AudioModel {
  /// Returns a user-friendly output name for the device.
  String get outputName {
    final isIOS = Platform.isIOS;
    final platformReceiverTitle = isIOS ? 'iPhone' : 'Phone';

    return switch (title.toLowerCase()) {
      'speaker' => 'Speaker',
      'receiver' => platformReceiverTitle,
      _ => title,
    };
  }

  /// Returns true if the device is a wired headset or bluetooth device.
  bool get hasOtherConnection =>
      deviceType == AudioDeviceType.wiredHeadset ||
      deviceType == AudioDeviceType.bluetooth;
}
