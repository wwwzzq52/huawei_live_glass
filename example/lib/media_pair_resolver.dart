// =============================================================================
// 【修改点 A】华为动态照片识别器（可编译版）
// -----------------------------------------------------------------------------
// 为什么需要它：
//   image_picker 从系统相册返回的是“缓存副本路径”（如 /cache/image_picker_xxx.jpg），
//   与华为原始 DCIM/Camera/IMG_xxx.jpg 不在同一目录，File('同目录同名.mp4') 永远
//   找不到。华为动态照片的 MP4 只存在于 MediaStore 中的原始相对目录
//   （DCIM/Camera/IMG_xxx.mp4），所以必须回到 MediaStore 查询。
//
// 用法：
//   1) 用 image_picker 选图（得到 XFile）；
//   2) 调 resolvePairFromPickedFile(xfile) —— 内部通过文件名在 MediaStore 反查
//      原始图片资源，再查“同目录同名 mp4”；
//   3) 返回 HuaweiMediaPair{imagePath, videoPath}。
//
// 说明：photo_manager 3.x 没有 presentPicker API（仅 presentLimited），
//       因此这里不依赖系统选择器，而是配合 image_picker 使用。
// =============================================================================

import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';

/// 一张被选中的图片及其可能的华为动态照片配对。
class HuaweiMediaPair {
  const HuaweiMediaPair({
    required this.imagePath,
    this.videoPath,
  });

  /// 图片路径（优先用 MediaStore 原始文件，保证可直接读）。
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
  // 从 image_picker 选中的图片出发，解析华为配对
  // ---------------------------------------------------------------------------
  static Future<HuaweiMediaPair?> resolvePairFromPickedFile(XFile picked) async {
    final granted = await requestPermission();
    if (!granted) {
      // 未授权时仍可继续使用 image_picker 返回的缓存副本，只是无法关联原始 mp4
      return HuaweiMediaPair(imagePath: picked.path);
    }

    final name = picked.name; // 如 IMG_20260808_133148.jpg
    final title = _stripExtension(name); // 如 IMG_20260808_133148

    AssetEntity? imageAsset = await _findImageByTitle(title);
    if (imageAsset == null) {
      // 反查失败：退回缓存副本
      return HuaweiMediaPair(imagePath: picked.path);
    }

    final image = await _materialize(imageAsset);
    final videoPath = await _findPairVideo(imageAsset);

    return HuaweiMediaPair(
      imagePath: image ?? picked.path,
      videoPath: videoPath,
    );
  }

  // ---------------------------------------------------------------------------
  // 从 AssetEntity 解析华为配对（已拿到实体时使用）
  // ---------------------------------------------------------------------------
  static Future<HuaweiMediaPair?> resolvePair(AssetEntity imageAsset) async {
    final image = await _materialize(imageAsset);
    if (image == null) return null;

    final videoPath = await _findPairVideo(imageAsset);
    return HuaweiMediaPair(imagePath: image, videoPath: videoPath);
  }

  static String _stripExtension(String filename) {
    final idx = filename.lastIndexOf('.');
    if (idx <= 0) return filename;
    return filename.substring(0, idx);
  }

  /// 按标题（文件名去扩展名）在 MediaStore 中反查原始图片资源。
  static Future<AssetEntity?> _findImageByTitle(String title) async {
    try {
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );
      if (paths.isEmpty) return null;

      final path = paths.first;
      final count = await path.assetCountAsync;
      if (count == 0) return null;

      final candidates = <String>[
        title,
        '${title}.jpg',
        '${title}.jpeg',
      ];

      const pageSize = 200;
      var page = 0;
      while (page * pageSize < count) {
        final assets = await path.getAssetListRange(
          start: page * pageSize,
          end: (page + 1) * pageSize,
        );
        for (final a in assets) {
          final t = a.title;
          if (t == null) continue;
          if (candidates.any((c) => t.equalsIgnoreCase(c))) {
            return a;
          }
        }
        page++;
      }
    } catch (_) {
      // ignore
    }
    return null;
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
  static Future<String?> _findPairVideo(AssetEntity imageAsset) async {
    try {
      final imageTitle = imageAsset.title; // 如 IMG_20260808_133148
      if (imageTitle == null || imageTitle.isEmpty) return null;

      final imageDir = imageAsset.relativePath; // 如 DCIM/Camera/

      // 候选标题：完全同名 / 带 _mp4 后缀（兼容不同 EMUI 版本）
      final candidates = <String>[
        imageTitle,
        '${imageTitle}_mp4',
        '${imageTitle}_MP4',
        '${imageTitle}.mp4',
      ];

      final videos = await PhotoManager.getAssetPathList(
        type: RequestType.video,
        onlyAll: true,
      );
      if (videos.isEmpty) return null;

      final path = videos.first;
      final count = await path.assetCountAsync;
      if (count == 0) return null;

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
          final matched = candidates.any((c) => vTitle.equalsIgnoreCase(c));
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
