import 'dart:convert';

import 'package:dio/dio.dart';

class DomesticProbeCandidateBatch {
  const DomesticProbeCandidateBatch({
    required this.profileContent,
    required this.revision,
    required this.nodeIds,
  });

  final String profileContent;
  final String revision;
  final Set<String> nodeIds;
}

/// Downloads and validates the current GitHub-coarse-filtered candidate batch.
class DomesticProbeCandidateClient {
  DomesticProbeCandidateClient({Dio? dio}) : _dio = dio ?? Dio();

  static const candidatesUrl =
      'https://ccvvv.github.io/AutoSubHub/candidates.yaml';
  static const manifestUrl =
      'https://ccvvv.github.io/AutoSubHub/candidate-manifest.json';
  static const maxCandidates = 50;

  static final RegExp _candidateName =
      RegExp(r"""^\s*-?\s*name:\s*["']?probe_([a-f0-9]{24})__""", multiLine: true);

  final Dio _dio;

  Future<DomesticProbeCandidateBatch> fetchCandidateBatch() async {
    final responses = await Future.wait([
      _dio.get<String>(
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
      ),
      _dio.get<Map<String, dynamic>>(
        manifestUrl,
        options: Options(
          responseType: ResponseType.json,
          headers: const {
            'Cache-Control': 'no-cache, no-store, max-age=0',
            'Pragma': 'no-cache',
          },
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 10),
          validateStatus: (status) => status == 200,
        ),
      ),
    ]);

    final profile = responses[0].data as String?;
    final manifest = responses[1].data as Map<String, dynamic>?;
    if (profile == null || profile.trim().isEmpty || manifest == null) {
      throw const FormatException('GitHub returned an incomplete candidate batch');
    }

    final revision = manifest['generated_at'];
    final manifestNodes = manifest['nodes'];
    if (manifest['schema_version'] != 1 ||
        revision is! String ||
        manifestNodes is! List ||
        manifestNodes.isEmpty ||
        manifestNodes.length > maxCandidates) {
      throw const FormatException('Invalid candidate manifest');
    }
    DateTime.parse(revision);

    final manifestIds = <String>{};
    for (final entry in manifestNodes) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('Invalid candidate manifest entry');
      }
      final id = entry['node_id'];
      if (id is! String ||
          !RegExp(r'^probe_[a-f0-9]{24}$').hasMatch(id) ||
          !manifestIds.add(id)) {
        throw const FormatException('Invalid or duplicate candidate ID in manifest');
      }
    }

    final profileIds = _candidateName
        .allMatches(profile)
        .map((match) => 'probe_${match.group(1)}')
        .toSet();
    if (profileIds.isEmpty ||
        profileIds.length != manifestIds.length ||
        !profileIds.containsAll(manifestIds)) {
      throw const FormatException('Candidate profile and manifest do not match');
    }

    return DomesticProbeCandidateBatch(
      profileContent: profile,
      revision: revision,
      nodeIds: manifestIds,
    );
  }
}
