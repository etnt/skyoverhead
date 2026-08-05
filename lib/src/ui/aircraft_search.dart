/// Helpers for launching an external web search about a spotted aircraft
/// type. Kept small and separate so the URL-building logic is unit testable
/// without touching the platform plugin.
library;

import 'package:url_launcher/url_launcher.dart';

import '../domain/models.dart';
import 'format.dart' as fmt;

/// Builds a Google search URL for the candidate's aircraft type, e.g.
/// "Airbus A320 aircraft", or null when the type is unknown.
Uri? aircraftSearchUri(Candidate c) {
  final type = fmt.aircraftTypeLabel(c);
  if (type == null) return null;
  return Uri.https('www.google.com', '/search', {'q': '$type aircraft'});
}

/// Opens a web search for the candidate's aircraft type in the external
/// browser. Returns false (without launching) when the type is unknown or the
/// URL could not be opened.
Future<bool> launchAircraftSearch(Candidate c) async {
  final uri = aircraftSearchUri(c);
  if (uri == null) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
