/// A task published by the owner's AutoSubHub repository for the Mi 6 probe.
///
/// This object contains task metadata only; it must never carry proxy credentials.
enum DomesticProbeTaskStatus { pending, completed }

class DomesticProbeTask {
  const DomesticProbeTask({
    required this.taskId,
    required this.status,
    required this.targetDeviceId,
    required this.scope,
    required this.maxNodes,
    required this.createdAt,
    required this.expiresAt,
  });

  final String taskId;
  final DomesticProbeTaskStatus status;
  final String targetDeviceId;
  final String scope;
  final int maxNodes;
  final DateTime createdAt;
  final DateTime expiresAt;

  static const supportedSchemaVersion = 1;
  static const supportedScope = 'active-hiddify-profile';

  factory DomesticProbeTask.fromJson(Map<String, dynamic> json) {
    if (json['schema_version'] != supportedSchemaVersion) {
      throw const FormatException('Unsupported domestic probe task schema');
    }

    final taskId = json['task_id'];
    final statusValue = json['status'];
    final targetDeviceId = json['target_device_id'];
    final scope = json['scope'];
    final maxNodes = json['max_nodes'];
    final createdAtValue = json['created_at'];
    final expiresAtValue = json['expires_at'];

    if (taskId is! String || !RegExp(r'^mi6-[0-9]{5,}-[0-9]+$').hasMatch(taskId)) {
      throw const FormatException('Invalid domestic probe task ID');
    }
    if (statusValue is! String || !['pending', 'completed'].contains(statusValue)) {
      throw const FormatException('Invalid domestic probe task status');
    }
    if (targetDeviceId is! String || targetDeviceId.isEmpty || targetDeviceId.length > 40) {
      throw const FormatException('Invalid target device ID');
    }
    if (scope != supportedScope) {
      throw const FormatException('Unsupported domestic probe task scope');
    }
    if (maxNodes is! int || maxNodes < 1 || maxNodes > 50) {
      throw const FormatException('Invalid maximum node count');
    }
    if (createdAtValue is! String || expiresAtValue is! String) {
      throw const FormatException('Missing task timestamps');
    }

    final createdAt = DateTime.tryParse(createdAtValue)?.toUtc();
    final expiresAt = DateTime.tryParse(expiresAtValue)?.toUtc();
    if (createdAt == null || expiresAt == null || !expiresAt.isAfter(createdAt)) {
      throw const FormatException('Invalid task expiry window');
    }

    return DomesticProbeTask(
      taskId: taskId,
      status: DomesticProbeTaskStatus.values.byName(statusValue),
      targetDeviceId: targetDeviceId,
      scope: scope as String,
      maxNodes: maxNodes,
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }

  bool isRunnableFor(String deviceId, {DateTime? now}) {
    final currentTime = (now ?? DateTime.now()).toUtc();
    return status == DomesticProbeTaskStatus.pending &&
        targetDeviceId == deviceId &&
        currentTime.isBefore(expiresAt) &&
        !currentTime.isBefore(createdAt.subtract(const Duration(minutes: 5)));
  }
}