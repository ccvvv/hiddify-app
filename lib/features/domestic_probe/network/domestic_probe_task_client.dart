import 'package:dio/dio.dart';
import 'package:hiddify/features/domestic_probe/model/domestic_probe_task.dart';

/// Reads the owner's current Mi 6 task manifest from AutoSubHub.
///
/// The manifest is public metadata only. Result upload credentials are handled
/// separately and must never be added to this client or its URLs.
class DomesticProbeTaskClient {
  DomesticProbeTaskClient({Dio? dio}) : _dio = dio ?? Dio();

  static const taskManifestUrl =
      'https://raw.githubusercontent.com/ccvvv/AutoSubHub/feature/android-domestic-probe-mvp/data/domestic-probe/task.json';
  static const targetDeviceId = 'mi6-probe-01';

  final Dio _dio;

  Future<DomesticProbeTask?> fetchRunnableTask({DateTime? now}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      taskManifestUrl,
      options: Options(
        responseType: ResponseType.json,
        headers: const {'Cache-Control': 'no-cache'},
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 10),
      ),
    );

    final json = response.data;
    if (response.statusCode != 200 || json == null) {
      throw const FormatException('GitHub returned an empty task manifest');
    }

    final task = DomesticProbeTask.fromJson(json);
    return task.isRunnableFor(targetDeviceId, now: now) ? task : null;
  }
}