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

Repository variables are optional. The workflow defaults `PAGES_ORIGIN` to
`https://etnt.github.io` and `WEB_API_PROXY_URL` to
`https://skyoverhead-api-proxy.kruskakli.workers.dev`. Set these variables only
to override the defaults:

- `PAGES_ORIGIN`: the HTTPS origin of the Pages site, without its repository
  path or a trailing slash (for example, `https://OWNER.github.io`). Find the
  published site URL in repository `Settings` > `Pages`.
- `WEB_API_PROXY_URL`: the Worker base URL, without a path or trailing slash.
  This URL is public and appears in the built web app; do not store it as a
  secret.

## 4. Enable GitHub Pages deployment

1. In repository settings, open `Pages`.
2. Set the publishing source to `GitHub Actions`.
3. Add the `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` repository
   secrets described above.
4. Run the web deployment workflow from the repository's default branch.

The workflow deploys the Worker, builds Flutter Web with the repository path,
and publishes `build/web`. It sends `PAGES_ORIGIN` to the Worker. The Worker
uses this value to allow requests from the published app.

## 5. Test the proxy

Set the shell variables to match your GitHub Actions variables, or use the
defaults:

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
