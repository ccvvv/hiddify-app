import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/domestic_probe/network/chatgpt_probe_response.dart';

void main() {
  group('ChatGptProbeResponse', () {
    test('accepts a successful HTTPS ChatGPT response', () {
      expect(
        ChatGptProbeResponse.isReachable(
          statusCode: 200,
          finalUri: Uri.parse('https://chatgpt.com/'),
          body: '<html>ChatGPT</html>',
        ),
        isTrue,
      );
    });

    test('accepts the OpenAI authentication redirect destination', () {
      expect(
        ChatGptProbeResponse.isReachable(
          statusCode: 200,
          finalUri: Uri.parse('https://auth.openai.com/log-in'),
        ),
        isTrue,
      );
    });

    test('rejects unrelated hosts even when they return HTTP 200', () {
      expect(
        ChatGptProbeResponse.isReachable(
          statusCode: 200,
          finalUri: Uri.parse('https://example.com/'),
        ),
        isFalse,
      );
    });

    test('rejects non-200 responses and HTTP destinations', () {
      expect(
        ChatGptProbeResponse.isReachable(
          statusCode: 403,
          finalUri: Uri.parse('https://chatgpt.com/'),
        ),
        isFalse,
      );
      expect(
        ChatGptProbeResponse.isReachable(
          statusCode: 200,
          finalUri: Uri.parse('http://chatgpt.com/'),
        ),
        isFalse,
      );
    });

    test('rejects common browser challenge pages', () {
      expect(
        ChatGptProbeResponse.isReachable(
          statusCode: 200,
          finalUri: Uri.parse('https://chatgpt.com/'),
          body: '<html>Just a moment... cf-chl-abc</html>',
        ),
        isFalse,
      );
    });
  });
}
