import 'dart:io';

import 'package:mixbuild_dashboard/services/mixbuild_command_runner.dart';

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

  @override
  Future<SystemResourceSnapshot> sample() async {
    if (Platform.isMacOS) {
      return _sampleMacOsResources();
    }
    return SystemResourceSnapshot.fallback();
  }

  Future<SystemResourceSnapshot> _sampleMacOsResources() async {
    final results = await Future.wait([
      _runner.run('top -l 1 -n 0',
          workingDirectory: Directory.current.path),
      _runner.run('sysctl -n hw.memsize',
          workingDirectory: Directory.current.path),
      _runner.run('vm_stat', workingDirectory: Directory.current.path),
    ]);
    final cpuResult = results[0];
    final memSizeResult = results[1];
    final vmStatResult = results[2];

    final cpuUsagePercent = cpuResult.exitCode == 0
        ? _parseCpuUsageFromTop(cpuResult.stdout)
        : null;

    final totalBytes = memSizeResult.exitCode == 0
        ? int.tryParse(memSizeResult.stdout.trim())
        : null;

    final usedBytes = vmStatResult.exitCode == 0
        ? _parseMacOsUsedMemoryFromVmStat(vmStatResult.stdout)
        : null;

    return SystemResourceSnapshot(
      cpuUsagePercent: cpuUsagePercent ?? 0,
      memoryUsedBytes: usedBytes ?? 0,
      totalMemoryBytes: totalBytes ?? 0,
    );
  }

  double? _parseCpuUsageFromTop(String output) {
    // Parse top output: CPU usage: 12.98% user, 14.2% sys, 72.98% idle
    for (final line in output.split('\n')) {
      if (line.contains('CPU usage:')) {
        final idleMatch = RegExp(r'([\d.]+)%\s+idle').firstMatch(line);
        if (idleMatch == null) return null;
        final idlePercent = double.tryParse(idleMatch.group(1)!);
        if (idlePercent == null) return null;
        return (100 - idlePercent).clamp(0, 100);
      }
    }
    return null;
  }

  int? _parseMacOsUsedMemoryFromVmStat(String output) {
    int? pageSize;
    int? active;
    int? wired;
    int? compressor;

    for (final line in output.split('\n')) {
      if (line.contains('page size of')) {
        final match = RegExp(r'page size of (\d+) bytes').firstMatch(line);
        if (match != null) {
          pageSize = int.tryParse(match.group(1)!);
        }
      } else if (line.startsWith('Pages active:')) {
        active = _extractPageCount(line);
      } else if (line.startsWith('Pages wired down:')) {
        wired = _extractPageCount(line);
      } else if (line.startsWith('Pages occupied by compressor:')) {
        compressor = _extractPageCount(line);
      }
    }

    if (pageSize == null || active == null || wired == null) {
      return null;
    }

    return (active + wired + (compressor ?? 0)) * pageSize;
  }

  int? _extractPageCount(String line) {
    final match = RegExp(r':\s+(\d+)').firstMatch(line);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }
}
