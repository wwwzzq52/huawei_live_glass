import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_live_motion_platform_interface.dart';

/// An implementation of [FlutterLiveMotionPlatform] that uses method channels.
class MethodChannelFlutterLiveMotion extends FlutterLiveMotionPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_live_motion');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<dynamic> generate({required String imagePath, required String videoPath}) async {
    return await methodChannel.invokeMethod('generate', {
      'imagePath': imagePath,
      'videoPath': videoPath,
    });
  }

  /// 【修改点 B：新增 export 通道】
  @override
  Future<Map<dynamic, dynamic>?> export({
    required String imagePath,
    required String videoPath,
    String? mode,
  }) async {
    final result = await methodChannel.invokeMapMethod<dynamic, dynamic>('export', {
      'imagePath': imagePath,
      'videoPath': videoPath,
      'mode': mode ?? 'auto',
    });
    return result;
  }
}
