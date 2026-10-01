import assert from "node:assert/strict";
import test, { afterEach } from "node:test";
import worker from "../src/index.js";

const pagesOrigin = "https://etnt.github.io";
const originalFetch = globalThis.fetch;
const originalConsoleLog = console.log;
const originalConsoleWarn = console.warn;
const originalConsoleError = console.error;

afterEach(() => {
  globalThis.fetch = originalFetch;
  console.log = originalConsoleLog;
  console.warn = originalConsoleWarn;
  console.error = originalConsoleError;
});

function request(path, { method = "GET", origin = pagesOrigin } = {}) {
  const headers = origin === null ? undefined : { Origin: origin };
  return new Request(`https://worker.example${path}`, { method, headers });
}

test("forwards OpenSky requests and preserves every query parameter", async () => {
  let forwardedUrl;
  let forwardedMethod;
  globalThis.fetch = async (url, init) => {
    forwardedUrl = url;
    forwardedMethod = init.method;
    return Response.json({ states: [] }, { status: 200 });
  };

  const response = await worker.fetch(
    request("/opensky/api/states/all?lamin=51.2&lamax=53.4&time=123&icao24=abc123"),
  );

  assert.equal(
    forwardedUrl,
    "https://opensky-network.org/api/states/all?lamin=51.2&lamax=53.4&time=123&icao24=abc123",
  );
  assert.equal(forwardedMethod, "GET");
  assert.equal(response.status, 200);
  assert.equal(response.headers.get("Access-Control-Allow-Origin"), pagesOrigin);
  assert.match(response.headers.get("Content-Type"), /^application\/json/);
  assert.deepEqual(await response.json(), { states: [] });
});

test("logs route and response timing without observer coordinates", async () => {
  const entries = [];
  console.log = (entry) => entries.push(entry);
  globalThis.fetch = async () => Response.json({ states: [] });

  await worker.fetch(
    request(
      "/opensky/api/states/all?lamin=59.059807&lomin=17.540289&lamax=59.5&lomax=18.5",
    ),
  );

  assert.deepEqual(
    entries.map((entry) => entry.event),
    ["upstream_request_started", "upstream_response"],
  );
  assert.equal(entries[0].route, "opensky");
  assert.equal(entries[1].route, "opensky");
  assert.equal(entries[1].status, 200);
  assert.equal(typeof entries[1].durationMs, "number");

  const logText = JSON.stringify(entries);
  assert.equal(logText.includes("59.059807"), false);
  assert.equal(logText.includes("17.540289"), false);
  assert.equal(logText.includes("lamin"), false);
});

test("forwards ADSBDB aircraft lookups with the optional callsign", async () => {
  let forwardedUrl;
  globalThis.fetch = async (url) => {
    forwardedUrl = url;
    return Response.json({ response: { aircraft: {} } });
  };

  const response = await worker.fetch(
    request("/adsbdb/v0/aircraft/a1b2c3?callsign=TEST%201"),
  );

  assert.equal(
    forwardedUrl,
    "https://api.adsbdb.com/v0/aircraft/a1b2c3?callsign=TEST+1",
  );
  assert.equal(response.headers.get("Access-Control-Allow-Origin"), pagesOrigin);
  assert.deepEqual(await response.json(), { response: { aircraft: {} } });
});

test("answers a valid CORS preflight without contacting upstream", async () => {
  globalThis.fetch = () => assert.fail("preflight must not fetch upstream");

  const response = await worker.fetch(
    new Request("https://worker.example/opensky/api/states/all", {
      method: "OPTIONS",
      headers: {
        Origin: pagesOrigin,
        "Access-Control-Request-Method": "GET",
      },
    }),
  );

  assert.equal(response.status, 204);
  assert.equal(response.headers.get("Access-Control-Allow-Origin"), pagesOrigin);
  assert.equal(response.headers.get("Access-Control-Allow-Methods"), "GET, OPTIONS");
});

