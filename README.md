# flutter_live_motion

[English](#english) | [中文](#中文)

---

<a name="english"></a>

A Flutter plugin to generate and save Live Photos (iOS) and Motion Photos (Android) with broad device compatibility.

[![pub package](https://img.shields.io/pub/v/flutter_live_motion.svg)](https://pub.dev/packages/flutter_live_motion)

## Features

- ✅ **iOS Live Photos**: Generates Live Photos from JPG/HEIC images and MOV videos, with proper metadata pairing
- ✅ **Android Motion Photos**: Generates Motion Photos compatible with multiple vendors:
  - Google Pixel (Google Photos)
  - OPPO/Realme (ColorOS/RealmeUI)
  - Xiaomi (MIUI/HyperOS)
  - Other Android devices with Google Photos app
- ✅ **Smart XMP Merging**: Preserves original image metadata (HDR GainMap, etc.) while adding Motion Photo fields
- ✅ **Automatic Saving**:
  - iOS: Saves directly to Photos Library
  - Android: Saves to app cache directory (can be moved to gallery)

## Installation

Add `flutter_live_motion` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_live_motion: ^0.1.0
```

Then run:

```bash
flutter pub get
```

## Platform Configuration

### iOS

Add the following keys to your `Info.plist` file to access the Photo Library:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photo library to save Live Photos.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>We need access to save Live Photos to your photo library.</string>
```

### Android

No special permissions are required. The plugin generates Motion Photos in the app's cache directory. To save to the public gallery, you can use a file picker or media store API.

## Usage

### Basic Example

```dart
import 'package:flutter_live_motion/flutter_live_motion.dart';
import 'package:image_picker/image_picker.dart';

class LivePhotoExample extends StatefulWidget {
  @override
  _LivePhotoExampleState createState() => _LivePhotoExampleState();
}

class _LivePhotoExampleState extends State<LivePhotoExample> {
  final _plugin = FlutterLiveMotion();
  final _picker = ImagePicker();

  String? _imagePath;
  String? _videoPath;

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _imagePath = image.path);
    }
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() => _videoPath = video.path);
    }
  }

  Future<void> _generateLivePhoto() async {
    if (_imagePath == null || _videoPath == null) {
      print('Please select both image and video');
      return;
    }

    try {
      final result = await _plugin.generate(
        imagePath: _imagePath!,
        videoPath: _videoPath!,
      );

      if (Platform.isIOS) {
        if (result == true) {
          print('✅ Live Photo saved to Photos Library!');
        }
      } else {
        print('✅ Motion Photo generated at: $result');
      }
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Live Photos Demo')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _pickImage,
            child: Text('Pick Image'),
          ),
          ElevatedButton(
            onPressed: _pickVideo,
            child: Text('Pick Video'),
          ),
          ElevatedButton(
            onPressed: _generateLivePhoto,
            child: Text('Generate Live Photo'),
          ),
        ],
      ),
    );
  }
}
```

### API Reference

#### `generate()`

Generates a Live Photo (iOS) or Motion Photo (Android).

```dart
Future<dynamic> generate({
  required String imagePath,
  required String videoPath,
})
```

**Parameters:**

- `imagePath`: Path to the image file
  - iOS: JPG or HEIC
  - Android: JPG (required)
- `videoPath`: Path to the video file
  - iOS: MOV (H.264/H.265 recommended)
  - Android: MP4

**Returns:**

- iOS: `bool` - `true` if saved successfully to Photos Library
- Android: `String` - Path to the generated Motion Photo file

**Throws:**

- `PlatformException` if generation fails

#### `getPlatformVersion()`

Returns the platform version string.

```dart
Future<String?> getPlatformVersion()
```

## Requirements

### iOS

- **Image Format**: JPG or HEIC
- **Video Format**: MOV (H.264 or H.265 codec)
- **Video Duration**: Typically 1-3 seconds
- **iOS Version**: iOS 9.1+

### Android

- **Image Format**: JPG (required)
- **Video Format**: MP4
- **Video Duration**: Typically 1-3 seconds
- **Android Version**: Android 5.0+ (API 21+)

## Device Compatibility

### Tested Devices

✅ **iOS**:

- iPhone (iOS 9.1+)
- iPad (iOS 9.1+)

✅ **Android**:

- Google Pixel (all models)
- OPPO/Realme (ColorOS 7+)
- Xiaomi (MIUI 11+, HyperOS)
- Samsung (with Google Photos app)
- Other Android devices (with Google Photos app)

### Motion Photo Format Support

The plugin generates Motion Photos with XMP metadata compatible with:

- **Google Photos**: Full support on all devices
- **OPPO/Realme Gallery**: Native support with `OpCamera` metadata
- **Xiaomi Gallery**: Native support with `MiCamera` metadata
- **Samsung Gallery**: Support via Google Photos integration

## Technical Details

### iOS Implementation

- Uses `AVFoundation` and `PhotoKit` frameworks
- Injects `assetIdentifier` into image EXIF and video QuickTime metadata
- Creates proper Live Photo pairing for Photos Library

### Android Implementation

- Appends MP4 video data to JPG image
- Injects XMP metadata with Motion Photo specifications:
  - Google Camera v2 format
  - OPPO/Realme OLivePhoto v2 format
  - Xiaomi MicroVideo format
- Smart XMP merging preserves original image metadata (HDR GainMap, etc.)
- Properly maintains JPEG APP1 segment structure

## Troubleshooting

### Android: Motion Photo not recognized

1. **Check image format**: Must be JPG (not PNG or other formats)
2. **Check video format**: Must be MP4
3. **Verify file integrity**: Ensure both files are valid and not corrupted
4. **Test with Google Photos**: Install Google Photos app for guaranteed compatibility

### iOS: Live Photo not appearing

1. **Check permissions**: Ensure Photo Library permissions are granted
2. **Check video format**: Use MOV with H.264 or H.265 codec
3. **Check video duration**: Keep videos short (1-3 seconds)

### General Issues

- **File paths**: Ensure file paths are absolute and files exist
- **File sizes**: Very large files may cause memory issues
- **Platform differences**: iOS and Android have different format requirements

## Example App

See the [example](example/) directory for a complete demo app showing:

- Image and video picking
- Live Photo generation
- Platform-specific handling
- Error handling

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Motion Photo format reference: [Motion Photo Parser](https://motion-photo-parser.site.0to1.cf/)
- XMP metadata specifications from Google, OPPO, and Xiaomi

---

<a name="中文"></a>

# flutter_live_photos

一个用于生成和保存 iOS 实况照片和 Android 动态照片的 Flutter 插件，支持多种设备。

[![pub package](https://img.shields.io/pub/v/flutter_live_photos.svg)](https://pub.dev/packages/flutter_live_photos)

## 功能特性

- ✅ **iOS 实况照片**：从 JPG/HEIC 图片和 MOV 视频生成实况照片，自动配对元数据
- ✅ **Android 动态照片**：生成兼容多个厂商的动态照片：
  - Google Pixel（Google 相册）
  - OPPO/Realme（ColorOS/RealmeUI）
  - Xiaomi（MIUI/HyperOS）
  - 其他安装了 Google 相册的 Android 设备
- ✅ **智能 XMP 合并**：保留原图元数据（HDR GainMap 等），同时添加动态照片字段
- ✅ **自动保存**：
  - iOS：直接保存到相册
  - Android：保存到应用缓存目录（可移动到相册）

## 安装

在 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  flutter_live_photos: ^0.1.0
```

然后运行：

```bash
flutter pub get
```

## 平台配置

### iOS

在 `Info.plist` 文件中添加以下权限：

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>需要访问相册以保存实况照片</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>需要权限将实况照片保存到相册</string>
```

### Android

无需特殊权限。插件会在应用缓存目录生成动态照片。如需保存到公共相册，可使用文件选择器或媒体存储 API。

## 使用方法

### 基础示例

```dart
import 'package:flutter_live_photos/flutter_live_photos.dart';
import 'package:image_picker/image_picker.dart';

class LivePhotoExample extends StatefulWidget {
  @override
  _LivePhotoExampleState createState() => _LivePhotoExampleState();
}

class _LivePhotoExampleState extends State<LivePhotoExample> {
  final _plugin = FlutterLivePhotos();
  final _picker = ImagePicker();

  String? _imagePath;
  String? _videoPath;

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _imagePath = image.path);
    }
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() => _videoPath = video.path);
    }
  }

  Future<void> _generateLivePhoto() async {
    if (_imagePath == null || _videoPath == null) {
      print('请同时选择图片和视频');
      return;
    }

    try {
      final result = await _plugin.generate(
        imagePath: _imagePath!,
        videoPath: _videoPath!,
      );

      if (Platform.isIOS) {
        if (result == true) {
          print('✅ 实况照片已保存到相册！');
        }
      } else {
        print('✅ 动态照片已生成：$result');
      }
    } catch (e) {
      print('❌ 错误：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('实况照片演示')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _pickImage,
            child: Text('选择图片'),
          ),
          ElevatedButton(
            onPressed: _pickVideo,
            child: Text('选择视频'),
          ),
          ElevatedButton(
            onPressed: _generateLivePhoto,
            child: Text('生成实况照片'),
          ),
        ],
      ),
    );
  }
}
```

### API 参考

#### `generate()`

生成实况照片（iOS）或动态照片（Android）。

```dart
Future<dynamic> generate({
  required String imagePath,
  required String videoPath,
})
```

**参数：**

- `imagePath`：图片文件路径
  - iOS：JPG 或 HEIC
  - Android：JPG（必需）
- `videoPath`：视频文件路径
  - iOS：MOV（推荐 H.264/H.265 编码）
  - Android：MP4

**返回值：**

- iOS：`bool` - 成功保存到相册返回 `true`
- Android：`String` - 生成的动态照片文件路径

**异常：**

- 生成失败时抛出 `PlatformException`

#### `getPlatformVersion()`

返回平台版本字符串。

```dart
Future<String?> getPlatformVersion()
```

## 系统要求

### iOS

- **图片格式**：JPG 或 HEIC
- **视频格式**：MOV（H.264 或 H.265 编码）
- **视频时长**：通常 1-3 秒
- **iOS 版本**：iOS 9.1+

### Android

- **图片格式**：JPG（必需）
- **视频格式**：MP4
- **视频时长**：通常 1-3 秒
- **Android 版本**：Android 5.0+（API 21+）

## 设备兼容性

### 已测试设备

✅ **iOS**：

- iPhone（iOS 9.1+）
- iPad（iOS 9.1+）

✅ **Android**：

- Google Pixel（所有型号）
- OPPO/Realme（ColorOS 7+）
- Xiaomi（MIUI 11+、HyperOS）
- Samsung（需安装 Google 相册）
- 其他 Android 设备（需安装 Google 相册）

### 动态照片格式支持

插件生成的动态照片包含 XMP 元数据，兼容：

- **Google 相册**：所有设备完全支持
- **OPPO/Realme 相册**：原生支持（`OpCamera` 元数据）
- **小米相册**：原生支持（`MiCamera` 元数据）
- **三星相册**：通过 Google 相册集成支持

## 技术细节

### iOS 实现

- 使用 `AVFoundation` 和 `PhotoKit` 框架
- 向图片 EXIF 和视频 QuickTime 元数据注入 `assetIdentifier`
- 为相册创建正确的实况照片配对

### Android 实现

- 将 MP4 视频数据附加到 JPG 图片
- 注入 XMP 元数据，支持多种动态照片规范：
  - Google Camera v2 格式
  - OPPO/Realme OLivePhoto v2 格式
  - Xiaomi MicroVideo 格式
- 智能 XMP 合并保留原图元数据（HDR GainMap 等）
- 正确维护 JPEG APP1 段结构

## 故障排除

### Android：动态照片无法识别

1. **检查图片格式**：必须是 JPG（不能是 PNG 或其他格式）
2. **检查视频格式**：必须是 MP4
3. **验证文件完整性**：确保文件有效且未损坏
4. **使用 Google 相册测试**：安装 Google 相册应用以确保兼容性

### iOS：实况照片未显示

1. **检查权限**：确保已授予相册访问权限
2. **检查视频格式**：使用 H.264 或 H.265 编码的 MOV 格式
3. **检查视频时长**：保持视频简短（1-3 秒）

### 常见问题

- **文件路径**：确保文件路径是绝对路径且文件存在
- **文件大小**：超大文件可能导致内存问题
- **平台差异**：iOS 和 Android 有不同的格式要求

## 示例应用

查看 [example](example/) 目录获取完整演示应用，包含：

- 图片和视频选择
- 实况照片生成
- 平台特定处理
- 错误处理

## 贡献

欢迎贡献！请随时提交 Pull Request。

## 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件。

## 致谢

- 动态照片格式参考：[Motion Photo Parser](https://motion-photo-parser.site.0to1.cf/)
- XMP 元数据规范来自 Google、OPPO 和 Xiaomi
