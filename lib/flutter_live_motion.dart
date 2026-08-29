import 'flutter_live_motion_platform_interface.dart';

class FlutterLiveMotion {
  Future<String?> getPlatformVersion() {
    return FlutterLiveMotionPlatform.instance.getPlatformVersion();
  }

  /// Generates a Live Photo (iOS) or Motion Photo (Android).
  ///
  /// [imagePath] and [videoPath] are required.
  ///
  /// Returns:
  /// - iOS: [bool] true if successfully saved to Photos Library.
  /// - Android: [String] path to the generated Motion Photo file (saved in cache directory).
  Future<dynamic> generate({required String imagePath, required String videoPath}) {
    return FlutterLiveMotionPlatform.instance.generate(imagePath: imagePath, videoPath: videoPath);
  }

  /// 【修改点 B：导出入口】
  ///
  /// [mode] 可选值：
  /// - `'standard'`  标准 Android MotionPhoto（视频嵌入图片内部）。
  /// - `'huaweiPair'` 华为动态照片（图片 + 同名 mp4，华为图库可识别播放）。
  /// - `'auto'`      自动：源为“同目录同名 .jpg/.mp4 配对”时保留华为格式，
  ///                 否则输出标准 MotionPhoto。
  ///
  /// Android 返回 `Map`：`{ 'image': 输出图片路径, 'video': 输出视频路径(仅华为模式),
  /// 'motionPhoto': 标准模式生成的单文件路径(仅标准模式) }`。
  Future<Map<dynamic, dynamic>?> export({
    required String imagePath,
    required String videoPath,
    String? mode,
  }) {
    return FlutterLiveMotionPlatform.instance.export(
      imagePath: imagePath,
      videoPath: videoPath,
      mode: mode,
    );
  }
}
