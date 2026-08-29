# flutter_live_motion（华为动态照片扩展 · 单文件）

本项目基于开源项目 [aiglance/flutter_live_motion](https://github.com/aiglance/flutter_live_motion)（MIT License），
并在其之上扩展了**华为动态照片**（单文件 .jpg 内嵌视频）的识别与导出能力。
UI 示例为 Material 风格，保留了上游 Live Photo / Motion Photo 全部能力；
液态玻璃渲染（AGSL 折射着色器）已移植到 `example/shaders/liquid_glass.frag`，
参考实现见 [Kyant0/AndroidLiquidGlass](https://github.com/Kyant0/AndroidLiquidGlass)（Apache License 2.0）。

## 修改位置速查

| 文件 | 修改点 | 说明 |
| --- | --- | --- |
| `lib/flutter_live_motion.dart` | B | 新增 `export()` 导出入口 |
| `lib/flutter_live_motion_method_channel.dart` | B | 新增 `export` MethodChannel 通道 |
| `lib/flutter_live_motion_platform_interface.dart` | B | 扩展平台接口 `export()` |
| `android/src/main/kotlin/.../FlutterLiveMotionPlugin.kt` | A | `onMethodCall` 新增 `export` 分支 |
| `android/src/main/kotlin/.../HuaweiMotionPhotoExporter.kt` | A（重写） | 华为单文件导出 + 标准双模式导出 |
| `example/shaders/liquid_glass.frag` | 新增 | 液态玻璃 AGSL 折射着色器（移植自 AndroidLiquidGlass） |
| `example/lib/liquid_glass_painter.dart` | 新增 | `CustomPainter` 加载着色器渲染液态玻璃 |
| `example/lib/liquid_glass_watermark_app.dart` | A/B | 导入识别 + 液态玻璃预览 + 水印 + 导出开关 |
| `example/lib/media_pair_resolver.dart` | A（新增） | photo_manager 版：从 MediaStore 原始目录精确查询视频 |
| `example/pubspec.yaml` | C | 声明 `shaders/liquid_glass.frag` |

## 华为动态照片格式说明（单文件）

华为图库识别动态照片的规则是**单个 JPEG 文件内嵌视频**：

```text
[完整 JPEG 图像段，截止到最后一个 FFD9]
+ [MP4 动态片段原始字节]
+ [40 字节华为尾标记]
```

40 字节尾标记与华为相机生成文件一致：

```text
"922:503 " + 12 个空格              （20 字节）
"LIVE_"    + 7 位随机数字 + 8 个空格 （20 字节）
```

本插件：

- `mode = 'huawei'`（默认）：把处理后的图片与视频按上述结构合成**单个 .jpg** 写入 `DCIM/Camera`，
  华为图库直接识别为动态照片并播放内嵌视频；
- `mode = 'standard'`：复用上游 `MotionPhotoGeneratorHtml`，把视频嵌入 JPEG 尾部并写入
  Google/OPPO/Xiaomi 兼容的 XMP（标准 Motion Photo）；
- 旧值 `huaweiPair` / `auto` 兼容为 `huawei`。

## 接口

```dart
Future<Map<dynamic, dynamic>?> export({
  required String imagePath,
  required String videoPath,
  String? mode, // 'huawei' | 'standard'
});
```

Android 返回值：

```dart
{
  'image': '/storage/emulated/0/DCIM/Camera/IMG_...jpg',
  'video': null,                                     // 恒为 null
  'motionPhoto': '/storage/emulated/0/DCIM/Camera/IMG_...jpg', // 单文件动态照片
}
```

## 许可证

- `flutter_live_motion`：MIT License（保留于 `LICENSE`）
- `AndroidLiquidGlass` 参考：Apache License 2.0（副本见 `LICENSE-AndroidLiquidGlass-Apache2.0`）

本扩展新增代码沿用上游 MIT License 发布。

## 云编译 APK（GitHub Actions）

仓库已内置工作流 `.github/workflows/build-android.yml`，在 GitHub 网页上：

1. 打开仓库 **Actions** 页；
2. 左侧选择 **Build Android APK**；
3. 点 **Run workflow** → 保持 `main` 分支 → **Run workflow**；
4. 等待流水线跑完（约 5–10 分钟）；
5. 进入该次运行，在 **Artifacts** 区下载 `app-release-apk`，
   解压得到 `app-release.apk` 即可安装。

工作流使用 Flutter 3.35.2 + Java 17 构建，产物位于
`example/build/app/outputs/flutter-apk/app-release.apk`。
