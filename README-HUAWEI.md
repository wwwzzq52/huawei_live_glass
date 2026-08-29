# flutter_live_motion（华为动态照片扩展）

本项目基于开源项目 [aiglance/flutter_live_motion](https://github.com/aiglance/flutter_live_motion)（MIT License），
并在其之上扩展了**华为动态照片**（同名 .jpg + .mp4 配对）的识别与导出能力。
UI 示例为 Material 风格，保留了上游 Live Photo / Motion Photo 全部能力；
液态玻璃渲染与水印功能由调用方负责（本插件只负责动态照片格式），
参考实现可另见 [Kyant0/AndroidLiquidGlass](https://github.com/Kyant0/AndroidLiquidGlass)（Apache License 2.0）。

## 修改位置速查

| 文件 | 修改点 | 说明 |
| --- | --- | --- |
| `lib/flutter_live_motion.dart` | B | 新增 `export()` 导出入口 |
| `lib/flutter_live_motion_method_channel.dart` | B | 新增 `export` MethodChannel 通道 |
| `lib/flutter_live_motion_platform_interface.dart` | B | 扩展平台接口 `export()` |
| `android/src/main/kotlin/.../FlutterLiveMotionPlugin.kt` | A | `onMethodCall` 新增 `export` 分支 |
| `android/src/main/kotlin/.../HuaweiMotionPhotoExporter.kt` | A（新增） | 华为配对识别 + 华为/标准双模式导出 |
| `android/src/main/AndroidManifest.xml` | C | 声明 API≤32 的存储权限 |
| `example/lib/main.dart` | B | 示例：导入自动识别同名 mp4 + 「华为动态照片格式」开关 |
| `example/lib/media_pair_resolver.dart` | A（新增） | photo_manager 版：从 MediaStore 原始目录精确查询同名 mp4 |
| `example/android/app/src/main/AndroidManifest.xml` | C | 声明相册读取权限 |
| `android/src/test/kotlin/.../HuaweiMotionPhotoExporterTest.kt` | 新增 | 华为配对识别单元测试 |

## 华为动态照片格式说明

华为图库识别「动态照片」的规则是**同名配对**：

```text
DCIM/Camera/IMG_20260808_133148.jpg   ← 处理后的图片
DCIM/Camera/IMG_20260808_133148.mp4   ← 动态片段
```

两个文件仅扩展名不同、位于同一相册目录时，图库会将其合并显示为一张动态照片。

本插件：

- `mode = 'huaweiPair'`：把处理后的图片与视频写入 `DCIM/Camera`，保持同名；
- `mode = 'standard'`：复用上游 `MotionPhotoGeneratorHtml`，把视频嵌入 JPEG 尾部并写入
  Google/OPPO/Xiaomi 兼容的 XMP（标准 Motion Photo）；
- `mode = 'auto'`：若传入的图片与视频**同目录同名（.jpg/.jpeg + .mp4）**，判定源为华为
  动态照片并保留 `huaweiPair`，否则输出 `standard`。

## 接口

```dart
Future<Map<dynamic, dynamic>?> export({
  required String imagePath,
  required String videoPath,
  String? mode, // 'auto' | 'huaweiPair' | 'standard'
});
```

Android 返回值：

```dart
{
  'image': '/storage/emulated/0/DCIM/Camera/IMG_...jpg',
  'video': '/storage/emulated/0/DCIM/Camera/IMG_...mp4', // 仅 huaweiPair
  'motionPhoto': '/data/.../cache/MVIMG_..._MP.jpg',     // 仅 standard
}
```

## 许可证

- `flutter_live_motion`：MIT License（保留于 `LICENSE`）
- `AndroidLiquidGlass` 参考：Apache License 2.0（副本见 `LICENSE-AndroidLiquidGlass-Apache2.0`）

本扩展新增代码沿用上游 MIT License 发布。

## 云编译 APK（GitHub Actions）

仓库已内置工作流 `.github/workflows/build-apk.yml`，在 GitHub 网页上：

1. 打开仓库 **Actions** 页；
2. 左侧选择 **build-apk**；
3. 点 **Run workflow** → 保持 `main` 分支 → **Run workflow**；
4. 等待流水线跑完（约 5–10 分钟）；
5. 进入该次运行，在 **Artifacts** 区下载 `huawei_live_glass-release-apk`，
   解压得到 `app-release.apk` 即可安装。

工作流使用 Flutter 3.35.2 + Java 17 构建，产物位于
`example/build/app/outputs/flutter-apk/app-release.apk`。

