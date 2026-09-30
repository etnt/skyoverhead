# Set Up the Cloudflare API Proxy

This guide explains the Cloudflare and GitHub setup for the Sky Overhead web
proxy. Follow [the PWA implementation plan][pwa-plan].

A Worker is a small program that runs on Cloudflare's network. Cross-Origin
Resource Sharing (CORS) is a browser rule that controls which websites can
read a server response. The Sky Overhead Worker forwards requests to fixed
OpenSky and ADSBDB endpoints and adds CORS response headers.

The Worker source and deployment workflow are planned at
`cloudflare/opensky-proxy/` and `.github/workflows/deploy-web.yml`. Complete the
steps below after those files exist.

## 1. Create the Worker

You need a Cloudflare account. If you do not have one, [create one][account].
Create the Worker before its deployment token. This lets you limit the token
to this Worker.

1. Open [Cloudflare Workers & Pages](https://dash.cloudflare.com/).
2. Select `Create application`. Create a basic Worker named
   `skyoverhead-api-proxy`.
3. Enable its `workers.dev` address and deploy it.
4. Find your account's `workers.dev` subdomain in Workers & Pages.

The Worker address has this form:

```text
https://skyoverhead-api-proxy.ACCOUNT_SUBDOMAIN.workers.dev
```

Replace `ACCOUNT_SUBDOMAIN` with the subdomain shown in Cloudflare. If the
subdomain is `skyuser`, the address is
`https://skyoverhead-api-proxy.skyuser.workers.dev`.

The first GitHub Actions deployment replaces the basic Worker code with the
proxy code in this repository.

## 2. Create a deployment token

The token lets GitHub Actions deploy the Worker. It is not an API key for
OpenSky or ADSBDB.

1. Find the Cloudflare account ID in the Cloudflare dashboard.
2. Open `Manage Account`, then `API Tokens`.
3. Create an account API token with the `Workers Editor` role.
4. Limit the role to `skyoverhead-api-proxy` only.
5. Copy the token when Cloudflare shows it. Cloudflare shows it only once.

The Worker must exist before you can limit the token to it. The
`Workers Editor` role can deploy and update that Worker. It cannot create or
delete Workers.

## 3. Add GitHub Actions values

Open repository `Settings`. Select `Secrets and variables`, then `Actions`.

Add `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` as GitHub
repository secrets. Set them to the token and account ID from step 2.

Add `PAGES_ORIGIN` and `WEB_API_PROXY_URL` as repository variables.

Set `PAGES_ORIGIN` to the HTTPS origin of the Pages site. Do not include the
repository path. For a project Pages site, the value looks like
`https://OWNER.github.io`. Do not add a trailing slash. Find the published
site URL in repository `Settings`, under `Pages`.

Set `WEB_API_PROXY_URL` to the Worker address from step 1. Do not add a path or
trailing slash. This value is public and appears in the built web app. Do not
store it as a secret.

## 4. Enable GitHub Pages deployment

1. In the repository settings, open `Pages`.
2. Set the publishing source to `GitHub Actions`.
3. Make sure that both repository variables and both repository secrets are
   set.
4. Run the web deployment workflow from the repository's default branch.

The workflow deploys the Worker, builds Flutter Web with the repository path,
and publishes `build/web`. It sends `PAGES_ORIGIN` to the Worker. The Worker
uses this value to allow requests from the published app.

## 5. Test the proxy

Set the shell variables to match the GitHub repository variables. Replace
`OWNER` and `ACCOUNT_SUBDOMAIN` with your values:

```sh
export PAGES_ORIGIN="https://OWNER.github.io"
export WORKER_SUBDOMAIN="ACCOUNT_SUBDOMAIN"
export WORKER_HOST="skyoverhead-api-proxy.${WORKER_SUBDOMAIN}.workers.dev"
export WEB_API_PROXY_URL="https://${WORKER_HOST}"
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
