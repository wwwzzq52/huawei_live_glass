// =============================================================================
// 液态玻璃 CustomPainter
// -----------------------------------------------------------------------------
// 使用 Flutter 运行时效果（ui.FragmentProgram）加载 AGSL 着色器
// shaders/liquid_glass.frag，对传入的背景图做圆角折射 + 色散，还原
// Kyant0/AndroidLiquidGlass 的液态玻璃观感。
//
// 说明：
//   - setImageSampler(0, image) 把选中图片作为 uContent 采样源；
//   - 着色器加载失败时自动回退到普通圆角 + 轻微模糊，保证可运行。
// =============================================================================

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 一次性编译并缓存着色器程序（避免每次 build 都重新编译）。
Future<ui.FragmentProgram?>? _programFuture;

Future<ui.FragmentProgram?> _loadProgram() {
  return _programFuture ??= ui.FragmentProgram.fromAsset('shaders/liquid_glass.frag')
      .then<ui.FragmentProgram?>((p) => p)
      .catchError((Object _) => null);
}

class LiquidGlassPainter extends CustomPainter {
  LiquidGlassPainter({
    required this.content,
    required this.cornerRadius,
    this.refractionHeight = 60,
    this.refractionAmount = 0.55,
    this.depthEffect = 0.6,
    this.chromaticAberration = 0.5,
  });

  /// 被折射的背景图（用户选中的照片）。
  final ui.Image content;

  /// 圆角半径（逻辑像素）。
  final double cornerRadius;

  final double refractionHeight;
  final double refractionAmount;
  final double depthEffect;
  final double chromaticAberration;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final program = _programCache;
    if (program != null) {
      _paintWithShader(canvas, size, program);
      return;
    }

    // 回退：圆角裁切 + 直接绘制内容
    final radius = Radius.circular(cornerRadius);
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, radius);
    canvas.save();
    canvas.clipRRect(rrect);
    final src = Rect.fromLTWH(0, 0, content.width.toDouble(), content.height.toDouble());
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(content, src, dst, Paint()..filterQuality = ui.FilterQuality.high);
    canvas.restore();
  }

  void _paintWithShader(Canvas canvas, Size size, ui.FragmentProgram program) {
    final shader = program.fragmentShader();

    shader.setFloat(0, size.width);  // uSize.x
    shader.setFloat(1, size.height); // uSize.y
    shader.setFloat(2, content.width.toDouble());  // uContentSize.x
    shader.setFloat(3, content.height.toDouble()); // uContentSize.y
    shader.setFloat(4, cornerRadius); // uCornerRadii.x
    shader.setFloat(5, cornerRadius); // uCornerRadii.y
    shader.setFloat(6, cornerRadius); // uCornerRadii.z
    shader.setFloat(7, cornerRadius); // uCornerRadii.w
    shader.setFloat(8, refractionHeight);
    shader.setFloat(9, refractionAmount);
    shader.setFloat(10, depthEffect);
    shader.setFloat(11, chromaticAberration);
    shader.setImageSampler(0, content);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  static ui.FragmentProgram? _programCache;
  static bool _loading = false;

  /// 在显示前异步加载着色器。
  static Future<void> ensureLoaded() async {
    if (_programCache != null || _loading) return;
    _loading = true;
    _programCache = await _loadProgram();
    _loading = false;
  }

  @override
  bool shouldRepaint(covariant LiquidGlassPainter oldDelegate) {
    return oldDelegate.content != content ||
        oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.refractionHeight != refractionHeight ||
        oldDelegate.refractionAmount != refractionAmount ||
        oldDelegate.depthEffect != depthEffect ||
        oldDelegate.chromaticAberration != chromaticAberration;
  }
}
