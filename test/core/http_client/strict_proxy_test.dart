import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/http_client/dio_http_client.dart';

void main() {
  test('strict local-proxy requests fail closed when no proxy port is configured', () async {
    final client = DioHttpClient(
      timeout: const Duration(seconds: 1),
      userAgent: 'Hiddify domestic probe test',
      debug: false,
    );

    await expectLater(
      client.getViaLocalProxy<dynamic>('https://chatgpt.com/'),
      throwsA(isA<StateError>()),
    );
  });
}
