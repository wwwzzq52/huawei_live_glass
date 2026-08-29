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
  /// - `'standard'` 标准 Android MotionPhoto（视频嵌入图片内部）。
  /// - `'huawei'`   华为动态照片（单文件 .jpg：JPEG + MP4 + 40 字节尾标记）。
  ///   旧值 `'huaweiPair'` / `'auto'` 会兼容为 `'huawei'`。
  ///
  /// Android 返回 `Map`：
  ///   `{ 'image': 输出图片路径,
  ///      'motionPhoto': 单文件动态照片路径（两种模式均返回）,
  ///      'video': 恒为 null }`。
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

  /// 【新增：华为动态照片提取】
  ///
  /// 从选中的华为动态照片（单文件 .jpg）中提取内嵌视频片段。
  ///
  /// Android 返回 `Map`：
  ///   `{ 'videoPath': 提取出的 MP4 缓存路径（失败为 null）,
  ///      'isHuaweiMotionPhoto': 是否为华为动态照片 }`。
  Future<Map<dynamic, dynamic>?> extractVideo({required String imagePath}) {
    return FlutterLiveMotionPlatform.instance.extractVideo(imagePath: imagePath);
  }
}
