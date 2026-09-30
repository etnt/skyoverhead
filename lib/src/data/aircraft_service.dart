/// Identification orchestration: config validation -> OpenSky fetch ->
/// ranking -> ADSBDB enrichment -> [IdentifyResult].
///
/// A port of the Erlang `aircraft_id` facade (`identify/1`). All provider
/// and transport failures are collapsed into a single `error` result with
/// a stable [IdentifyError] code and friendly message; a run that simply
/// finds nothing overhead returns an `ok` result with `confidence == none`.
library;

import 'package:flutter/foundation.dart';

import '../config/identify_config.dart';
import '../config/web_config.dart';
import '../domain/models.dart';
import '../domain/ranking.dart' as ranking;
import '../domain/route_check.dart' as route_check;
import 'adsbdb_client.dart';
import 'errors.dart';
import 'http.dart';
import 'opensky_client.dart';
import 'web_proxy_transport.dart';

class AircraftService {
  final OpenSkyClient _opensky;
  final AdsbdbClient _adsbdb;
  final DateTime Function() _clock;

  AircraftService({
    required OpenSkyClient opensky,
    required AdsbdbClient adsbdb,
    DateTime Function()? clock,
  }) : _opensky = opensky, // ignore: prefer_initializing_formals
       _adsbdb = adsbdb, // ignore: prefer_initializing_formals
       _clock = clock ?? DateTime.now;

  /// Build a service backed by the real network transport.
  ///
  /// Web API requests use the configured CORS proxy. Native requests stay
  /// direct to their provider hosts.
  factory AircraftService.networked([HttpTransport? transport]) {
    HttpTransport apiTransport = transport ?? DefaultHttpTransport();
    if (kIsWeb) {
      final proxyBaseUri = webApiProxyBaseUri;
      if (proxyBaseUri != null) {
        apiTransport = WebProxyTransport(
          apiTransport,
          proxyBaseUri: proxyBaseUri,
        );
      }
    }
    return AircraftService(
      opensky: OpenSkyClient(apiTransport),
      adsbdb: AdsbdbClient(apiTransport),
    );
  }

  /// Run a single identification. Never throws; always returns a result.
  Future<IdentifyResult> identify(IdentifyConfig config) async {
    final observedAt = _clock();

    if (!_isConfigured(config)) {
      return IdentifyResult.error(
        errorCode: IdentifyError.notConfigured,
        message: messageForError(IdentifyError.notConfigured),
        observedAt: observedAt,
      );
    }

    final List<dynamic> rawStates;
    try {
      rawStates = await _opensky.fetchStates(config);
    } on IdentifyException catch (e) {
      return IdentifyResult.error(
        errorCode: e.code,
        message: messageForError(e.code),
        observedAt: observedAt,
      );
    }

    final now = observedAt.toUtc().millisecondsSinceEpoch ~/ 1000;
    final observer = Observer(
      lat: config.latitude,
      lon: config.longitude,
      elevM: config.elevationM,
    );
    final selection = ranking.select(rawStates, observer, now, config);

    final primary = selection.candidate;
    if (primary == null) {
      return IdentifyResult.none(observedAt: observedAt);
    }

    final enriched = await _adsbdb.enrich(primary);
    final checked = enriched.copyWith(
      routePlausibility: route_check.evaluateRoute(
        observerLat: observer.lat,
        observerLon: observer.lon,
        origin: enriched.origin,
        destination: enriched.destination,
      ),
    );
    return IdentifyResult.ok(
      confidence: selection.confidence,
      candidate: checked,
      alternatives: selection.alternatives,
      observedAt: observedAt,
    );
  }

  static bool _isConfigured(IdentifyConfig config) {
    final lat = config.latitude;
    final lon = config.longitude;
    return lat.isFinite &&
        lon.isFinite &&
        lat >= -90.0 &&
        lat <= 90.0 &&
        lon >= -180.0 &&
        lon <= 180.0;
  }
}
