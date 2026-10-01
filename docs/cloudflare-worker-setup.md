# Set Up the Cloudflare API Proxy

This guide explains the Cloudflare and GitHub setup for the Sky Overhead web
proxy. Follow [the PWA implementation plan][pwa-plan].

A Worker is a small program that runs on Cloudflare's network. Cross-Origin
Resource Sharing (CORS) is a browser rule that controls which websites can
read a server response. The Sky Overhead Worker forwards requests to fixed
OpenSky and ADSBDB endpoints and adds CORS response headers.

The Worker code and deployment workflow are in `cloudflare/opensky-proxy/` and
`.github/workflows/deploy-web.yml`. The named Worker has already been created;
the first workflow deployment replaces its code with this repository's proxy.

## 1. Confirm the existing Worker

You need access to the Cloudflare account that owns the Worker. If needed,
[create a Cloudflare account][account].

1. Open the [Cloudflare dashboard](https://dash.cloudflare.com/). Select
   `Workers & Pages` under `Compute`.
2. Confirm the existing Worker is named `skyoverhead-api-proxy` and its
   `workers.dev` address is enabled.

The Worker URL is:

```text
https://skyoverhead-api-proxy.kruskakli.workers.dev
```

The workflow deploys this repository's proxy code to that Worker.

## 2. Create a deployment token

The token lets GitHub Actions deploy the Worker. It is not an API key for
OpenSky or ADSBDB.

1. Find the Cloudflare account ID in the dashboard.
2. Open `Manage Account`, then `API Tokens`.
3. Create an account API token with the `Workers Editor` role.
4. Restrict the token to the `skyoverhead-api-proxy` Worker.
5. Copy the token when Cloudflare shows it. It is shown only once.

The Worker already exists, so the `Workers Editor` role can deploy and update
it. This role cannot create or delete Workers.

## 3. Add GitHub Actions values

Open repository `Settings`. Select `Secrets and variables`, then `Actions`.

Add `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` as GitHub
repository secrets. Set them to the token and account ID from step 2.

The Worker allows the origin set by `ALLOWED_ORIGIN` in
`cloudflare/opensky-proxy/src/index.js`. The value is
`https://etnt.github.io`. Do not add the repository path or a trailing slash.

`WEB_API_PROXY_URL` is an optional GitHub repository variable. Its default is
`https://skyoverhead-api-proxy.kruskakli.workers.dev`. Set the variable only to
override this Worker address. The value is public and appears in the built web
app. Do not store it as a secret.

## 4. Enable GitHub Pages deployment

1. In repository settings, open `Pages`.
2. Set the publishing source to `GitHub Actions`.
3. Add the `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` repository
   secrets described above.
4. Run the web deployment workflow from the repository's default branch.

The workflow deploys the Worker, builds Flutter Web with the repository path,
and publishes `build/web`. The Worker adds CORS headers only for the origin in
`ALLOWED_ORIGIN`.

## 5. Test the proxy

Set these shell variables to match `ALLOWED_ORIGIN` and the Worker URL, or use
the defaults:

```sh
export PAGES_ORIGIN="https://etnt.github.io"
export WEB_API_PROXY_URL="https://skyoverhead-api-proxy.kruskakli.workers.dev"
```

Send a browser preflight request:

```sh
curl -i -X OPTIONS "$WEB_API_PROXY_URL/opensky/api/states/all" \
  -H "Origin: $PAGES_ORIGIN" \
  -H "Access-Control-Request-Method: GET"
```

The response must include `Access-Control-Allow-Origin` with the value of
`PAGES_ORIGIN`. Its allowed methods must include `GET`.

Send the same request with a different origin:

```sh
curl -i -X OPTIONS "$WEB_API_PROXY_URL/opensky/api/states/all" \
  -H "Origin: https://not-your-app.example" \
  -H "Access-Control-Request-Method: GET"
```

The Worker must reject this origin. It must not return an
`Access-Control-Allow-Origin` value for it.

Open the published HTTPS site in Chrome. Make sure that the app gets data from
OpenSky and ADSBDB without CORS errors. A successful preflight does not prove
that the upstream APIs returned data.

## Worker observability

`cloudflare/opensky-proxy/wrangler.toml` enables persisted Workers Logs. The
settings are:

```toml
[observability]
enabled = true
head_sampling_rate = 1

[observability.logs]
invocation_logs = false
```

Invocation logs are off because they include full request URLs. OpenSky URLs
contain observer coordinates. Custom `console.log` and `console.error` records
are still stored. Wrangler does not need a `persist` setting for these logs.

The Worker records these events:

- `request_rejected`: rejected origin, route, or method.
- `upstream_request_started`: route, method, and Cloudflare request ID.
- `upstream_response`: route, upstream status, and elapsed time.
- `upstream_fetch_failed`: route, error type, and elapsed time.

To read stored logs, open Cloudflare Workers & Pages, select
`skyoverhead-api-proxy`, then open `Observability`. For live logs, open `Logs` and
select `Live`. You can also run `npx wrangler tail` from
`cloudflare/opensky-proxy/`.

If an `upstream_request_started` event has no matching response or failure
event, the proxy did not complete the upstream request. If the failure event
appears, read its error type. The log fields do not contain the request query.


## Security and limits

Keep `CLOUDFLARE_API_TOKEN` in GitHub Actions secrets. Never add it to source
code or a repository variable. Do not expose it to pull-request workflows.

The Worker must forward only its fixed OpenSky and ADSBDB routes. It must not
accept an upstream URL from the request. The origin check controls which browser
pages can read a response. It does not authenticate users or prevent all
non-browser requests.

The Worker does not remove OpenSky or ADSBDB rate limits or outages. A public
`workers.dev` address is suitable for a hobby project, but it is not a private
endpoint.

## Official setup references

- [Create a Cloudflare account][account]
- [Cloudflare API token guide][token-guide]
- [Cloudflare Workers roles][workers-roles]
- [Cloudflare GitHub Actions guide][cloudflare-actions]
- [`workers.dev` guide][workers-dev]
- [GitHub Pages documentation][github-pages]
- [Cloudflare Workers Logs][worker-logs]
- [Cloudflare real-time logs][worker-live-logs]

[pwa-plan]: ../plan/feature-pwa-implementation-1.md
[account]:
  https://developers.cloudflare.com/fundamentals/account/create-account/
[token-guide]:
  https://developers.cloudflare.com/fundamentals/api/get-started/create-token/
[workers-roles]:
  https://developers.cloudflare.com/workers/authorization/workers/
[cloudflare-actions]:
  https://developers.cloudflare.com/workers/ci-cd/external-cicd/github-actions/
[workers-dev]:
  https://developers.cloudflare.com/workers/configuration/routing/workers-dev/
[github-pages]: https://docs.github.com/en/pages
[worker-logs]:
  https://developers.cloudflare.com/workers/observability/logs/workers-logs/
[worker-live-logs]:
  https://developers.cloudflare.com/workers/observability/logs/real-time-logs/
