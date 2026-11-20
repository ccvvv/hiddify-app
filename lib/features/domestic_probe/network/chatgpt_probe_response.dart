/// Conservative validation for the ChatGPT reachability response.
///
/// This does not prove account login or that a prompt can be submitted. It
/// only accepts a successful HTTPS response from the ChatGPT web/login hosts.
class ChatGptProbeResponse {
  ChatGptProbeResponse._();

  static const _allowedHosts = <String>{
    'chatgpt.com',
    'auth.openai.com',
    'chat.openai.com',
  };

  static bool isReachable({
    required int? statusCode,
    required Uri finalUri,
    String? body,
  }) {
    if (statusCode != 200 || finalUri.scheme != 'https') return false;

    final host = finalUri.host.toLowerCase();
    final allowedHost = _allowedHosts.contains(host) ||
        host.endsWith('.chatgpt.com');
    if (!allowedHost) return false;

    final normalizedBody = (body ?? '').toLowerCase();
    const challengeMarkers = <String>[
      'just a moment...',
      'cf-chl-',
      'enable javascript and cookies to continue',
      'checking your browser',
    ];
    if (challengeMarkers.any(normalizedBody.contains)) return false;

    return true;
  }
}
