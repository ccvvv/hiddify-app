import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/domestic_probe/model/domestic_probe_result.dart';

void main() {
  DomesticProbeResult result({
    ProbeCheckStatus download = ProbeCheckStatus.passed,
    ProbeCheckStatus? gpt,
    double? speed = 500,
  }) => DomesticProbeResult(
    nodeId: 'opaque-test-id',
    downloadStatus: download,
    gptStatus: gpt,
    speedKiBPerSecond: speed,
    checkedAt: DateTime.utc(2026, 1, 1),
  );

  test('a successful download makes a node usable even below 500 KiB/s', () {
    expect(result(speed: 12).usable, isTrue);
    expect(result(speed: 12).passed, isTrue);
    expect(result(speed: 12).speedPassed, isFalse);
  });

  test('500 KiB/s or faster is marked as speed-passed', () {
    expect(result().speedPassed, isTrue);
    expect(result(speed: 499.9).speedPassed, isFalse);
  });

  test('GPT status is optional and never gates usability', () {
    expect(result(gpt: null).usable, isTrue);
    expect(result(gpt: ProbeCheckStatus.failed).usable, isTrue);
    expect(result(gpt: ProbeCheckStatus.inconclusive).usable, isTrue);
  });

  test('a failed or inconclusive download is not usable', () {
    expect(result(download: ProbeCheckStatus.failed).usable, isFalse);
    expect(result(download: ProbeCheckStatus.inconclusive).usable, isFalse);
  });

  test('missing or zero download speed cannot be treated as usable', () {
    expect(result(speed: null).usable, isFalse);
    expect(result(speed: 0).usable, isFalse);
  });

  test('a high speed cannot override a failed download status', () {
    expect(result(download: ProbeCheckStatus.failed, speed: 9000).usable, isFalse);
  });
}
