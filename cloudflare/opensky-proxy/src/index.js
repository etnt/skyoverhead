const ALLOWED_ORIGIN = "https://etnt.github.io";
const OPEN_SKY_PATH = "/opensky/api/states/all";
const OPEN_SKY_URL = "https://opensky-network.org/api/states/all";
const ADSBDB_PATH_PREFIX = "/adsbdb/v0/aircraft/";
const ADSBDB_URL_PREFIX = "https://api.adsbdb.com/v0/aircraft/";

function corsHeaders(origin) {
  const headers = {
    "Access-Control-Allow-Methods": "GET, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Max-Age": "86400",
    "Content-Type": "application/json; charset=utf-8",
    Vary: "Origin, Access-Control-Request-Method, Access-Control-Request-Headers",
  };
  if (origin) headers["Access-Control-Allow-Origin"] = origin;
  return headers;
}

function jsonResponse(payload, status, origin) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: corsHeaders(origin),
  });
}

function logEvent(event, details) {
  console.log({ service: "skyoverhead-api-proxy", event, ...details });
}

function routeFor(url) {
  if (url.pathname === OPEN_SKY_PATH) {
    const upstream = new URL(OPEN_SKY_URL);
    upstream.search = url.search;
    return { name: "opensky", url: upstream };
  }

  if (url.pathname.startsWith(ADSBDB_PATH_PREFIX)) {
    const icao24 = url.pathname.slice(ADSBDB_PATH_PREFIX.length);
    if (!/^[0-9a-fA-F]{6}$/.test(icao24)) return null;

    const callsigns = url.searchParams.getAll("callsign");
    if ([...url.searchParams.keys()].some((key) => key !== "callsign") || callsigns.length > 1) {
      return null;
    }

    const upstream = new URL(`${ADSBDB_URL_PREFIX}${icao24}`);
    if (callsigns.length === 1) upstream.searchParams.set("callsign", callsigns[0]);
    return { name: "adsbdb", url: upstream };
  }

  return null;
}

export default {
  async fetch(request) {
    const startedAt = Date.now();
    const requestId = request.headers.get("CF-Ray");
    const origin = request.headers.get("Origin");
    const url = new URL(request.url);
    const route = routeFor(url);

    if (!origin || origin !== ALLOWED_ORIGIN) {
      console.warn({
        service: "skyoverhead-api-proxy",
        event: "request_rejected",
        reason: "origin_not_allowed",
        origin: origin ?? "missing",
        method: request.method,
        requestId,
      });
      return jsonResponse({ error: "origin_not_allowed" }, 403, null);
    }

    if (!route) {
      logEvent("request_rejected", {
        reason: "route_not_allowed",
        method: request.method,
        requestId,
      });
      return jsonResponse({ error: "route_not_allowed" }, 404, origin);
    }

    if (request.method === "OPTIONS") {
      const requestedMethod = request.headers.get(
        "Access-Control-Request-Method",
      );
      if (requestedMethod !== null && requestedMethod !== "GET") {
        logEvent("request_rejected", {
          reason: "method_not_allowed",
          route: route.name,
          method: request.method,
          requestId,
        });
        return jsonResponse({ error: "method_not_allowed" }, 405, origin);
      }
      logEvent("request_completed", {
        route: route.name,
        method: request.method,
        status: 204,
        durationMs: Date.now() - startedAt,
        requestId,
      });
      return new Response(null, { status: 204, headers: corsHeaders(origin) });
    }

    if (request.method !== "GET") {
      logEvent("request_rejected", {
        reason: "method_not_allowed",
        route: route.name,
        method: request.method,
        requestId,
      });
      return jsonResponse({ error: "method_not_allowed" }, 405, origin);
    }

    logEvent("upstream_request_started", {
      route: route.name,
      method: request.method,
      requestId,
    });

    let response;
    try {
      response = await fetch(route.url.toString(), { method: "GET" });
    } catch (error) {
      console.error({
        service: "skyoverhead-api-proxy",
        event: "upstream_fetch_failed",
        route: route.name,
        method: request.method,
        status: 502,
        errorName: error instanceof Error ? error.name : "unknown",
        durationMs: Date.now() - startedAt,
        requestId,
      });
      return jsonResponse({ error: "upstream_fetch_failed" }, 502, origin);
    }

    logEvent("upstream_response", {
      route: route.name,
      method: request.method,
      status: response.status,
      durationMs: Date.now() - startedAt,
      requestId,
    });

    const headers = corsHeaders(origin);
    const contentType = response.headers.get("Content-Type");
    if (contentType) headers["Content-Type"] = contentType;
    const retryAfter = response.headers.get("Retry-After");
    if (retryAfter) headers["Retry-After"] = retryAfter;

    return new Response(response.body, { status: response.status, headers });
  },
};
