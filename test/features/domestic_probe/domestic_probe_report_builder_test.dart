import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/domestic_probe/model/domestic_probe_report_builder.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';

void main() {
  test('reports stable IDs from candidate tags and excludes private tag text', () {
    final report = DomesticProbeReportBuilder().build(
      candidateRevision: '2026-11-20T11:00:00Z',
      testedAt: DateTime.utc(2026, 11, 20, 12),
      outbounds: [
        OutboundInfo(
          tag: 'probe_0123456789abcdef01234567__private-server-name',
          type: 'Shadowsocks',
          isVisible: true,
          downloadSpeed: Int64(125000),
          urlTestDelay: 120,
        ),
        OutboundInfo(
          tag: 'probe_abcdef0123456789abcdef01__old-cached-node',
          type: 'VLESS',
          isVisible: true,
          downloadSpeed: Int64(900000),
          downloadSpeedCached: true,
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
        OutboundInfo(
          tag: 'not-a-candidate',
          type: 'Trojan',
          isVisible: true,
          downloadSpeed: Int64(100000),
        ),
      ],
    );

    final results = report['results'] as List<Map<String, dynamic>>;
    expect(results, hasLength(2));
    expect(results[0]['node_id'], 'probe_0123456789abcdef01234567');
    expect(results[0]['status'], 'passed');
    expect(results[0]['protocol'], 'shadowsocks');
    expect(results[0]['download_kbps'], 1000);
    expect(results[0]['latency_ms'], 120);
    expect(results[1]['status'], 'inconclusive');
    expect(results[1]['download_kbps'], isNull);
    expect(report['candidate_revision'], '2026-11-20T11:00:00Z');
    expect(report['device_id'], 'mi6-probe-01');
    expect(report.containsKey('task_id'), isFalse);
    expect(report.toString(), isNot(contains('private-server-name')));
    expect(report.toString(), isNot(contains('old-cached-node')));
  });

  test('limits candidates and marks failed speeds', () {
    final report = DomesticProbeReportBuilder().build(
      maxNodes: 1,
      candidateRevision: '2026-11-20T11:00:00Z',
      outbounds: [
        OutboundInfo(
          tag: 'probe_0123456789abcdef01234567__failed-node',
          type: 'Trojan',
          isVisible: true,
          downloadSpeed: Int64(-1),
        ),
        OutboundInfo(
          tag: 'probe_abcdef0123456789abcdef01__second-node',
          type: 'TUIC',
          isVisible: true,
          downloadSpeed: Int64(5000),
        ),
      ],
    );
    final results = report['results'] as List<Map<String, dynamic>>;
    expect(results, hasLength(1));
    expect(results.first['status'], 'failed');
    expect(results.first['protocol'], 'trojan');
  });

  test('rejects duplicate stable candidate IDs', () {
    expect(
      () => DomesticProbeReportBuilder().build(
        candidateRevision: '2026-11-20T11:00:00Z',
        outbounds: [
          OutboundInfo(
            tag: 'probe_0123456789abcdef01234567__node-a',
            type: 'SS',
            isVisible: true,
          ),
          OutboundInfo(
            tag: 'probe_0123456789abcdef01234567__node-b',
            type: 'SS',
            isVisible: true,
          ),
        ],
      ),
      throwsStateError,
    );
  });

  test('rejects empty candidate lists and invalid limits', () {
    expect(
      () => DomesticProbeReportBuilder().build(
        candidateRevision: '2026-11-20T11:00:00Z',
        outbounds: [],
      ),
      throwsStateError,
    );
    expect(
      () => DomesticProbeReportBuilder().build(
        candidateRevision: '2026-11-20T11:00:00Z',
        outbounds: [],
        maxNodes: 0,
      ),
      throwsArgumentError,
    );
  });
}
