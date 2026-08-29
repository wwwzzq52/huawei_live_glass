// =============================================================================
// Photo Watermark · 华为动态照片
// -----------------------------------------------------------------------------
// 界面仿照样本 App（液态玻璃质感 + 照片水印），核心改动：
//   1. 单按钮导入华为动态照片（单文件 .jpg），自动识别并提取内嵌视频；
//   2. 水印面板：文字 / 大小 / 透明度 / 旋转 / 九宫格位置 / 图片水印开关；
//   3. 保存：输出华为动态照片（单文件 .jpg，内嵌视频 + 40 字节尾标记），
//      华为图库可直接识别为动态照片并播放。
//
// 液态玻璃折射着色器来自 Kyant0/AndroidLiquidGlass（Apache-2.0），
// 动态照片格式来自 aiglance/flutter_live_motion（MIT）。
// =============================================================================

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_live_motion/flutter_live_motion.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'liquid_glass_painter.dart';

void main() {
  runApp(const HuaweiLiveGlassApp());
}

class HuaweiLiveGlassApp extends StatelessWidget {
  const HuaweiLiveGlassApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photo Watermark',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0F1A),
        useMaterial3: true,
      ),
      home: const EditorPage(),
    );
  }
}

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final _plugin = FlutterLiveMotion();
  final _picker = ImagePicker();

  String? _imagePath;
  String? _videoPath; // 从华为动态照片中提取出的内嵌视频（缓存路径）
  Uint8List? _previewBytes;
  ui.Image? _previewImage;
  bool _isHuaweiMotion = false;

  // 水印参数
  String _watermarkText = 'Photo Watermark';
  double _watermarkOpacity = 0.6;
  double _watermarkSize = 44;
  int _watermarkPosition = 4; // 0..8 九宫格，默认右下
  double _watermarkRotation = -15;
  bool _showLogo = true; // 图片水印（模拟样本的设备 logo 水印）

  String _status = '请选择一张华为动态照片';
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            'Photo Watermark',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          if (_isHuaweiMotion)
            const _GlassBadge(label: '华为动态照片'),
        ],
      ),
    );
  }

  Widget _preview() {
    return Center(
      child: SizedBox(
        width: 320,
        height: 340,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_previewImage != null)
              CustomPaint(
                painter: LiquidGlassPainter(
                  content: _previewImage!,
                  cornerRadius: 28,
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: const ColoredBox(color: Color(0xFF1B1B27)),
              ),
            if (_previewImage != null) _buildPreviewOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewOverlay() {
    return Stack(
      fit: StackFit.expand,
      children: [
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
        if (_showLogo)
          Positioned(
            right: 18,
            bottom: 18,
            child: Image.asset('assets/photo_logo.png', width: 46, height: 46),
          ),
      ],
    );
  }

  Widget _glassPanel() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: const ui.ColorFilter.matrix(<double>[
          1, 0, 0, 0, 0,
          0, 1, 0, 0, 0,
          0, 0, 1, 0, 0,
          0, 0, 0, 1.15, 0,
        ]),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _glassButton(
                  icon: Icons.photo_library_outlined,
                  label: _imagePath == null ? '选择华为动态照片' : '重新选择照片',
                  onTap: _pickImage,
                ),
                const SizedBox(height: 14),

                _glassTextField(),
                const SizedBox(height: 12),

                _sliderRow('大小', _watermarkSize, 16, 96, (v) => setState(() => _watermarkSize = v)),
                const SizedBox(height: 6),
                _sliderRow('透明度', _watermarkOpacity, 0.1, 1.0, (v) => setState(() => _watermarkOpacity = v)),
                const SizedBox(height: 6),
                _sliderRow('旋转', _watermarkRotation, -45, 45, (v) => setState(() => _watermarkRotation = v)),
                const SizedBox(height: 12),

                Row(
                  children: [
                    const Text('位置', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    const SizedBox(width: 12),
                    Expanded(child: _positionGrid()),
                    const SizedBox(width: 12),
                    _logoSwitch(),
                  ],
                ),
                const SizedBox(height: 14),

                _busy
                    ? const Center(child: CircularProgressIndicator())
                    : _glassButton(
                        icon: Icons.file_download_outlined,
                        label: '保存华为动态照片',
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
      ),
    );
  }

  Widget _logoSwitch() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('图 标', style: TextStyle(fontSize: 11, color: Colors.white70)),
        Switch(
          value: _showLogo,
          activeColor: const Color(0xFFFF8D28),
          onChanged: _busy ? null : (v) => setState(() => _showLogo = v),
        ),
      ],
    );
  }

  Widget _positionGrid() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(9, (i) {
        final selected = _watermarkPosition == i;
        return GestureDetector(
          onTap: _busy ? null : () => setState(() => _watermarkPosition = i),
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFF8D28) : Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
          ),
        );
      }),
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
  // 导入：单按钮选择华为动态照片，自动提取内嵌视频
  // ===========================================================================
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() {
        _imagePath = image.path;
        _videoPath = null;
        _isHuaweiMotion = false;
        _busy = true;
        _status = '正在识别动态照片…';
      });

      // 提取华为动态照片内嵌视频（单文件 .jpg 内部自带 MP4）
      Map<dynamic, dynamic>? ext;
      try {
        ext = await _plugin.extractVideo(imagePath: image.path);
      } catch (_) {
        ext = null;
      }

      final videoPath = ext?['videoPath'] as String?;
      final isHuawei = ext?['isHuaweiMotionPhoto'] == true;

      setState(() {
        _videoPath = videoPath;
        _isHuaweiMotion = isHuawei;
        _status = isHuawei
            ? '✅ 已识别华为动态照片，并提取内嵌视频'
            : '已选照片（未检测到动态视频）';
      });

      await _rebuildPreview();
    } catch (e) {
      setState(() => _status = '选择照片失败: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  // ===========================================================================
  // 水印渲染
  // ===========================================================================
  Future<void> _rebuildPreview() async {
    if (_imagePath == null) return;
    try {
      final out = await _applyWatermark(File(_imagePath!), toJpeg: false);
      final codec = await ui.instantiateImageCodec(out);
      final frame = await codec.getNextFrame();
      await LiquidGlassPainter.ensureLoaded();
      setState(() {
        _previewBytes = out;
        _previewImage = frame.image;
      });
    } catch (e) {
      setState(() => _status = '预览渲染失败: $e');
    }
  }

  Future<Uint8List> _applyWatermark(File input, {required bool toJpeg}) async {
    final bytes = await input.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('无法解码图片');

    var image = decoded.convert(numChannels: 4);

    // 图片水印（模拟样本的 logo 水印）
    if (_showLogo) {
      try {
        final logoBytes = await rootBundle.load('assets/photo_logo.png');
        final logo = img.decodePng(logoBytes.buffer.asUint8List());
        if (logo != null) {
          final targetW = (image.width * 0.12).round().clamp(48, 200);
          final resized = img.copyResize(logo, width: targetW);
          final lx = image.width - resized.width - 24;
          final ly = image.height - resized.height - 24;
          image = img.compositeImage(image, resized, dstX: lx, dstY: ly);
        }
      } catch (_) {
        // 忽略 logo 绘制失败
      }
    }

    // 文字水印
    final pos = _positionOffset(image.width, image.height);
    image = img.drawString(
      image,
      _watermarkText,
      font: img.arial48,
      x: pos.$1,
      y: pos.$2,
      color: img.ColorRgba8(255, 255, 255, (_watermarkOpacity * 255).round()),
    );

    return toJpeg
        ? Uint8List.fromList(img.encodeJpg(image, quality: 95))
        : Uint8List.fromList(img.encodePng(image));
  }

  (int, int) _positionOffset(int w, int h) {
    const margin = 24;
    final col = _watermarkPosition % 3; // 0 左 1 中 2 右
    final row = _watermarkPosition ~/ 3; // 0 上 1 中 2 下
    final textW = (_watermarkSize * _watermarkText.length * 0.6).round();
    final x = switch (col) {
      0 => margin,
      1 => (w / 2 - textW / 2).round(),
      _ => (w - textW - margin).round(),
    };
    final y = switch (row) {
      0 => margin + 48,
      1 => (h / 2).round(),
      _ => (h - 48 - margin).round(),
    };
    return (x, y);
  }

  // ===========================================================================
  // 导出：渲染水印图 → 华为单文件动态照片
  // ===========================================================================
  Future<void> _export() async {
    if (_imagePath == null || _videoPath == null) return;
    setState(() {
      _busy = true;
      _status = '正在渲染水印并保存…';
    });

    try {
      final tmp = await getTemporaryDirectory();
      final processed = File('${tmp.path}/processed_${DateTime.now().millisecondsSinceEpoch}.jpg');
      final jpegBytes = await _applyWatermark(File(_imagePath!), toJpeg: true);
      await processed.writeAsBytes(jpegBytes);

      final result = await _plugin.export(
        imagePath: processed.path,
        videoPath: _videoPath!,
        mode: 'huawei',
      );

      setState(() {
        final motionPhoto = result?['motionPhoto'];
        if (motionPhoto != null) {
          _status = '✅ 华为动态照片已保存（单文件）\n$motionPhoto';
        } else {
          _status = '导出完成: $result';
        }
      });
    } catch (e) {
      setState(() => _status = '保存失败: $e');
    } finally {
      setState(() => _busy = false);
    }
  }
}

// =============================================================================
// 液态玻璃 UI 组件
// =============================================================================

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
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
