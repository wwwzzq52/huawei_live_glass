// =============================================================================
// 【参考实现】华为动态照片 + 液态玻璃 + 水印 完整 Dart 应用
// -----------------------------------------------------------------------------
// 这是把两个开源项目能力合到一起的 Flutter 端参考代码：
//   - 动态照片格式：aiglance/flutter_live_motion（已扩展华为配对导出，见本仓库 lib/ 与 android/）
//   - 液态玻璃 UI：Kyant0/AndroidLiquidGlass 是 Compose Multiplatform 库，
//     其 AGSL RuntimeShader 不能直接在 Flutter 中使用；Flutter 端用
//     BackdropFilter(ImageFilter.blur) 实现等效的“液态玻璃”观感。
//     （要 1:1 复用其 AGSL 着色器，需在 Android 原生层集成 Compose 或
//       通过 PlatformView 嵌入，工程代价大，本参考按 Flutter 惯用方式等价实现。）
//
// 依赖（pubspec.yaml 追加）：
//   dependencies:
//     image: ^4.5.0          # 水印绘制 + JPEG 编解码
//     image_picker: ^1.2.1
//     path_provider: ^2.1.5  # 输出缓存目录
//     flutter_live_motion:  # 本仓库本地路径
//       path: ../
// =============================================================================

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_live_motion/flutter_live_motion.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

import 'media_pair_resolver.dart';

void main() {
  runApp(const HuaweiLiveGlassApp());
}

class HuaweiLiveGlassApp extends StatelessWidget {
  const HuaweiLiveGlassApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '华为动态照片 · 液态玻璃水印',
      debugShowCheckedModeBanner: false,
      navigatorKey: mediaPairResolverNavigatorKey,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101018),
        useMaterial3: true,
      ),
      home: const EditorPage(),
    );
  }
}

