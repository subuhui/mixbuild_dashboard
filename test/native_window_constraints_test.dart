import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('macOS window sets minimum size', () async {
    final source = await File('macos/Runner/MainFlutterWindow.swift')
        .readAsString();

    expect(source, contains('minSize = NSSize(width: 960, height: 720)'));
  });

  test('Windows runner enforces minimum window tracking size', () async {
    final flutterWindowHeader =
        await File('windows/runner/flutter_window.h').readAsString();
    final flutterWindowSource =
        await File('windows/runner/flutter_window.cpp').readAsString();
    final win32WindowSource =
        await File('windows/runner/win32_window.cpp').readAsString();

    expect(flutterWindowHeader, contains('static constexpr Size kMinimumSize'));
    expect(flutterWindowSource, contains('SetMinSize(kMinimumSize);'));
    expect(win32WindowSource, contains('WM_GETMINMAXINFO'));
  });
}
