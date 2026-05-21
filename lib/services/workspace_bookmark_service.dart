import 'dart:convert';
import 'dart:io';

import 'package:macos_secure_bookmarks/macos_secure_bookmarks.dart';
import 'package:path/path.dart' as p;

/// macOS Security-Scoped Bookmark 持久化服务。
///
/// 在沙箱应用中，用户通过 NSOpenPanel 选择的目录只在当前会话有效。
/// 本服务在用户选目录时创建 security-scoped bookmark 并写入 JSON 文件，
/// 下次应用启动时通过 [restoreAll] 自动恢复访问权限。
///
/// 非 macOS 平台所有方法均为 no-op，不影响跨平台编译。
class WorkspaceBookmarkService {
  static final _secureBookmarks = SecureBookmarks();
  static final WorkspaceBookmarkService _instance =
      WorkspaceBookmarkService._();

  factory WorkspaceBookmarkService() => _instance;
  WorkspaceBookmarkService._();

  /// 路径 → 书签字符串（base64 编码的 NSData）
  final Map<String, String> _bookmarks = {};

  File get _storageFile {
    // 沙箱应用 $HOME 已被重定向到容器目录
    // ~/Library/Containers/<bundle-id>/Data/Library/Application Support/...
    final home = Platform.environment['HOME'] ?? '.';
    return File(p.join(
      home,
      'Library',
      'Application Support',
      'mixbuild_dashboard',
      'bookmarks.json',
    ));
  }

  /// 应用启动时调用，恢复所有已保存书签的访问权限。
  ///
  /// 恢复成功的路径会立即可访问，失败/过期的书签会被静默跳过。
  Future<void> restoreAll() async {
    if (!Platform.isMacOS) return;
    await _loadFromDisk();
    final staleKeys = <String>[];
    for (final entry in _bookmarks.entries) {
      try {
        final dir = await _secureBookmarks.resolveBookmark(
          entry.value,
          isDirectory: true,
        );
        await _secureBookmarks.startAccessingSecurityScopedResource(dir);
      } catch (_) {
        staleKeys.add(entry.key);
      }
    }
    if (staleKeys.isNotEmpty) {
      for (final key in staleKeys) {
        _bookmarks.remove(key);
      }
      await _saveToDisk();
    }
  }

  /// 用户通过 picker 选择 [path] 后调用，持久化该目录的访问书签。
  ///
  /// 必须在 [getDirectoryPath] 返回有效路径后立即调用，此时 macOS
  /// 已通过 NSOpenPanel 授权了临时访问权限，才能成功创建 security-scoped bookmark。
  Future<void> saveBookmark(String path) async {
    if (!Platform.isMacOS) return;
    try {
      final bookmarkData = await _secureBookmarks.bookmark(Directory(path));
      _bookmarks[path] = bookmarkData;
      await _saveToDisk();
    } catch (_) {
      // 创建书签失败（如路径不存在）时静默忽略，不影响当前会话使用
    }
  }

  Future<void> _loadFromDisk() async {
    try {
      final file = _storageFile;
      if (!file.existsSync()) return;
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      _bookmarks.clear();
      for (final entry in json.entries) {
        _bookmarks[entry.key] = entry.value as String;
      }
    } catch (_) {}
  }

  Future<void> _saveToDisk() async {
    try {
      final file = _storageFile;
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(_bookmarks));
    } catch (_) {}
  }
}
