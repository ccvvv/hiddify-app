import 'dart:convert';
import 'dart:math';

import 'package:hiddify/features/domestic_probe/model/domestic_probe_task.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';

/// Converts fresh Hiddify core download-speed fields into a privacy-safe report.
///
/// IDs are random per report rather than hashes of proxy tags. This prevents
/// common server names from being guessed from a public digest. No proxy tag,
/// address, UUID, or credential leaves the device.
class DomesticProbeReportBuilder {
  DomesticProbeReportBuilder({String Function()? createNodeId})
    : _createNodeId = createNodeId ?? _randomNodeId;

  final String Function() _createNodeId;

  Map<String, dynamic> build({
    required DomesticProbeTask task,
    required List<OutboundInfo> outbounds,
    DateTime? testedAt,
  }) {
    final candidates = outbounds
        .where((item) => !item.isGroup && item.isVisible && !item.tag.contains('§hide§'))
        .take(task.maxNodes)
        .toList(growable: false);

    if (candidates.isEmpty) {
      throw StateError('No visible proxy nodes are available for this task');
    }

    final ids = <String>{};
    final results = candidates.map((item) {
      final nodeId = _createNodeId();
      if (!RegExp(r'^[A-Za-z0-9_-]{8,80}$').hasMatch(nodeId) || !ids.add(nodeId)) {
        throw StateError('Node ID generator returned an invalid or duplicate ID');
      }

      final bytesPerSecond = item.downloadSpeed.toInt();
      final isFresh = !item.downloadSpeedCached;
      final status = !isFresh || bytesPerSecond == 0
          ? 'inconclusive'
          : bytesPerSecond > 0
              ? 'passed'
              : 'failed';
      final latency = item.urlTestDelay > 0 && item.urlTestDelay < 65000
          ? item.urlTestDelay
          : null;

      return <String, dynamic>{
        'node_id': nodeId,
        'protocol': _protocolOf(item.type),
        'status': status,
        'download_kbps': status == 'passed' ? bytesPerSecond * 8 / 1000 : null,
        'latency_ms': latency,
        'gpt_ok': null,
      };
    }).toList(growable: false);

    return {
      'task_id': task.taskId,
      'device_id': task.targetDeviceId,
      'network': 'mainland-wifi',
      'tested_at': (testedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'results': results,
    };
  }

  static String _protocolOf(String type) {
    final value = type.toLowerCase();
    if (value.contains('shadowsocks') || value == 'ss') return 'shadowsocks';
    if (value.contains('vmess')) return 'vmess';
    if (value.contains('vless')) return 'vless';
    if (value.contains('trojan')) return 'trojan';
    if (value.contains('hysteria2') || value.contains('hysteria 2')) return 'hysteria2';
    if (value.contains('tuic')) return 'tuic';
    return 'other';
  }

  static String _randomNodeId() {
    final random = Random.secure();
    final bytes = List<int>.generate(18, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
