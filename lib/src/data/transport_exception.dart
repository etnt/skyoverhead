/// How a transport-level failure was classified.
enum TransportErrorKind {
  timeout,
  connectionFailed,
  dnsFailed,
  tlsFailed,
  tooLarge,
  other,
}

/// Raised for transport-level failures (no HTTP status was obtained).
class TransportException implements Exception {
  final TransportErrorKind kind;
  final Object? cause;

  const TransportException(this.kind, [this.cause]);

  @override
  String toString() => 'TransportException(${kind.name})';
}
