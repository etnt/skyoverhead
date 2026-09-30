import 'dart:io';

import 'package:http/http.dart' as http;

import 'transport_exception.dart';

TransportException classifyTransportError(Object error) {
  if (error is HandshakeException || error is TlsException) {
    return TransportException(TransportErrorKind.tlsFailed, error);
  }
  if (error is SocketException) {
    final kind = error.message.toLowerCase().contains('failed host lookup')
        ? TransportErrorKind.dnsFailed
        : TransportErrorKind.connectionFailed;
    return TransportException(kind, error);
  }
  if (error is http.ClientException) {
    return TransportException(TransportErrorKind.connectionFailed, error);
  }
  return TransportException(TransportErrorKind.other, error);
}
