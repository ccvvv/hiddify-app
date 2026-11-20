/// The result of checking one outbound from the phone's current network.
enum ProbeCheckStatus { passed, failed, inconclusive }

/// A deliberately sanitized result. Never put a raw outbound tag, address, UUID,
/// password, subscription URL, or serialized proxy configuration in this model.
class DomesticProbeResult {
  const DomesticProbeResult({
    required this.nodeId,
    required this.gptStatus,
    required this.speedKiBPerSecond,
    required this.checkedAt,
    this.protocol,
    this.latencyMs,
    this.httpStatus,
    this.failureCategory,
    this.attempts = 1,
  });

  /// Opaque identifier generated locally; it must not encode a server address or credential.
  final String nodeId;
  final String? protocol;
  final ProbeCheckStatus gptStatus;
  final double? speedKiBPerSecond;
  final int? latencyMs;

  /// HTTP status only; do not store the full response body or URL.
  final int? httpStatus;
  final String? failureCategory;
  final int attempts;
  final DateTime checkedAt;

  static const minimumSpeedKiBPerSecond = 500.0;

  bool get speedPassed =>
      speedKiBPerSecond != null && speedKiBPerSecond! >= minimumSpeedKiBPerSecond;

  /// GPT reachability and throughput are separate checks. Both must pass for
  /// the node to be recommended by the first domestic probe.
  bool get passed => gptStatus == ProbeCheckStatus.passed && speedPassed;
}
