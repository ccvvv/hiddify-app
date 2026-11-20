/// Status for an individual probe stage.
enum ProbeCheckStatus { passed, failed, inconclusive }

/// A sanitized result for testing one outbound from the phone's current network.
///
/// A successful download through the selected proxy is the primary usability
/// signal. GPT reachability is optional metadata and never gates usability.
class DomesticProbeResult {
  const DomesticProbeResult({
    required this.nodeId,
    required this.downloadStatus,
    required this.checkedAt,
    this.gptStatus,
    this.speedKiBPerSecond,
    this.protocol,
    this.latencyMs,
    this.httpStatus,
    this.failureCategory,
    this.attempts = 1,
  });

  /// Opaque identifier generated locally; it must not encode an address or credential.
  final String nodeId;
  final String? protocol;

  /// Whether a non-empty download completed through the selected proxy.
  final ProbeCheckStatus downloadStatus;

  /// Optional ChatGPT reachability result. It does not affect [usable].
  final ProbeCheckStatus? gptStatus;

  final double? speedKiBPerSecond;
  final int? latencyMs;

  /// HTTP status only; do not store the full response body or URL.
  final int? httpStatus;
  final String? failureCategory;
  final int attempts;
  final DateTime checkedAt;

  static const minimumSpeedKiBPerSecond = 500.0;

  /// A node is usable when the selected proxy successfully downloaded data.
  bool get usable =>
      downloadStatus == ProbeCheckStatus.passed &&
      speedKiBPerSecond != null &&
      speedKiBPerSecond! > 0;

  /// Compatibility alias for existing UI/report consumers.
  bool get passed => usable;

  /// A ranking label, not the definition of basic usability.
  bool get speedPassed =>
      usable && speedKiBPerSecond! >= minimumSpeedKiBPerSecond;
}
