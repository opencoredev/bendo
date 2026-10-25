---
title: Deploy behind Caddy or Cloudflare
description: Run a Bendo binary under systemd behind Caddy or Cloudflare, with TLS at the proxy, the right client addresses, workers and production settings.
---

# Deploy behind Caddy or Cloudflare

A Bendo server is one native binary that speaks plain HTTP/1.1. It has no TLS
and no HTTP/2, by design: a reverse proxy in front of it does that, and Bendo
listens on the loopback address where only the proxy can reach it.

```text
browser ──HTTPS, HTTP/2──▶ Caddy or Cloudflare ──HTTP/1.1──▶ 127.0.0.1:8787 ──▶ Bendo (systemd)
```

This guide covers the server side of that picture: building the binary,
production settings, trusting the proxy's client address, a systemd unit, and
the proxy configuration for Caddy, Cloudflare Tunnel, or Cloudflare in front
of Caddy. The Bend snippets come from [the complete app](#the-complete-app) at
the end of the page.

## Build the binary

```sh
bendo build
scp dist/server deploy@server.example:/opt/myapp/server
```

`bendo build` writes `dist/server`, compiled through C with clang. It needs
neither Bun nor Bend on the server, only the C library it was linked against,
so build on the same Linux distribution and architecture as the server, or an
older one. Several [workers](../workers.md) need Linux.

## Configure the app for production

The defaults already suit a server behind a proxy:

| Setting | Default | Change it with |
|---|---|---|
| Address | `127.0.0.1`, the loopback interface | The `host` field of the `Config.Config` record (an IPv4 literal) |
| Port | 8787 | `PORT` in the environment |
| Mode | Development | `B.production(config)`, or `BENDO_ENV=production` |
| Workers | 1 process | `B.workers(config, n)`, or `BENDO_WORKERS` |
| Body limit | 1 MiB | The `body_limit` field; see [uploads](uploads.md#raise-the-server-body-limit) |

Keep the loopback address when the proxy runs on the same machine. Production
mode changes one thing: a response that breaks its route's
[response schema](../validation.md) is logged and sent unchanged instead of
becoming a 500. This app has no response schemas, but sets it in code so that
adding one later is safe:

```bend
case Done{table}: B.serve_with(~Unit, ~Tag, ~Env, ~handler, ~middleware, table, env, B.production(B.config()))
```

The logger built-in writes one line per request to stderr, which systemd sends
to the journal:

```bend
B.use(Tag, Builtin{B.logger()}),
```

## Trust the client address from the proxy

Behind a proxy, every connection comes from the proxy, so the socket peer is
always `127.0.0.1`. The proxy puts the real client address in
`X-Forwarded-For`. Bendo ignores that header unless you tell it which peers
are your proxies, because any client can send it.

List the proxies once:

```bend
def proxies() -> List<&2, String>:
  ["127.0.0.1/32"]
```

Then pass the list to each feature that needs the client's address. Parse it
with `B.cidrs`, which returns `None{}` for a typo so the app stops instead of
trusting the wrong range:

```bend
start(B.cidrs(proxies()), B.ip_policy([], admin_networks(), proxies()))
```

| Feature | Where the trusted list goes |
|---|---|
| Reading the address in a handler | `B.client_address(Unit, c, trusted)` |
| IP allow and deny lists | The third argument of `B.ip_policy` |
| Rate limiting | The last argument of `B.rate_limit_config` |

```bend
case Whoami{} Env{limiter, trusted}: IO.pure(B.Res, C.text(Unit, c, address(B.client_address(Unit, c, trusted))))
```

```bend
limiter : B.RateLimiter <- B.rate_limiter_with(B.rate_limit_config("api", B.fixed_window(100n, 60000n), 10000n, ranges))
```

When the peer is trusted, Bendo reads `X-Forwarded-For` from the right,
skipping your own proxies, and takes the first address that is not one of
them. A client can put anything at the left of the header, but it cannot get
past the entry your proxy appended. `B.conn_info` always reports the socket
peer.

Trusting `127.0.0.1` trusts every process on the machine, not only Caddy. Any
local process can connect to the port directly and send whatever
`X-Forwarded-For` it likes. Bendo cannot listen on a Unix socket, so limit who
can reach the port instead: run the app on a host or container that runs
nothing untrusted, or add a firewall rule that accepts loopback connections to
the port only from the proxy's user (nftables matches that with
`meta skuid`).

This app lets only the office network reach `/admin`, judged by that client
address:

```bend
def admin_networks() -> List<&2, String>:
  ["198.51.100.0/24"]
```

```bend
B.use_path(Tag, "/admin/*", Builtin{B.ip_restriction(admin)}),
```

### Forward to another service

When Bendo itself forwards requests to another server with `B.proxy`, it
normally replaces `X-Forwarded-For` with the peer it sees, which here is the
proxy. Turn on `B.proxy_trust_forwarded` to append to the proxy's header
instead, so the next service sees the whole chain:

```bend
def legacy() -> B.ProxyOptions:
  B.proxy_trust_forwarded(B.proxy_rewrite(B.proxy_options("http://127.0.0.1:9000"), "/legacy", ""), True{})
```

A request from `203.0.113.7` through Caddy reaches that service with
`X-Forwarded-For: 203.0.113.7, 127.0.0.1`. Only enable it when every caller
reaches Bendo through a proxy you control. Listening on the loopback address
keeps out other machines, but not other processes on this one: they can
connect directly and forge the header, which the next service then trusts.
Enable it only when you trust every local caller or restrict the port as
[above](#trust-the-client-address-from-the-proxy) describes.

## Run it under systemd

Create a unit at `/etc/systemd/system/myapp.service`:

```ini
[Unit]
Description=myapp, a Bendo server
After=network.target

[Service]
ExecStart=/opt/myapp/server
Environment=PORT=8787 BENDO_ENV=production BENDO_WORKERS=4
EnvironmentFile=/etc/myapp/secrets.env
DynamicUser=yes
Restart=on-failure
RestartSec=2
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
```

- `EnvironmentFile` holds secrets such as the [auth guide's](auth.md#load-secrets-at-startup)
  signing keys, one `NAME=value` per line. systemd reads it before it drops
  privileges, so make it `chmod 600` and owned by root.
- `DynamicUser=yes` runs the server as a fresh unprivileged user with a
  read-only view of the system.
- `BENDO_WORKERS=4` starts four processes on the same port. Workers share no
  memory: each has its own [stores](../store.md), sessions and rate-limit
  counts. Leave it at 1 when that matters. The first process waits for every
  worker before it accepts connections, and if any worker dies the whole group
  exits, so `Restart=on-failure` restarts all of them.

```sh
sudo systemctl daemon-reload
sudo systemctl enable --now myapp
journalctl -u myapp -f
```

Stopping the service stops every worker. Requests in flight when it stops are
not drained, so restart during quiet periods or run two instances behind the
proxy and restart them in turn.

## Put Caddy in front

[Caddy](https://caddyserver.com) gets a certificate from Let's Encrypt on its
own, redirects HTTP to HTTPS, and speaks HTTP/2 and HTTP/3 to browsers. A
whole `Caddyfile` for one site:

```text
api.example.com {
	encode zstd gzip
	reverse_proxy 127.0.0.1:8787 {
		health_uri /healthz
	}
}
```

- `reverse_proxy` sets `X-Forwarded-For`, `X-Forwarded-Proto` and
  `X-Forwarded-Host`. It replaces any values the client sent, because the
  client is not one of Caddy's trusted proxies, so Bendo sees exactly one
  address: the client's.
- WebSocket upgrades pass through without extra settings.
- `encode` compresses responses. Bendo has no compression middleware, so this
  is where it happens.
- `health_uri` makes Caddy probe `/healthz` and stop sending traffic while the
  app is down.

Open ports 80 and 443 to Caddy, and keep 8787 closed to the outside.

## Put Cloudflare in front

### With Cloudflare Tunnel

A tunnel needs no open ports at all. `cloudflared` runs next to Bendo, keeps an
outbound connection to Cloudflare, and forwards requests to the loopback
address. Cloudflare handles TLS at its edge.

```sh
cloudflared tunnel login
cloudflared tunnel create myapp
cloudflared tunnel route dns myapp api.example.com
```

Then point the tunnel at Bendo in `/etc/cloudflared/config.yml`:

```yaml
tunnel: myapp
credentials-file: /etc/cloudflared/<tunnel-id>.json
ingress:
  - hostname: api.example.com
    service: http://127.0.0.1:8787
  - service: http_status:404
```

`cloudflared` connects from `127.0.0.1` and passes on the
`X-Forwarded-For` header that Cloudflare's edge set, so the same
`proxies()` list works. Install it as a service with
`sudo cloudflared service install`.

### With the Cloudflare proxy and Caddy

If DNS is proxied through Cloudflare to a server running Caddy, there are two
proxies in front of Bendo:

1. In Cloudflare, set the SSL/TLS mode to **Full (strict)**, so Cloudflare
   checks Caddy's certificate.
2. Tell Caddy to keep the `X-Forwarded-For` value that Cloudflare sends, by
   trusting Cloudflare's address ranges in the global options:

   ```text
   {
   	servers {
   		trusted_proxies static 173.245.48.0/20 103.21.244.0/22
   	}
   }
   ```

   List every range from [cloudflare.com/ips](https://www.cloudflare.com/ips/);
   the two above are only the start of the list.
3. Add the same ranges to `proxies()` in the app, next to `127.0.0.1/32`.
   Caddy appends the Cloudflare edge's address to the header, and Bendo must
   skip it to reach the client.

Cloudflare closes a request that sends nothing for 100 seconds. Keep
Server-Sent Events and WebSockets busy with heartbeats or pings more often
than that; the [WebSocket guide](websockets.md#keep-connections-alive) sets a
ping every 20 seconds.

## Check it

From the server, call the app the way the proxy does, with a forwarded
address:

```sh
curl -H 'X-Forwarded-For: 203.0.113.7' http://127.0.0.1:8787/api/whoami   # 203.0.113.7
curl -i -H 'X-Forwarded-For: 203.0.113.7' http://127.0.0.1:8787/admin/whoami   # 403 Forbidden
curl -i http://127.0.0.1:8787/api/whoami | grep -i ratelimit
```

```text
ratelimit-policy: "api";q=100;w=60
ratelimit: "api";r=99;t=54
```

Then call the public address through the proxy. `/api/whoami` should print
your own public IP address, not `127.0.0.1` and not a Cloudflare address.

## The complete app

::: details main.bend
```bend
import Base
import ./bendo/main.bend as B
import ./bendo/app/context.bend as C

type Env is Data:
  Env{limiter: B.RateLimiter, trusted: List<&2, B.Cidr>}

type Tag is Data:
  Health{}
  Whoami{}
  Legacy{}
  Limit{}
  Builtin{id: B.Builtin}

# The proxies that connect to Bendo directly. Caddy and cloudflared both run
# on the same machine, so that is the loopback address.
def proxies() -> List<&2, String>:
  ["127.0.0.1/32"]

# Only the office network may reach /admin.
def admin_networks() -> List<&2, String>:
  ["198.51.100.0/24"]

def address(found: Maybe<&2, String>) -> String:
  match found:
    case Some{ip}: ip
    case None{}: "unknown"

# An older service on the same machine, reached through /legacy. Caddy already
# set X-Forwarded-For, so append to it instead of replacing it.
def legacy() -> B.ProxyOptions:
  B.proxy_trust_forwarded(B.proxy_rewrite(B.proxy_options("http://127.0.0.1:9000"), "/legacy", ""), True{})

def handle(tag: Tag, +c: B.Context(Unit), env: Env) -> IO(B.Res):
  match tag env:
    case Health{} _: IO.pure(B.Res, C.text(Unit, c, "ok"))
    case Whoami{} Env{limiter, trusted}: IO.pure(B.Res, C.text(Unit, c, address(B.client_address(Unit, c, trusted))))
    case Legacy{} _: B.proxy_with(Unit, c, legacy())
    case _ _: IO.pure(B.Res, C.not_found(Unit, c))

def handler(tag: Tag, c: B.Context(Unit), env: Env) -> IO(B.Res):
  handle(tag, c, env)

def middleware(tag: Tag, c: B.Context(Unit), env: Env, next: B.Context(Unit) -> IO(B.Res)) -> IO(B.Res):
  match tag env:
    case Builtin{id} _: B.builtin(Unit, id, c, next)
    case Limit{} Env{limiter, trusted}: B.rate_limit(Unit, limiter, c, next)
    case _ _: next(c)

def routes(admin: B.IpPolicy) -> List<&2, B.Registration(Tag)>:
  [B.use(Tag, Builtin{B.logger()}),
   B.use_path(Tag, "/admin/*", Builtin{B.ip_restriction(admin)}),
   B.use_path(Tag, "/api/*", Limit{}),
   B.get(Tag, "/healthz", Health{}),
   B.get(Tag, "/api/whoami", Whoami{}),
   B.get(Tag, "/admin/whoami", Whoami{}),
   B.all(Tag, "/legacy/*", Legacy{})]

def ready(env: Env, result: Result<&2, &2, B.RouteError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid routes")
    case Done{table}: B.serve_with(~Unit, ~Tag, ~Env, ~handler, ~middleware, table, env, B.production(B.config()))

def start(trusted: Maybe<&2, List<&2, B.Cidr>>, admin: Maybe<&2, B.IpPolicy>) -> IO(Unit):
  match trusted admin:
    case Some{+ranges} Some{policy}:
      do IO<Unit>:
        limiter : B.RateLimiter <- B.rate_limiter_with(B.rate_limit_config("api", B.fixed_window(100n, 60000n), 10000n, ranges))
        ready(Env{limiter, ranges}, B.routes(Tag, routes(policy)))
    case _ _: IO.die(Unit, 1, "invalid proxy or admin address ranges")

def main() -> IO(Unit):
  start(B.cidrs(proxies()), B.ip_policy([], admin_networks(), proxies()))
```
:::

## Read on

- [Connection info and rate limits](../connection.md) explains the
  `X-Forwarded-For` walk, address syntax and rate-limit policies.
- [Workers](../workers.md) covers startup, failure and the limits of several
  processes.
- [Proxy](../proxy.md) is the reference for forwarding requests from Bendo.