test("rejects preflight requests for unsupported methods", async () => {
  const response = await worker.fetch(
    new Request("https://worker.example/opensky/api/states/all", {
      method: "OPTIONS",
      headers: {
        Origin: pagesOrigin,
        "Access-Control-Request-Method": "POST",
      },
    }),
  );

  assert.equal(response.status, 405);
  assert.equal(response.headers.get("Access-Control-Allow-Origin"), pagesOrigin);
});

test("rejects origins other than the configured Pages origin", async () => {
  globalThis.fetch = () => assert.fail("denied origins must not reach upstream");

  const response = await worker.fetch(
    request("/opensky/api/states/all", { origin: "https://attacker.example" }),
  );

  assert.equal(response.status, 403);
  assert.equal(response.headers.get("Access-Control-Allow-Origin"), null);
  assert.deepEqual(await response.json(), { error: "origin_not_allowed" });
});

test("rejects missing origins", async () => {
  const response = await worker.fetch(
    request("/opensky/api/states/all", { origin: null }),
  );

  assert.equal(response.status, 403);
  assert.equal(response.headers.get("Access-Control-Allow-Origin"), null);
});

test("rejects unsupported routes and methods", async (t) => {
  globalThis.fetch = () => assert.fail("invalid requests must not reach upstream");

  await t.test("unknown route", async () => {
    const response = await worker.fetch(request("/proxy?url=https://example.com"));
    assert.equal(response.status, 404);
    assert.equal(response.headers.get("Access-Control-Allow-Origin"), pagesOrigin);
  });

  await t.test("unsupported method", async () => {
    const response = await worker.fetch(
      request("/opensky/api/states/all", { method: "POST" }),
    );
    assert.equal(response.status, 405);
    assert.deepEqual(await response.json(), { error: "method_not_allowed" });
  });
});

test("rejects invalid ADSBDB aircraft IDs and unapproved query parameters", async (t) => {
  globalThis.fetch = () => assert.fail("invalid ADSBDB requests must not reach upstream");

  for (const path of [
    "/adsbdb/v0/aircraft/abc12z",
    "/adsbdb/v0/aircraft/abcdef0",
    "/adsbdb/v0/aircraft/abcdef?target=https://example.com",
    "/adsbdb/v0/aircraft/abcdef?callsign=A&callsign=B",
  ]) {
    await t.test(path, async () => {
      const response = await worker.fetch(request(path));
      assert.equal(response.status, 404);
      assert.deepEqual(await response.json(), { error: "route_not_allowed" });
    });
  }
});

test("returns an explicit CORS-safe 502 and logs the upstream error class", async () => {
  const errors = [];
  console.error = (entry) => errors.push(entry);
  globalThis.fetch = async () => {
    throw new Error("network failure");
  };

  const response = await worker.fetch(request("/opensky/api/states/all"));

  assert.equal(response.status, 502);
  assert.equal(response.headers.get("Access-Control-Allow-Origin"), pagesOrigin);
  assert.match(response.headers.get("Content-Type"), /^application\/json/);
  assert.deepEqual(await response.json(), { error: "upstream_fetch_failed" });
  assert.equal(errors.length, 1);
  assert.equal(errors[0].event, "upstream_fetch_failed");
  assert.equal(errors[0].route, "opensky");
  assert.equal(errors[0].status, 502);
  assert.equal(errors[0].errorName, "Error");
  assert.equal(typeof errors[0].durationMs, "number");
  assert.equal(JSON.stringify(errors).includes("network failure"), false);
});

test("preserves non-JSON upstream statuses and retry headers", async () => {
  globalThis.fetch = async () =>
    new Response("rate limited", {
      status: 429,
      headers: {
        "Content-Type": "text/plain",
        "Retry-After": "60",
      },
    });

  const response = await worker.fetch(request("/opensky/api/states/all"));

  assert.equal(response.status, 429);
  assert.equal(response.headers.get("Content-Type"), "text/plain");
  assert.equal(response.headers.get("Retry-After"), "60");
  assert.equal(await response.text(), "rate limited");
});
