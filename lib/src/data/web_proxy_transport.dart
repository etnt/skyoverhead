import 'http.dart';

/// Rewrites the app's supported API hosts to the configured CORS proxy.
class WebProxyTransport implements HttpTransport {
  static final RegExp _adsbdbPath = RegExp(
    r'^/v0/aircraft/[a-f0-9]{6}$',
    caseSensitive: false,
  );

  final HttpTransport _inner;
  final Uri _proxyBaseUri;

  WebProxyTransport(this._inner, {required Uri proxyBaseUri})
    : _proxyBaseUri = proxyBaseUri {
    if (proxyBaseUri.scheme != 'https' ||
        proxyBaseUri.host.isEmpty ||
        proxyBaseUri.path.isNotEmpty ||
        proxyBaseUri.hasQuery ||
        proxyBaseUri.hasFragment ||
        proxyBaseUri.userInfo.isNotEmpty) {
      throw ArgumentError.value(
        proxyBaseUri,
        'proxyBaseUri',
        'Must be an HTTPS origin without a path or credentials.',
      );
    }
  }

  @override
  Future<HttpResponse> get(
    Uri url, {
    Map<String, String> headers = const {},
    Duration timeout = const Duration(seconds: 12),
    int maxBody = 262144,
  }) {
    return _inner.get(
      _proxyUrl(url),
      headers: headers,
      timeout: timeout,
      maxBody: maxBody,
    );
  }

  Uri _proxyUrl(Uri url) {
    final path = switch (url.host) {
      'opensky-network.org' when url.path == '/api/states/all' =>
        '/opensky${url.path}',
      'api.adsbdb.com' when _adsbdbPath.hasMatch(url.path) =>
        '/adsbdb${url.path}',
      _ => null,
    };
    if (path == null) return url;

    return _proxyBaseUri.replace(
      path: path,
      query: url.hasQuery ? url.query : null,
    );
  }
}
