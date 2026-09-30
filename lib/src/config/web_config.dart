const _webApiProxyBaseUrl = String.fromEnvironment('WEB_API_PROXY_BASE_URL');

Uri? get webApiProxyBaseUri {
  if (_webApiProxyBaseUrl.isEmpty) return null;

  final uri = Uri.parse(_webApiProxyBaseUrl);
  if (uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.path.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw const FormatException(
      'WEB_API_PROXY_BASE_URL must be an HTTPS origin without a path.',
    );
  }
  return uri;
}
