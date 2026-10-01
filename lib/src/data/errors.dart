/// Stable error taxonomy for identification, mirroring the error codes
/// returned by the Erlang `aircraft_id` facade (`message_for/1`).
enum IdentifyError {
  notConfigured,
  networkUnavailable,
  dnsFailed,
  tlsFailed,
  openskyTimeout,
  openskyRateLimited,
  openskyUnauthorized,
  openskyUnavailable,
  openskyBadResponse,
}

/// Short, user-visible title for each classified identification failure.
String titleForError(IdentifyError code) {
  switch (code) {
    case IdentifyError.notConfigured:
      return 'Location not set';
    case IdentifyError.networkUnavailable:
      return 'Network error';
    case IdentifyError.dnsFailed:
      return 'Aircraft service host not found';
    case IdentifyError.tlsFailed:
      return 'Secure connection failed';
    case IdentifyError.openskyTimeout:
      return 'OpenSky request timed out';
    case IdentifyError.openskyRateLimited:
      return 'OpenSky rate limit reached';
    case IdentifyError.openskyUnauthorized:
      return 'OpenSky rejected the request';
    case IdentifyError.openskyUnavailable:
      return 'OpenSky is unavailable';
    case IdentifyError.openskyBadResponse:
      return 'Invalid response from OpenSky';
  }
}

/// Thrown by the data layer to signal a classified failure.
class IdentifyException implements Exception {
  final IdentifyError code;

  const IdentifyException(this.code);

  @override
  String toString() => 'IdentifyException(${code.name})';
}

/// Human-friendly message for each error code, mirroring the library copy.
String messageForError(IdentifyError code) {
  switch (code) {
    case IdentifyError.notConfigured:
      return 'Set your location to identify aircraft overhead.';
    case IdentifyError.networkUnavailable:
      return 'The network is unavailable.';
    case IdentifyError.dnsFailed:
      return 'Could not resolve the aircraft service host.';
    case IdentifyError.tlsFailed:
      return 'A secure connection to the aircraft service failed.';
    case IdentifyError.openskyTimeout:
      return 'The OpenSky request did not return a response within 12 seconds.';
    case IdentifyError.openskyRateLimited:
      return 'The aircraft service is rate limiting requests. Try again shortly.';
    case IdentifyError.openskyUnauthorized:
      return 'The aircraft service rejected the request.';
    case IdentifyError.openskyUnavailable:
      return 'The aircraft service is temporarily unavailable. Try again later.';
    case IdentifyError.openskyBadResponse:
      return 'The aircraft service returned an invalid response.';
  }
}
