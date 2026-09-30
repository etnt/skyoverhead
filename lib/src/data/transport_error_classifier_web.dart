import 'package:http/http.dart' as http;

import 'transport_exception.dart';

TransportException classifyTransportError(Object error) {
  final kind = error is http.ClientException
      ? TransportErrorKind.connectionFailed
      : TransportErrorKind.other;
  return TransportException(kind, error);
}
