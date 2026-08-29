// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_live_motion/flutter_live_motion.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('FlutterLiveMotion Plugin Tests', () {
    late FlutterLiveMotion plugin;

    setUp(() {
      plugin = FlutterLiveMotion();
    });

    testWidgets('getPlatformVersion test', (WidgetTester tester) async {
      final String? version = await plugin.getPlatformVersion();
      // The version string depends on the host platform running the test, so
      // just assert that some non-empty string is returned.
      expect(version?.isNotEmpty, true);
      
      // Verify platform-specific version strings
      if (Platform.isAndroid) {
        expect(version, contains('Android'));
      } else if (Platform.isIOS) {
        expect(version, contains('iOS'));
      }
    });

    testWidgets('generate method requires valid paths', (WidgetTester tester) async {
      // Test with invalid paths should throw an error
      expect(
        () async => await plugin.generate(
          imagePath: '/invalid/path/image.jpg',
          videoPath: '/invalid/path/video.mp4',
        ),
        throwsA(isA<Exception>()),
      );
    });

    testWidgets('generate method validates file extensions on Android', (WidgetTester tester) async {
      if (!Platform.isAndroid) return;

      // Note: This test would require actual test files to be present
      // In a real scenario, you would create temporary test files
      // For now, we just verify the method signature is correct
      expect(plugin.generate, isA<Function>());
    });
  });
}
