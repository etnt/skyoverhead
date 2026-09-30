import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:skyoverhead/src/data/http.dart';
import 'package:skyoverhead/src/data/transport_error_classifier_web.dart'
    as web_classifier;

class _ThrowingHttpClient extends http.BaseClient {
  final Object error;

  _ThrowingHttpClient(this.error);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw error;
  }
}

Future<TransportException> _transportFailure(Object error) async {
  final transport = DefaultHttpTransport(client: _ThrowingHttpClient(error));
  try {
    await transport.get(Uri.https('opensky-network.org', '/api/states/all'));
    fail('Expected a transport exception.');
  } on TransportException catch (exception) {
    return exception;
  } finally {
    transport.close();
  }
}

void main() {
  test('preserves native DNS classification', () async {
    final exception = await _transportFailure(
      const SocketException('Failed host lookup: example.test'),
    );

    expect(exception.kind, TransportErrorKind.dnsFailed);
  });

  test('preserves native TLS classification', () async {
    final exception = await _transportFailure(
      const HandshakeException('Handshake failed'),
    );

    expect(exception.kind, TransportErrorKind.tlsFailed);
  });

  test('classifies browser HTTP client failures as connection errors', () {
    final exception = web_classifier.classifyTransportError(
      http.ClientException('Browser request failed'),
    );

    expect(exception.kind, TransportErrorKind.connectionFailed);
  });
}
