import 'package:flutter_test/flutter_test.dart';
import 'package:skyoverhead/src/ui/airport_search.dart';

void main() {
  group('airportSearchUri', () {
    test('includes the airport name and known codes in a Google search', () {
      final uri = airportSearchUri(
        name: '  Stockholm-Arlanda Airport ',
        codes: [' ARN ', 'ESSA'],
      );

      expect(uri, isNotNull);
      expect(uri!.host, 'www.google.com');
      expect(uri.path, '/search');
      expect(uri.queryParameters['q'], 'Stockholm-Arlanda Airport ARN ESSA');
    });

    test('uses available codes when the airport name is missing', () {
      final uri = airportSearchUri(codes: [null, '  ', 'FRA']);
      expect(uri?.queryParameters['q'], 'FRA airport');
    });

    test('does not build a search when airport information is blank', () {
      expect(airportSearchUri(name: ' ', codes: [null, '  ']), isNull);
    });
  });
}
