import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('macOS window sets minimum size and fixed aspect ratio', () async {
    final source = await File('macos/Runner/MainFlutterWindow.swift')
        .readAsString();

    expect(source, contains('let baseContentSize = NSSize(width: 1024, height: 720)'));
    expect(source, contains('minSize = NSSize(width: 1024, height: 720)'));
    expect(
      source,
      contains('contentAspectRatio = baseContentSize'),
    );
  });

  test('Windows runner enforces minimum size and fixed aspect ratio',
      () async {
    final windowsMain = await File('windows/runner/main.cpp').readAsString();
    final flutterWindowHeader =
        await File('windows/runner/flutter_window.h').readAsString();
    final flutterWindowSource =
        await File('windows/runner/flutter_window.cpp').readAsString();
    final win32WindowSource =
        await File('windows/runner/win32_window.cpp').readAsString();

    expect(
      flutterWindowHeader,
      contains('static constexpr Size kMinimumSize = Size(1024, 720);'),
    );
    expect(windowsMain, contains('Win32Window::Size size(1280, 900);'));
    expect(flutterWindowSource, contains('SetMinSize(kMinimumSize);'));
    expect(flutterWindowSource, contains('SetAspectRatio(kMinimumSize);'));
    expect(win32WindowSource, contains('WM_GETMINMAXINFO'));
    expect(win32WindowSource, contains('WM_SIZING'));
  });
}
