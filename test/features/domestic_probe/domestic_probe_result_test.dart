import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/domestic_probe/model/domestic_probe_result.dart';

void main() {
  DomesticProbeResult result({
    ProbeCheckStatus gpt = ProbeCheckStatus.passed,
    double? speed = 500,
  }) => DomesticProbeResult(
    nodeId: 'opaque-test-id',
    gptStatus: gpt,
    speedKiBPerSecond: speed,
    checkedAt: DateTime.utc(2026, 1, 1),
  );

  test('requires both GPT reachability and the 500 KiB/s threshold', () {
    expect(result().passed, isTrue);
    expect(result(speed: 499.9).passed, isFalse);
    expect(result(gpt: ProbeCheckStatus.failed).passed, isFalse);
    expect(result(gpt: ProbeCheckStatus.inconclusive).passed, isFalse);
  });

  test('does not treat a missing speed measurement as passing', () {
    expect(result(speed: null).speedPassed, isFalse);
    expect(result(speed: null).passed, isFalse);
  });
}
