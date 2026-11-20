import 'package:dio/dio.dart';

/// Sends a sanitized domestic probe report to the owner's GitHub repository.
///
/// The caller must obtain [token] from secure storage. Never persist it in
/// preferences, include it in a report, or log request headers/body.
class DomesticProbeResultClient {
  DomesticProbeResultClient({Dio? dio}) : _dio = dio ?? Dio();

  static const dispatchUrl =
      'https://api.github.com/repos/ccvvv/AutoSubHub/dispatches';

  final Dio _dio;

  /// Returns true only when GitHub accepts the dispatch (HTTP 204).
  ///
  /// This means the event was accepted, not that the Actions workflow has
  /// finished validating and storing the report.
  Future<bool> dispatch({
    required String token,
    required Map<String, dynamic> report,
  }) async {
    if (token.trim().isEmpty) {
      throw ArgumentError.value(token, 'token', 'GitHub token is required');
    }
    _validateReport(report);

    final response = await _dio.post<void>(
      dispatchUrl,
      data: {
        'event_type': 'domestic-probe-results',
        'client_payload': report,
      },
      options: Options(
        headers: {
          'Accept': 'application/vnd.github+json',
          'Authorization': 'Bearer $token',
          'X-GitHub-Api-Version': '2022-11-28',
          'Content-Type': 'application/json',
        },
        validateStatus: (status) => status == 204,
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    return response.statusCode == 204;
  }

  void _validateReport(Map<String, dynamic> report) {
    final deviceId = report['device_id'];
    final network = report['network'];
    final testedAt = report['tested_at'];
    final candidateRevision = report['candidate_revision'];
    final results = report['results'];

    // task_id is deliberately optional: the probe can upload a scheduled
    // domestic test receipt without receiving an individual GitHub task.
    final taskId = report['task_id'];
    if (taskId != null &&
        (taskId is! String ||
            !RegExp(r'^mi6-[0-9]{5,}-[0-9]+$').hasMatch(taskId))) {
      throw const FormatException('Invalid optional task_id');
    }
    if (deviceId != 'mi6-probe-01') {
      throw const FormatException('Unexpected probe device_id');
    }
    if (network != 'mainland-wifi') {
      throw const FormatException('Unexpected probe network');
    }
    if (testedAt is! String || testedAt.length > 40) {
      throw const FormatException('Invalid tested_at');
    }
    DateTime.parse(testedAt);
    if (candidateRevision is! String || candidateRevision.length > 40) {
      throw const FormatException('Invalid candidate_revision');
    }
    DateTime.parse(candidateRevision);
    if (results is! List || results.isEmpty || results.length > 50) {
      throw const FormatException('Report must contain 1..50 results');
    }

    final nodeIdPattern = RegExp(r'^probe_[a-f0-9]{24}$');
    const protocols = {
      'shadowsocks',
      'vmess',
      'vless',
      'trojan',
      'hysteria2',
      'tuic',
      'other',
    };
    const statuses = {'passed', 'failed', 'inconclusive'};
    final seenNodeIds = <String>{};

    for (final entry in results) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('Invalid result entry');
      }
      final nodeId = entry['node_id'];
      if (nodeId is! String ||
          !nodeIdPattern.hasMatch(nodeId) ||
          !seenNodeIds.add(nodeId)) {
        throw const FormatException('Invalid or duplicate stable node_id');
      }
      if (!protocols.contains(entry['protocol'])) {
        throw const FormatException('Invalid protocol');
      }
      if (!statuses.contains(entry['status'])) {
        throw const FormatException('Invalid status');
      }
      final speed = entry['download_kbps'];
      final latency = entry['latency_ms'];
      if (speed != null &&
          (speed is! num || speed < 0 || speed > 1000000)) {
        throw const FormatException('Invalid download_kbps');
      }
      if (latency != null &&
          (latency is! num || latency < 0 || latency > 600000)) {
        throw const FormatException('Invalid latency_ms');
      }
      final gptOk = entry['gpt_ok'];
      if (gptOk != null && gptOk is! bool) {
        throw const FormatException('Invalid gpt_ok');
      }
    }
  }
}
