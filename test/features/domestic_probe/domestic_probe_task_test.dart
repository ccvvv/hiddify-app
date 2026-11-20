import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/domestic_probe/model/domestic_probe_task.dart';

void main() {
  final created = DateTime.utc(2026, 11, 20, 10);
  Map<String, dynamic> taskJson({
    String status = 'pending',
    String target = 'mi6-probe-01',
    int maxNodes = 50,
    String expires = '2026-11-20T16:00:00Z',
  }) => {
    'schema_version': 1,
    'task_id': 'mi6-123456789-1',
    'status': status,
    'target_device_id': target,
    'scope': 'active-hiddify-profile',
    'max_nodes': maxNodes,
    'created_at': created.toIso8601String(),
    'expires_at': expires,
  };

  test('parses a valid task and allows its target device', () {
    final task = DomesticProbeTask.fromJson(taskJson());
    expect(task.taskId, 'mi6-123456789-1');
    expect(task.maxNodes, 50);
    expect(task.isRunnableFor('mi6-probe-01', now: DateTime.utc(2026, 11, 20, 11)), isTrue);
  });

  test('does not run completed, expired, or other-device tasks', () {
    expect(DomesticProbeTask.fromJson(taskJson(status: 'completed')).isRunnableFor('mi6-probe-01', now: DateTime.utc(2026, 11, 20, 11)), isFalse);
    expect(DomesticProbeTask.fromJson(taskJson()).isRunnableFor('mi6-probe-01', now: DateTime.utc(2026, 11, 20, 17)), isFalse);
    expect(DomesticProbeTask.fromJson(taskJson(target: 'another-device')).isRunnableFor('mi6-probe-01', now: DateTime.utc(2026, 11, 20, 11)), isFalse);
  });

  test('rejects unsupported schemas, invalid node limits, and invalid expiry', () {
    expect(() => DomesticProbeTask.fromJson({...taskJson(), 'schema_version': 2}), throwsFormatException);
    expect(() => DomesticProbeTask.fromJson(taskJson(maxNodes: 51)), throwsFormatException);
    expect(() => DomesticProbeTask.fromJson(taskJson(expires: '2026-11-20T09:00:00Z')), throwsFormatException);
  });
}