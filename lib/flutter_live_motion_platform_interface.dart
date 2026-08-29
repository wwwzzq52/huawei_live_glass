import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_live_motion_method_channel.dart';

abstract class FlutterLiveMotionPlatform extends PlatformInterface {
  /// Constructs a FlutterLiveMotionPlatform.
  FlutterLiveMotionPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterLiveMotionPlatform _instance = MethodChannelFlutterLiveMotion();

  /// The default instance of [FlutterLiveMotionPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterLiveMotion].
  static FlutterLiveMotionPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterLiveMotionPlatform] when
  /// they register themselves.
  static set instance(FlutterLiveMotionPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Generates a Live Photo (iOS) or Motion Photo (Android).
  ///
  /// [imagePath] and [videoPath] are required.
  /// Returns a [dynamic] result:
  /// - iOS: [bool] indicating success (saved to Photos Library).
  /// - Android: [String] path to the generated Motion Photo file.
  Future<dynamic> generate({required String imagePath, required String videoPath}) {
    throw UnimplementedError('generate() has not been implemented.');
  }

  /// 【修改点 B：扩展接口 — 导出格式开关 + 华为单文件导出】
  ///
  /// [mode] 可选值：
  /// - `'standard'`：标准 Android MotionPhoto（视频嵌入 JPEG 尾部 + XMP），
  ///   与上游 flutter_live_motion 行为一致。
  /// - `'huawei'`（默认）：华为动态照片格式 — 输出单个 .jpg 文件
  ///   （JPEG 图像段 + 内嵌 MP4 + 40 字节华为尾标记），华为图库可直接识别播放。
  ///   旧值 `'huaweiPair'` / `'auto'` 兼容为 `'huawei'`。
  Future<Map<dynamic, dynamic>?> export({
    required String imagePath,
    required String videoPath,
    String? mode,
  }) {
    throw UnimplementedError('export() has not been implemented.');
  }

  /// 【新增：华为动态照片提取】
  ///
  /// 从选中的华为动态照片（单文件 .jpg）中提取内嵌视频片段。
  Future<Map<dynamic, dynamic>?> extractVideo({required String imagePath}) {
    throw UnimplementedError('extractVideo() has not been implemented.');
  }
}
