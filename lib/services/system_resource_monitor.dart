import 'dart:io';

import 'package:mixbuild_dashboard/services/mixbuild_command_runner.dart';
import 'package:system_resources_2/system_resources_2.dart';

class SystemResourceSnapshot {
  const SystemResourceSnapshot({
    required this.cpuUsagePercent,
    required this.memoryUsedBytes,
    required this.totalMemoryBytes,
  });

  factory SystemResourceSnapshot.fallback() {
    return SystemResourceSnapshot(
      cpuUsagePercent: 0,
      memoryUsedBytes: ProcessInfo.currentRss,
      totalMemoryBytes: 0,
    );
  }

  final double cpuUsagePercent;
  final int memoryUsedBytes;
  final int totalMemoryBytes;

  double get cpuProgress => (cpuUsagePercent / 100).clamp(0, 1);

  double get memoryProgress {
    if (totalMemoryBytes <= 0) {
      return 0;
    }
    return (memoryUsedBytes / totalMemoryBytes).clamp(0, 1);
  }

  String get cpuLabel {
    final fractionDigits = cpuUsagePercent >= 10 ? 0 : 1;
    return '${cpuUsagePercent.toStringAsFixed(fractionDigits)}%';
  }

  String get memoryLabel {
    final usedGb = memoryUsedBytes / (1024 * 1024 * 1024);
    if (totalMemoryBytes <= 0) {
      return '${usedGb.toStringAsFixed(1)}GB';
    }
    final totalGb = totalMemoryBytes / (1024 * 1024 * 1024);
    final totalDigits = totalGb >= 10 ? 0 : 1;
    return '${usedGb.toStringAsFixed(1)}/${totalGb.toStringAsFixed(totalDigits)}GB';
  }
}

abstract class SystemResourceMonitor {
  Future<SystemResourceSnapshot> sample();
}

class ProcessSystemResourceMonitor implements SystemResourceMonitor {
  ProcessSystemResourceMonitor(this._runner);

  final MixbuildCommandRunner _runner;
  Future<void>? _initializeFuture;
  bool _nativeLibraryUnavailable = false;

  Future<void> _ensureInitialized() {
    return _initializeFuture ??= SystemResources.init();
  }

  @override
  Future<SystemResourceSnapshot> sample() async {
    if (Platform.isLinux) {
      await _ensureInitialized();
      return _sampleWithSystemResources();
    }
    if (Platform.isMacOS) {
      if (_nativeLibraryUnavailable) {
        return _sampleMacOsFallback();
      }
      try {
        await _ensureInitialized();
        return _sampleWithSystemResources();
      } catch (_) {
        _nativeLibraryUnavailable = true;
        return _sampleMacOsFallback();
      }
    }
    return SystemResourceSnapshot.fallback();
  }

  SystemResourceSnapshot _sampleWithSystemResources() {
    return SystemResourceSnapshot(
      cpuUsagePercent: (SystemResources.cpuLoadAvg() * 100).clamp(0, 100),
      memoryUsedBytes: SystemResources.memoryUsedBytes(),
      totalMemoryBytes: SystemResources.memoryLimitBytes(),
    );
  }

  Future<SystemResourceSnapshot> _sampleMacOsFallback() async {
    final result = await _runner.run(
      'top -l 1',
      workingDirectory: Directory.current.path,
    );
    if (result.exitCode != 0) {
      return SystemResourceSnapshot.fallback();
    }

    final lines = result.stdout.split('\n');
    final cpuLine = _firstLineStartingWith(lines, 'CPU usage:');
    final memoryLine = _firstLineStartingWith(lines, 'PhysMem:');
    if (cpuLine == null || memoryLine == null) {
      return SystemResourceSnapshot.fallback();
    }

    final cpuUsagePercent = _parseMacOsCpuUsage(cpuLine);
    final memoryUsage = _parseMacOsMemoryUsage(memoryLine);
    if (cpuUsagePercent == null || memoryUsage == null) {
      return SystemResourceSnapshot.fallback();
    }

    return SystemResourceSnapshot(
      cpuUsagePercent: cpuUsagePercent,
      memoryUsedBytes: memoryUsage.usedBytes,
      totalMemoryBytes: memoryUsage.totalBytes,
    );
  }

  String? _firstLineStartingWith(List<String> lines, String prefix) {
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith(prefix)) {
        return trimmed;
      }
    }
    return null;
  }

  double? _parseMacOsCpuUsage(String line) {
    final idleMatch = RegExp(r'([\d.]+)%\s+idle').firstMatch(line);
    if (idleMatch == null) {
      return null;
    }
    final idlePercent = double.tryParse(idleMatch.group(1)!);
    if (idlePercent == null) {
      return null;
    }
    return (100 - idlePercent).clamp(0, 100).toDouble();
  }

  _MemoryUsage? _parseMacOsMemoryUsage(String line) {
    final usedMatch = RegExp(r'PhysMem:\s+([^ ]+)\s+used').firstMatch(line);
    final unusedMatch = RegExp(r'([^,]+)\s+unused\.?$').firstMatch(line);
    if (usedMatch == null || unusedMatch == null) {
      return null;
    }
    final usedBytes = _parseByteSize(usedMatch.group(1)!);
    final unusedBytes = _parseByteSize(unusedMatch.group(1)!);
    if (usedBytes == null || unusedBytes == null) {
      return null;
    }
    return _MemoryUsage(
      usedBytes: usedBytes,
      totalBytes: usedBytes + unusedBytes,
    );
  }

  int? _parseByteSize(String rawValue) {
    final normalized = rawValue.trim().toUpperCase();
    final match = RegExp(r'^([\d.]+)([KMGTP])$').firstMatch(normalized);
    if (match == null) {
      return null;
    }
    final value = double.tryParse(match.group(1)!);
    final unit = match.group(2);
    if (value == null || unit == null) {
      return null;
    }
    final multiplier = switch (unit) {
      'K' => 1024,
      'M' => 1024 * 1024,
      'G' => 1024 * 1024 * 1024,
      'T' => 1024 * 1024 * 1024 * 1024,
      'P' => 1024 * 1024 * 1024 * 1024 * 1024,
      _ => 1,
    };
    return (value * multiplier).round();
  }
}

class _MemoryUsage {
  const _MemoryUsage({
    required this.usedBytes,
    required this.totalBytes,
  });

  final int usedBytes;
  final int totalBytes;
}
