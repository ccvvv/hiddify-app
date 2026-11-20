import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/domestic_probe/model/domestic_probe_report_builder.dart';
import 'package:hiddify/features/domestic_probe/model/domestic_probe_task.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';

void main() {
  final task = DomesticProbeTask(
    taskId: 'mi6-123456789-1',
    status: DomesticProbeTaskStatus.pending,
    targetDeviceId: 'mi6-probe-01',
    scope: DomesticProbeTask.supportedScope,
    maxNodes: 2,
    createdAt: DateTime.utc(2026, 11, 20, 10),
    expiresAt: DateTime.utc(2026, 11, 20, 16),
  );

  test('builds sanitized report from fresh per-node download speeds', () {
    var nextId = 0;
    final builder = DomesticProbeReportBuilder(createNodeId: () => 'node-id-0000000${nextId++}');
    final report = builder.build(
      task: task,
      testedAt: DateTime.utc(2026, 11, 20, 12),
      outbounds: [
        OutboundInfo(
          tag: 'private-server-name',
          type: 'Shadowsocks',
          isVisible: true,
          downloadSpeed: Int64(125000),
          urlTestDelay: 120,
        ),
        OutboundInfo(
          tag: 'old-cached-node',
          type: 'VLESS',
          isVisible: true,
          downloadSpeed: Int64(900000),
          downloadSpeedCached: true,
          urlTestDelay: 0,
        ),
        OutboundInfo(
          tag: 'group-entry',
          type: 'Selector',
          isVisible: true,
          isGroup: true,
          downloadSpeed: Int64(800000),
        ),
        OutboundInfo(
          tag: 'hidden-entry§hide§secret',
          type: 'VMess',
          isVisible: true,
          downloadSpeed: Int64(800000),
        ),
      ],
    );

    final results = report['results'] as List<Map<String, dynamic>>;
    expect(results, hasLength(2));
    expect(results[0]['status'], 'passed');
    expect(results[0]['protocol'], 'shadowsocks');
    expect(results[0]['download_kbps'], 1000);
    expect(results[0]['latency_ms'], 120);
    expect(results[1]['status'], 'inconclusive');
    expect(results[1]['download_kbps'], isNull);
    expect(report['device_id'], 'mi6-probe-01');
    expect(report.toString(), isNot(contains('private-server-name')));
    expect(report.toString(), isNot(contains('old-cached-node')));
  });

  test('limits candidates to task max and marks failed speeds', () {
    final builder = DomesticProbeReportBuilder(createNodeId: () => 'node-id-12345678');
    final report = builder.build(
      task: task,
      outbounds: [
        OutboundInfo(tag: 'failed-node', type: 'Trojan', isVisible: true, downloadSpeed: Int64(-1)),
        OutboundInfo(tag: 'third-node', type: 'TUIC', isVisible: true, downloadSpeed: Int64(5000)),
        OutboundInfo(tag: 'must-not-include', type: 'VMess', isVisible: true, downloadSpeed: Int64(5000)),
      ],
    );
    final results = report['results'] as List<Map<String, dynamic>>;
    expect(results, hasLength(2));
    expect(results.first['status'], 'failed');
    expect(results.first['protocol'], 'trojan');
  });

  test('rejects duplicate or invalid generated node IDs', () {
    final builder = DomesticProbeReportBuilder(createNodeId: () => 'short');
    expect(
      () => builder.build(
        task: task,
        outbounds: [OutboundInfo(tag: 'node', type: 'SS', isVisible: true)],
      ),
      throwsStateError,
    );
  });

  test('rejects empty candidate lists', () {
    final builder = DomesticProbeReportBuilder();
    expect(() => builder.build(task: task, outbounds: []), throwsStateError);
  });
}
