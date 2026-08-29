# flutter_live_photos_example

A complete example app demonstrating how to use the `flutter_live_photos` plugin to generate Live Photos (iOS) and Motion Photos (Android).

## Features Demonstrated

- ✅ Image picking from gallery
- ✅ Video picking from gallery
- ✅ Live Photo / Motion Photo generation
- ✅ Platform-specific handling (iOS vs Android)
- ✅ Error handling and user feedback
- ✅ UI validation (disable button until both files selected)

## Running the Example

### Prerequisites

1. Flutter SDK installed
2. iOS Simulator or Android Emulator running
3. Or physical device connected

### Steps

```bash
# Navigate to example directory
cd example

# Get dependencies
flutter pub get

# Run on iOS
flutter run -d ios

# Run on Android
flutter run -d android
```

## Testing on Real Devices

### iOS Testing

1. Connect your iPhone
2. Run: `flutter run -d <your-device-id>`
3. Select an image and video from Photos
4. Tap "GENERATE LIVE PHOTO"
5. Check Photos app for the new Live Photo

### Android Testing

**Tested Devices:**
- ✅ Google Pixel (all models)
- ✅ OPPO/Realme (ColorOS 7+)
- ✅ Xiaomi (MIUI 11+, HyperOS)
- ✅ Samsung (with Google Photos)

**Steps:**
1. Connect your Android device
2. Run: `flutter run -d <your-device-id>`
3. Select a JPG image and MP4 video
4. Tap "GENERATE LIVE PHOTO"
5. Check the output path in the status message
6. Open the file with Gallery or Google Photos app

## Usage Example

```dart
import 'package:flutter_live_photos/flutter_live_photos.dart';
import 'package:image_picker/image_picker.dart';

// Pick image
final XFile? image = await ImagePicker().pickImage(
  source: ImageSource.gallery,
);

// Pick video
final XFile? video = await ImagePicker().pickVideo(
  source: ImageSource.gallery,
);

// Generate Live Photo / Motion Photo
if (image != null && video != null) {
  final result = await FlutterLivePhotos().generate(
    imagePath: image.path,
    videoPath: video.path,
  );
  
  if (Platform.isIOS) {
    print('Saved to Photos: $result');
  } else {
    print('Generated at: $result');
  }
}
```

## Troubleshooting

### iOS

**Issue**: "Photo Library access denied"
- **Solution**: Check Info.plist has `NSPhotoLibraryAddUsageDescription` key

**Issue**: Live Photo not appearing in Photos app
- **Solution**: Ensure video is MOV format with H.264/H.265 codec

### Android

**Issue**: Motion Photo not recognized in Gallery
- **Solution**: 
  1. Ensure image is JPG (not PNG)
  2. Ensure video is MP4
  3. Try opening with Google Photos app

**Issue**: File not found error
- **Solution**: Check that both image and video paths are valid

## Code Structure

```
example/
├── lib/
│   └── main.dart          # Main app with UI and plugin integration
├── test/
│   └── widget_test.dart   # Widget tests
├── integration_test/
│   └── plugin_integration_test.dart  # Integration tests
└── pubspec.yaml
```

## Learn More

- [Plugin Documentation](../README.md)
- [Flutter Documentation](https://docs.flutter.dev/)
- [Image Picker Plugin](https://pub.dev/packages/image_picker)