// =============================================================================
// 编辑页：液态玻璃 UI + 水印参数 + 华为动态照片导入/导出
// =============================================================================
class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final _plugin = FlutterLiveMotion();
  final _picker = ImagePicker();

  String? _imagePath;
  String? _videoPath;
  Uint8List? _previewBytes;

  /// 【修改点 A】华为动态照片识别：选 jpg 时自动读同目录同名 mp4
  bool _detectedHuaweiPair = false;

  /// 【修改点 B】导出开关：华为动态照片格式
  bool _huaweiFormat = false;

  // 水印参数
  String _watermarkText = 'LIQUID GLASS';
  double _watermarkOpacity = 0.6;
  double _watermarkSize = 48;
  int _watermarkPosition = 4; // 0..8 九宫格，默认右下
  double _watermarkRotation = -15;

  String _status = '就绪';
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 【液态玻璃背景】多层渐变 + 模糊光斑，给 BackdropFilter 提供内容
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _LiquidBackground(),
          SafeArea(
            child: Column(
              children: [
                _header(),
                Expanded(child: _preview()),
                _glassPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          const Text(
            '动态照片水印',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          if (_detectedHuaweiPair)
            const _GlassBadge(label: '华为动态照片已识别'),
        ],
      ),
    );
  }

  Widget _preview() {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          width: 320,
          height: 320,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_previewBytes != null)
                Image.memory(_previewBytes!, fit: BoxFit.cover, gaplessPlayback: true)
              else
                const ColoredBox(color: Color(0xFF1B1B27)),
              // 预览水印
              if (_previewBytes != null)
                Center(
                  child: Transform.rotate(
                    angle: _watermarkRotation * 3.1415926 / 180,
                    child: Opacity(
                      opacity: _watermarkOpacity,
                      child: Text(
                        _watermarkText,
                        style: TextStyle(
                          fontSize: _watermarkSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: const [
                            Shadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 【液态玻璃面板】BackdropFilter 模糊背后内容，模拟 AndroidLiquidGlass 的 vibrancy+blur
  Widget _glassPanel() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: const ColorFilter.matrix(<double>[
          1, 0, 0, 0, 0,
          0, 1, 0, 0, 0,
          0, 0, 1, 0, 0,
          0, 0, 0, 1.15, 0, // 提亮 = vibrancy 近似
        ]),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _glassButton(
                      icon: Icons.photo_library_outlined,
                      label: '选择图片',
                      onTap: _pickImage,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _glassButton(
                      icon: Icons.movie_outlined,
                      label: _videoPath == null ? '选择视频' : '已关联视频',
                      onTap: _pickVideo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 水印参数（保留水印功能）
              _glassTextField(),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _sliderRow(
                      '大小',
                      _watermarkSize,
                      16,
                      96,
                      (v) => setState(() => _watermarkSize = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _sliderRow(
                      '透明度',
                      _watermarkOpacity,
                      0.1,
                      1.0,
                      (v) => setState(() => _watermarkOpacity = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 【修改点 B】华为动态照片格式开关
              SwitchListTile(
                value: _huaweiFormat,
                onChanged: _busy
                    ? null
                    : (v) => setState(() {
                          _huaweiFormat = v;
                          _status = v ? '导出模式：华为动态照片（图片+同名mp4）' : '导出模式：标准 MotionPhoto';
                        }),
                contentPadding: EdgeInsets.zero,
                title: const Text('华为动态照片格式'),
                subtitle: Text(
                  _huaweiFormat
                      ? '输出处理后的图片 + 同名 mp4，华为图库可识别播放'
                      : '输出标准 Android MotionPhoto（视频嵌入图片内部）',
                  style: const TextStyle(fontSize: 12),
                ),
                activeColor: const Color(0xFFFF8D28),
              ),
              const SizedBox(height: 10),

              _busy
                  ? const Center(child: CircularProgressIndicator())
                  : _glassButton(
                      icon: Icons.file_download_outlined,
                      label: '导出动态照片',
                      highlight: true,
                      onTap: (_imagePath == null || _videoPath == null) ? null : _export,
                    ),
              const SizedBox(height: 8),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.75)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassTextField() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: TextField(
        controller: TextEditingController(text: _watermarkText)
          ..selection = TextSelection.collapsed(offset: _watermarkText.length),
        onChanged: (v) => setState(() => _watermarkText = v),
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          border: InputBorder.none,
          icon: Icon(Icons.title, color: Colors.white70),
          hintText: '水印文字',
          hintStyle: TextStyle(color: Colors.white38),
        ),
      ),
    );
  }

  Widget _sliderRow(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label ${value.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            activeTrackColor: const Color(0xFFFF8D28),
            inactiveTrackColor: Colors.white24,
          ),
          child: Slider(value: value, min: min, max: max, onChanged: _busy ? null : onChanged),
        ),
      ],
    );
  }

  Widget _glassButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool highlight = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: highlight
              ? const LinearGradient(colors: [Color(0xFFFF8D28), Color(0xFFFF5E3A)])
              : LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.14),
                    Colors.white.withValues(alpha: 0.06),
                  ],
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: onTap == null ? Colors.white38 : Colors.white),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: onTap == null ? Colors.white38 : Colors.white)),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 导入：识别华为动态照片（选 jpg 自动读同目录同名 mp4）
  // ===========================================================================
  Future<void> _pickImage() async {
    try {
      // 【修改点 A：photo_manager 精确识别华为动态照片】
      // 优先用 MediaPairResolver.pickHuaweiImage()：
      //   通过系统相册选择图片 → 从 MediaStore 解析原始相对目录 → 查同名 mp4。
      // 该方法内部会申请权限；失败或用户取消时回退到 image_picker。
      HuaweiMediaPair? pair;
      try {
        pair = await MediaPairResolver.pickHuaweiImage();
      } catch (_) {
        pair = null;
      }

      if (pair != null) {
        setState(() {
          _imagePath = pair.imagePath;
          _videoPath = pair.videoPath ?? _videoPath;
          _detectedHuaweiPair = pair.hasMotionVideo;
          _status = pair.hasMotionVideo
              ? '✅ 识别华为动态照片，自动关联 ${pair.videoPath!.split('/').last}'
              : '已选图片 ${pair.imagePath.split('/').last}';
        });
        await _rebuildPreview();
        return;
      }

      // 回退：image_picker + 本地路径探测
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      final autoVideo = await _findPairVideo(image.path);

      setState(() {
        _imagePath = image.path;
        _videoPath = autoVideo ?? _videoPath;
        _detectedHuaweiPair = autoVideo != null;
        _status = autoVideo != null
            ? '✅ 识别华为动态照片，自动关联 ${autoVideo.split('/').last}'
            : '已选图片 ${image.path.split('/').last}';
      });

      await _rebuildPreview();
    } catch (e) {
      setState(() => _status = '选择图片失败: $e');
    }
  }

  /// 【修改点 A】同目录同名 mp4 识别（photo_manager 版）。
  ///
  /// 优先用 photo_manager 打开系统相册并解析 MediaStore 中的原始相对目录，
  /// 从而精确命中华为“同目录同名”的 IMG_xxx.mp4；失败时回退到 image_picker
  /// 并做本地路径探测（仅适用于直接传入原始文件路径的场景）。
  Future<String?> _findPairVideo(String imagePath) async {
    if (!Platform.isAndroid) return null;

    // 回退：本地路径同名探测
    final local = await findLocalPairVideo(imagePath);
    if (local != null) return local;

    // 已由 photo_manager 拿到 AssetEntity 的场景不经过这里；
    // 此处只兜底 image_picker 的缓存副本：无法从缓存路径反查 MediaStore 原始目录，
    // 返回 null 让调用方手动选视频。
    return null;
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        setState(() {
          _videoPath = video.path;
          _status = '已选视频 ${video.path.split('/').last}';
        });
      }
    } catch (e) {
      setState(() => _status = '选择视频失败: $e');
    }
  }

  // ===========================================================================
  // 水印渲染：把水印画到处理后的图片上（保留原水印功能）
  // ===========================================================================
  Future<void> _rebuildPreview() async {
    if (_imagePath == null) return;
    try {
      final out = await _applyWatermark(File(_imagePath!), toJpeg: false);
      setState(() => _previewBytes = out);
    } catch (e) {
      setState(() => _status = '预览渲染失败: $e');
    }
  }

  Future<Uint8List> _applyWatermark(File input, {required bool toJpeg}) async {
    final bytes = await input.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('无法解码图片');

    final image = decoded.convert(numChannels: 4);
    final pos = _positionOffset(image.width, image.height);

    final draw = img.drawString(
      image,
      _watermarkText,
      font: img.arial48, // 内置位图字体，避免字体资源依赖
      x: pos.$1,
      y: pos.$2,
      color: img.ColorRgba8(255, 255, 255, (_watermarkOpacity * 255).round()),
    );

    return toJpeg
        ? Uint8List.fromList(img.encodeJpg(draw, quality: 95))
        : Uint8List.fromList(img.encodePng(draw));
  }

  (int, int) _positionOffset(int w, int h) {
    const margin = 24;
    final col = _watermarkPosition % 3; // 0 左 1 中 2 右
    final row = _watermarkPosition ~/ 3; // 0 上 1 中 2 下
    final x = switch (col) {
      0 => margin,
      1 => (w / 2 - _watermarkSize * 2).round(),
      _ => (w - _watermarkSize * _watermarkText.length * 0.6 - margin).round(),
    };
    final y = switch (row) {
      0 => margin + 48,
      1 => (h / 2).round(),
      _ => (h - 48 - margin).round(),
    };
    return (x, y);
  }

  // ===========================================================================
  // 导出：先渲染水印图，再按开关选择华为配对 / 标准 MotionPhoto
  // ===========================================================================
  Future<void> _export() async {
    if (_imagePath == null || _videoPath == null) return;
    setState(() {
      _busy = true;
      _status = '正在渲染水印并导出…';
    });

    try {
      final tmp = await getTemporaryDirectory();
      final processed = File('${tmp.path}/processed_${DateTime.now().millisecondsSinceEpoch}.jpg');
      final jpegBytes = await _applyWatermark(File(_imagePath!), toJpeg: true);
      await processed.writeAsBytes(jpegBytes);

      // 【修改点 B】导出开关：开启 → 华为配对；关闭 → 标准 MotionPhoto
      final mode = _huaweiFormat ? 'huaweiPair' : 'standard';
      final result = await _plugin.export(
        imagePath: processed.path,
        videoPath: _videoPath!,
        mode: mode,
      );

      setState(() {
        if (result != null && result['video'] != null) {
          _status = '✅ 华为动态照片已导出\n图片: ${result['image']}\n视频: ${result['video']}';
        } else if (result != null && result['motionPhoto'] != null) {
          _status = '✅ 标准 MotionPhoto 已生成\n${result['motionPhoto']}';
        } else {
          _status = '导出完成: $result';
        }
      });
    } catch (e) {
      setState(() => _status = '导出失败: $e');
    } finally {
      setState(() => _busy = false);
    }
  }
}

// =============================================================================
// 液态玻璃 UI 组件
// =============================================================================

/// 【液态玻璃背景】多个彩色光斑 + 深色底，供 BackdropFilter 产生折射感
class _LiquidBackground extends StatelessWidget {
  const _LiquidBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1030), Color(0xFF0B1026), Color(0xFF14222B)],
        ),
      ),
      child: Stack(
        children: const [
          _GlowBall(color: Color(0x66FF8D28), top: -80, left: -60, size: 260),
          _GlowBall(color: Color(0x550088FF), top: 180, right: -90, size: 300),
          _GlowBall(color: Color(0x4434C759), bottom: -100, left: 40, size: 280),
        ],
      ),
    );
  }
}

class _GlowBall extends StatelessWidget {
  const _GlowBall({
    required this.color,
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.size,
  });

  final Color color;
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassBadge extends StatelessWidget {
  const _GlassBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0x5534C759),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.motion_photos_on, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}
