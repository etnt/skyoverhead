const pagesOriginEnvKey = "PAGES_ORIGIN";
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

function routeFor(url) {
  if (url.pathname === OPEN_SKY_PATH) {
    const upstream = new URL(OPEN_SKY_URL);
    upstream.search = url.search;
    return upstream;
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
    return upstream;
  }

  return null;
}

export default {
  async fetch(request, env) {
    const origin = request.headers.get("Origin");
    if (!origin || origin !== env[pagesOriginEnvKey]) {
      return jsonResponse({ error: "origin_not_allowed" }, 403, null);
    }

    const url = new URL(request.url);
    const upstream = routeFor(url);
    if (!upstream) {
      return jsonResponse({ error: "route_not_allowed" }, 404, origin);
    }

    if (request.method === "OPTIONS") {
      const requestedMethod = request.headers.get(
        "Access-Control-Request-Method",
      );
      if (requestedMethod !== null && requestedMethod !== "GET") {
        return jsonResponse({ error: "method_not_allowed" }, 405, origin);
      }
      return new Response(null, { status: 204, headers: corsHeaders(origin) });
    }

    if (request.method !== "GET") {
      return jsonResponse({ error: "method_not_allowed" }, 405, origin);
    }

    let response;
    try {
      response = await fetch(upstream.toString(), { method: "GET" });
    } catch {
      return jsonResponse({ error: "upstream_fetch_failed" }, 502, origin);
    }

    const headers = corsHeaders(origin);
    const contentType = response.headers.get("Content-Type");
    if (contentType) headers["Content-Type"] = contentType;
    const retryAfter = response.headers.get("Retry-After");
    if (retryAfter) headers["Retry-After"] = retryAfter;

    return new Response(response.body, { status: response.status, headers });
  },
};
