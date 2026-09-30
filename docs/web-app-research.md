# Sky Overhead on the Web

Sky Overhead can run on Flutter Web, but the web version has technical
challenges that the Android app does not have.

A progressive web app (PWA) is a website that users can install on a device.
A PWA is a suitable option if you want to reach iPhone users at no cost.
iOS users can add it to the home screen in Safari. It then works like a
regular app.

This document describes how Sky Overhead can work on the web. It is based on
the code and its packages.

## What works

- API requests: The app uses the `http` package to send requests to OpenSky
  Network and ADSBDB. These requests work on the web.
- State management: `flutter_riverpod` supports the web. You can use the app
  logic for aircraft identification and state on the web.
- Geospatial calculations: `geo.dart` uses Dart code to calculate elevation
  angles and distances. This code works on all platforms.

## Challenges

### GPS location (`geolocator`)

The `geolocator` package supports the web, but browsers use stricter security
rules than Android.

- Problem: A web page can request the device location only over a secure
  connection (HTTPS). A computer browser can also give a less accurate
  location. It can use the IP address instead of GPS.
- Solution: The app lets users enter coordinates manually with
  "Enter location." Users can enter coordinates if browser location does not
  work.

### Logbook and local storage (Collector mode)

Collector mode saves logbooks and medals on the device. Android apps often
save this data in the device's internal storage.

- Problem: A browser can remove local data, such as LocalStorage or
  IndexedDB, when the device has little free space or the user clears browser
  history.
- Solution: The `shared_preferences` and `hive` packages support the web.
  Tell users that clearing browser data can remove their logbook.

### CORS errors

Cross-Origin Resource Sharing (CORS) controls whether a browser can read a
response from another website. A CORS proxy is a server that forwards browser
requests to another server and returns the responses.

- Problem: An Android app can send requests to OpenSky or ADSBDB directly.
  A browser checks if those servers allow requests from the app's web address.
  If a server does not enable CORS, the browser blocks the request.
- Solution: If a browser blocks requests, send them through a CORS proxy.
  You can use Cloudflare Workers or Netlify Functions for this.

## Test Sky Overhead on the web

Open a terminal in the project folder. Run these commands:

1. Create the web files:

   ```sh
   flutter create --platforms web .
   ```

2. Run the app in Chrome:

   ```sh
   flutter run -d chrome
   ```

Look at the Chrome console. Make sure that the app gets data from OpenSky.
If the console shows a CORS error, use a proxy for the API requests.

Build the app with `flutter build web --release`. Upload the `build/web` folder
to a free host, such as GitHub Pages. GitHub Pages provides HTTPS. GPS needs
HTTPS.

To check web support, find which package saves the logbook. Also look for CORS
errors in Chrome.

## If CORS blocks OpenSky requests

If OpenSky does not allow requests from the app's web address, the browser
blocks them. Android apps do not have the same limit. You do not own the
OpenSky server, so you cannot change its configuration. You have two options.

### Option 1: Test locally

Use this option only during development. It turns off browser security checks.
Run the app in Chrome with this command:

```sh
flutter run -d chrome --web-browser-flag "--disable-web-security"
```

This opens Chrome with CORS blocking turned off. You can then check if the app
gets data from OpenSky.

### Option 2: Use a proxy in production

To publish the app, send API requests through a CORS proxy. The proxy receives
requests from the web app and sends them to OpenSky. It then adds the
`Access-Control-Allow-Origin` header and returns the responses to the app.

You can use a public proxy or create your own.

#### Option A: Use a public proxy

Add a proxy URL before the OpenSky API URL in the Dart code. One named option
is `cors-anywhere`.

Use `kIsWeb` to check if the app runs in a browser:

```dart
import 'package:flutter/foundation.dart';

String url = 'https://opensky-network.org/api/states/all?...';

if (kIsWeb) {
  url = 'https://herokuapp.com' + url;
}
```

Public proxies can limit requests or stop working.

#### Option B: Create a proxy with Cloudflare Workers

Create your own proxy with Cloudflare Workers:

1. Create a free account at [Cloudflare](https://cloudflare.com).
2. Create a Worker. Add a CORS proxy template.
3. In the Flutter code, replace `https://opensky-network.org` with the Worker
   address. For example, use an address on `workers.dev`.

Before you change `config_provider.dart` or the HTTP client, test the app in
Chrome with Option 1. Make sure that the rest of the app displays correctly.

To use OpenSky directly on Android and a proxy on the web, select the URL
based on the platform in the Dart code.
