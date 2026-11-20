import 'package:dio/dio.dart';
import 'package:hiddify/features/domestic_probe/model/domestic_probe_task.dart';

/// Reads the owner's current Mi 6 task manifest from AutoSubHub.
///
/// GitHub is the source of truth. This client deliberately does not depend on
/// DeepSeek: polling a small JSON manifest directly is cheaper and avoids an
/// extra API/service dependency. The manifest contains public task metadata
/// only; upload credentials are handled separately.
class DomesticProbeTaskClient {
  DomesticProbeTaskClient({Dio? dio}) : _dio = dio ?? Dio();

  static const taskManifestUrl =
      'https://raw.githubusercontent.com/ccvvv/AutoSubHub/feature/android-domestic-probe-mvp/data/domestic-probe/task.json';
  static const targetDeviceId = 'mi6-probe-01';
  static const maxAttempts = 3;

  final Dio _dio;

  Future<DomesticProbeTask?> fetchRunnableTask({DateTime? now}) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final response = await _dio.get<Map<String, dynamic>>(
          taskManifestUrl,
          options: Options(
            responseType: ResponseType.json,
            headers: const {
              'Cache-Control': 'no-cache, no-store, max-age=0',
              'Pragma': 'no-cache',
            },
            receiveTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 10),
            // A missing manifest means no task has been published yet.
            validateStatus: (status) => status == 200 || status == 404,
          ),
        );

        if (response.statusCode == 404) return null;

        final json = response.data;
        if (response.statusCode != 200 || json == null) {
          throw const FormatException('GitHub returned an empty task manifest');
        }

        final task = DomesticProbeTask.fromJson(json);
        return task.isRunnableFor(targetDeviceId, now: now) ? task : null;
      } on DioException catch (error) {
        if (!_isRetryable(error) || attempt == maxAttempts - 1) rethrow;
        await Future<void>.delayed(Duration(seconds: 2 << attempt));
      }
    }

    return null;
  }

  bool _isRetryable(DioException error) {
    final status = error.response?.statusCode;
    if (status == null) return true; // DNS, TLS, connection or timeout error.
    return status == 408 || status == 429 || status >= 500;
  }
}
