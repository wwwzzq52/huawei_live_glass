// =============================================================================
// 【新增文件】基于 photo_manager 的华为动态照片识别器
// -----------------------------------------------------------------------------
// 为什么需要它：
//   image_picker 从系统相册返回的是“缓存副本路径”（如 /cache/image_picker_xxx.jpg），
//   与华为原始 DCIM/Camera/IMG_xxx.jpg 不在同一目录，File('同目录同名.mp4') 永远
//   找不到。华为动态照片的 MP4 只存在于 MediaStore 中的原始相对目录
//   （DCIM/Camera/IMG_xxx.mp4），所以必须回到 MediaStore 查询。
//
// 依赖（example/pubspec.yaml 追加）：
//   photo_manager: ^3.7.1
//
// 用法：
//   1) 调用 requestPermission()（内部用 requestPermissionExtend）申请相册权限；
//   2) 用 MediaPairResolver.pickHuaweiImage() 打开系统相册选择图片，
//      返回“原始图片路径 + 关联的同名 mp4 路径（若有）”；
//   3) 或对已有 AssetEntity 调用 resolvePair(asset)。
// =============================================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

/// 一张被选中的图片及其可能的华为动态照片配对。
class HuaweiMediaPair {
  const HuaweiMediaPair({
    required this.imagePath,
    this.videoPath,
  });

  /// 原始图片路径（从 MediaStore 解析，已复制到应用缓存，保证可直接读）。
  final String imagePath;

  /// 同目录同名的华为动态片段（若有）。
  final String? videoPath;

  bool get hasMotionVideo => videoPath != null;
}

/// 【修改点 A：photo_manager 版识别器】
class MediaPairResolver {
  const MediaPairResolver._();

  // ---------------------------------------------------------------------------
  // 权限
  // ---------------------------------------------------------------------------
  static Future<bool> requestPermission() async {
    final req = await PhotoManager.requestPermissionExtend();
    return req.isAuth || req.hasAccess;
  }

  // ---------------------------------------------------------------------------
  // 选择图片并自动关联同名 mp4
  // ---------------------------------------------------------------------------
  static Future<HuaweiMediaPair?> pickHuaweiImage() async {
    final granted = await requestPermission();
    if (!granted) {
      throw StateError('未授予相册访问权限');
    }

    // 用 photo_manager 自带的系统相册选择器：请求类型只限图片。
    // requestType 不能设为 null，否则所有类型都会出现。
    final assets = await PhotoManager.presentPicker(
      context: _pickerContext,
      requestType: RequestType.image,
      maxCount: 1,
    );
    if (assets.isEmpty) return null;

    final asset = assets.first;
    return resolvePair(asset);
  }

  // 说明：presentPicker 需要一个 BuildContext；photo_manager 在 Android 上
  // 实际通过系统 ACTION_GET_CONTENT 打开选择页，该 context 不负责渲染 UI。
  // 这里通过全局 NavigatorState 获取 context，应用需在 MaterialApp 上绑定：
  //   MaterialApp(navigatorKey: mediaPairResolverNavigatorKey, ...)
  static BuildContext get _pickerContext {
    final key = _rootContextKey.currentContext;
    if (key == null) {
      throw StateError('MediaPairResolver 未初始化：请在 MaterialApp 上设置 '
          'navigatorKey: mediaPairResolverNavigatorKey');
    }
    return key;
  }

  // ---------------------------------------------------------------------------
  // 从 AssetEntity 解析华为配对
  // ---------------------------------------------------------------------------
  static Future<HuaweiMediaPair?> resolvePair(AssetEntity imageAsset) async {
    final image = await _materialize(imageAsset);
    if (image == null) return null;

    final videoPath = await _findPairVideo(imageAsset);
    return HuaweiMediaPair(imagePath: image, videoPath: videoPath);
  }

  /// 把 MediaStore 中的资源复制为本地可读文件。
  static Future<String?> _materialize(AssetEntity asset) async {
    final file = await asset.file;
    if (file != null) return file.path;
    final origin = await asset.originFile;
    return origin?.path;
  }

  /// 核心：查询与图片同目录同名的 mp4。
  ///
  /// 华为动态照片的配对规则：
  ///   DCIM/Camera/IMG_20260808_133148.jpg
  ///   DCIM/Camera/IMG_20260808_133148.mp4   ← 同名，仅扩展名不同
  ///
  /// 实现策略（由快到慢）：
  ///   1) 从图片 AssetEntity 的 title（不含扩展名）出发，在 MediaStore 中查询
  ///      同 title、type == video 的资源；再比对相对目录是否一致；
  ///   2) 兼容少数机型生成 `IMG_xxx_mp4.mp4` 或大小写差异的情况。
  static Future<String?> _findPairVideo(AssetEntity imageAsset) async {
    try {
      final imageTitle = imageAsset.title; // 通常不含扩展名，如 IMG_20260808_133148
      if (imageTitle == null || imageTitle.isEmpty) return null;

      final imageDir = imageAsset.relativePath; // 如 DCIM/Camera/

      // 候选标题：完全同名 / 带 _mp4 后缀（兼容不同 EMUI 版本）
      final candidates = <String>[
        imageTitle,
        '${imageTitle}_mp4',
        '${imageTitle}_MP4',
        '${imageTitle}.mp4', // 个别机型 title 带扩展名
      ];

      final videos = await PhotoManager.getAssetPathList(
        type: RequestType.video,
        onlyAll: true,
      );
      if (videos.isEmpty) return null;

      final path = videos.first; // 全部视频的聚合路径
      final count = await path.assetCountAsync;
      if (count == 0) return null;

      // 分页遍历视频，避免一次性拉取数千条
      const pageSize = 200;
      var page = 0;
      while (page * pageSize < count) {
        final assets = await path.getAssetListRange(
          start: page * pageSize,
          end: (page + 1) * pageSize,
        );
        for (final v in assets) {
          final vTitle = v.title;
          if (vTitle == null) continue;
          final matched = candidates.any((c) =>
              vTitle.equalsIgnoreCase(c));
          if (!matched) continue;

          // 目录一致才算“同目录同名”
          final vDir = v.relativePath ?? '';
          final iDir = imageDir ?? '';
          if (vDir != iDir) continue;

          final file = await v.file ?? await v.originFile;
          if (file != null) return file.path;
        }
        page++;
      }
    } catch (_) {
      // 查询失败时退回 null，由调用方决定是否手动选择视频
    }
    return null;
  }
}

/// 字符串忽略大小写比较扩展。
extension on String {
  bool equalsIgnoreCase(String other) => toLowerCase() == other.toLowerCase();
}

// -----------------------------------------------------------------------------
// 全局 context 挂载点
// -----------------------------------------------------------------------------
final GlobalKey<NavigatorState> _rootContextKey = GlobalKey<NavigatorState>();

/// 便捷方法：让调用方把 MaterialApp 的 navigatorKey 绑定到本解析器。
GlobalKey<NavigatorState> get mediaPairResolverNavigatorKey => _rootContextKey;

/// 兜底：从任意已选图片路径出发的本地同名探测（保留原逻辑，供直接传路径时用）。
Future<String?> findLocalPairVideo(String imagePath) async {
  if (!Platform.isAndroid) return null;
  final lower = imagePath.toLowerCase();
  if (!lower.endsWith('.jpg') && !lower.endsWith('.jpeg')) return null;
  final base = imagePath.substring(0, imagePath.lastIndexOf('.'));
  for (final name in <String>['$base.mp4', '${base}_mp4.mp4']) {
    if (await File(name).exists()) return name;
  }
  return null;
}
