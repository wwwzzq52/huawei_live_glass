// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_live_motion_example/main.dart';

void main() {
  testWidgets('Verify Platform version', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that platform version is retrieved.
    expect(
      find.byWidgetPredicate((Widget widget) => widget is Text && widget.data!.startsWith('Running on:')),
      findsOneWidget,
    );
  });

  testWidgets('Verify UI elements are present', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app bar is present
    expect(find.text('Live Photos Plugin Demo'), findsOneWidget);

    // Verify that the image picker button is present
    expect(find.text('Pick Image (JPG)'), findsOneWidget);

    // Verify that the video picker button is present
    expect(find.text('Pick Video (MOV/MP4)'), findsOneWidget);

    // Verify that the generate button is present
    expect(find.text('GENERATE LIVE PHOTO'), findsOneWidget);

    // Verify that the status text is present
    expect(find.textContaining('Status:'), findsOneWidget);
  });

  testWidgets('Generate button is disabled initially', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Find the generate button
    final generateButton = find.widgetWithText(ElevatedButton, 'GENERATE LIVE PHOTO');
    expect(generateButton, findsOneWidget);

    // Verify that the button is disabled (onPressed is null)
    final button = tester.widget<ElevatedButton>(generateButton);
    expect(button.onPressed, isNull);
  });
}
