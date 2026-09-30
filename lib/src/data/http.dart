/// Shared HTTP transport for the OpenSky and ADSBDB clients.
///
/// Mirrors the injectable `aircraft_id_http_client` behaviour: a small
/// [HttpTransport] interface so tests can supply a fake, plus a default
/// implementation over `package:http` that enforces timeouts, caps the
/// response body size, and classifies transport failures.
library;

import 'dart:async';

import 'package:http/http.dart' as http;

import 'transport_error_classifier.dart' as error_classifier;
import 'transport_exception.dart';

export 'transport_exception.dart';

/// A minimal HTTP response: status, lower-cased headers, and body text.
class HttpResponse {
  final int status;
  final Map<String, String> headers;
  final String body;

  const HttpResponse(this.status, this.headers, this.body);
}

/// Injectable HTTP transport abstraction.
abstract class HttpTransport {
  Future<HttpResponse> get(
    Uri url, {
    Map<String, String> headers = const {},
    Duration timeout = const Duration(seconds: 12),
    int maxBody = 262144,
  });
}

/// Default transport over `package:http`.
class DefaultHttpTransport implements HttpTransport {
  final http.Client _client;

  DefaultHttpTransport({http.Client? client})
    : _client = client ?? http.Client();

  @override
  Future<HttpResponse> get(
    Uri url, {
    Map<String, String> headers = const {},
    Duration timeout = const Duration(seconds: 12),
    int maxBody = 262144,
  }) async {
    try {
      final response = await _client
          .get(url, headers: headers)
          .timeout(timeout);
      if (response.bodyBytes.length > maxBody) {
        throw const TransportException(TransportErrorKind.tooLarge);
      }
      return HttpResponse(
        response.statusCode,
        _lowerCaseHeaders(response.headers),
        response.body,
      );
    } on TransportException {
      rethrow;
    } on TimeoutException catch (e) {
      throw TransportException(TransportErrorKind.timeout, e);
    } catch (e) {
      throw error_classifier.classifyTransportError(e);
    }
  }

  void close() => _client.close();

  static Map<String, String> _lowerCaseHeaders(Map<String, String> headers) {
    return {
      for (final entry in headers.entries) entry.key.toLowerCase(): entry.value,
    };
  }
}
