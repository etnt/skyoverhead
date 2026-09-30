import 'package:flutter_test/flutter_test.dart';
import 'package:skyoverhead/src/config/identify_config.dart';
import 'package:skyoverhead/src/data/adsbdb_client.dart';
import 'package:skyoverhead/src/data/opensky_client.dart';
import 'package:skyoverhead/src/data/web_proxy_transport.dart';

import 'support/fake_transport.dart';

void main() {
  const worker = 'https://skyoverhead-api-proxy.kruskakli.workers.dev';

  test(
    'routes OpenSky requests through the Worker with query intact',
    () async {
      final inner = FakeTransport.json(200, '{}');
      final transport = WebProxyTransport(
        inner,
        proxyBaseUri: Uri.parse(worker),
      );
      final request = OpenSkyClient.buildUrl(
        const IdentifyConfig(latitude: 59.3, longitude: 18.0),
      );

      await transport.get(request);

      expect(inner.lastUrl?.origin, worker);
      expect(inner.lastUrl?.path, '/opensky/api/states/all');
      expect(inner.lastUrl?.query, request.query);
    },
  );

  test(
    'routes ADSBDB requests through the Worker with callsign intact',
    () async {
      final inner = FakeTransport.json(200, '{}');
      final transport = WebProxyTransport(
        inner,
        proxyBaseUri: Uri.parse(worker),
      );
      final request = AdsbdbClient.buildUrl('3c6745', 'DLH804');

      await transport.get(request);

      expect(inner.lastUrl?.origin, worker);
      expect(inner.lastUrl?.path, '/adsbdb/v0/aircraft/3c6745');
      expect(inner.lastUrl?.queryParameters, {'callsign': 'DLH804'});
    },
  );

  test('leaves unsupported hosts and paths unchanged', () async {
    final inner = FakeTransport.json(200, '{}');
    final transport = WebProxyTransport(inner, proxyBaseUri: Uri.parse(worker));
    final unsupported = Uri.https('example.com', '/data');
    final unsupportedOpenSkyPath = Uri.https(
      'opensky-network.org',
      '/api/other',
    );

    await transport.get(unsupported);
    expect(inner.lastUrl, unsupported);

    await transport.get(unsupportedOpenSkyPath);
    expect(inner.lastUrl, unsupportedOpenSkyPath);
  });
}
