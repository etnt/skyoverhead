/// Helpers for opening an external Google search for an airport.
library;

import 'package:url_launcher/url_launcher.dart';

/// Builds a Google search URL from the airport's known name and codes, or null
/// when there is no airport information to search for.
Uri? airportSearchUri({String? name, Iterable<String?> codes = const []}) {
  final searchTerms = <String>{};
  final airportName = name?.trim();
  if (airportName != null && airportName.isNotEmpty) {
    searchTerms.add(airportName);
  }
  for (final code in codes) {
    final value = code?.trim();
    if (value != null && value.isNotEmpty) searchTerms.add(value);
  }
  if (searchTerms.isEmpty) return null;

  final query = searchTerms.join(' ');
  final searchQuery =
      RegExp(r'\bairport\b', caseSensitive: false).hasMatch(query)
      ? query
      : '$query airport';
  return Uri.https('www.google.com', '/search', {'q': searchQuery});
}

/// Opens an external Google search for an airport. Returns false when no
/// searchable airport information is available or the URL could not be opened.
Future<bool> launchAirportSearch({
  String? name,
  Iterable<String?> codes = const [],
}) async {
  final uri = airportSearchUri(name: name, codes: codes);
  if (uri == null) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
