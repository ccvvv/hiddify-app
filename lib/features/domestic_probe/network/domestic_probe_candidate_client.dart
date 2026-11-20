import 'package:dio/dio.dart';

/// Downloads the current GitHub-coarse-filtered candidate profile.
///
/// The profile contains the actual proxy configuration needed for domestic
/// testing. It is intentionally fetched as a profile, not as a task manifest.
class DomesticProbeCandidateClient {
  DomesticProbeCandidateClient({Dio? dio}) : _dio = dio ?? Dio();

  static const candidatesUrl =
      'https://raw.githubusercontent.com/ccvvv/AutoSubHub/feature/android-domestic-probe-mvp/data/domestic-probe/candidates.yaml';
  static const maxCandidates = 50;

  static final RegExp _candidateName =
      RegExp(r"""^\s*-?\s*name:\s*["']?probe_([a-f0-9]{24})__""", multiLine: true);

  final Dio _dio;

  Future<String> fetchCandidateProfile() async {
    final response = await _dio.get<String>(
      candidatesUrl,
      options: Options(
        responseType: ResponseType.plain,
        headers: const {
          'Cache-Control': 'no-cache, no-store, max-age=0',
          'Pragma': 'no-cache',
        },
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 10),
        validateStatus: (status) => status == 200,
      ),
    );

    final content = response.data;
    if (content == null || content.trim().isEmpty) {
      throw const FormatException('GitHub returned an empty candidate profile');
    }

    final ids = _candidateName
        .allMatches(content)
        .map((match) => match.group(1)!)
        .toList(growable: false);
    if (ids.isEmpty || ids.length > maxCandidates) {
      throw FormatException(
        'Candidate profile must contain 1..$maxCandidates tagged nodes',
      );
    }
    if (ids.toSet().length != ids.length) {
      throw const FormatException('Candidate profile contains duplicate stable IDs');
    }

    return content;
  }
}
