# IMAP Proxy example

A small IMAP proxy that sits between a mail client and an upstream IMAP server and logs
the (PII-redacted) traffic flowing through it. Each accepted client connection is
parsed into `CommandStreamPart`s, forwarded over a TLS connection to the upstream
server, and the server's `Response`s are forwarded back.

It's a debugging/learning tool that shows how to build a bidirectional relay with
`NIOAsyncChannel` and structured concurrency — not a production-ready proxy.

## Running

From the repository root:

```sh
swift run --package-path Examples/Proxy Proxy <bind-host> <bind-port> <server-host> <server-port>
```

For example, to listen on loopback port 1430 and forward to `imap.example.com:993`:

```sh
swift run --package-path Examples/Proxy Proxy 127.0.0.1 1430 imap.example.com 993
```

Then point a mail client at `127.0.0.1:1430` (with TLS disabled — see below).

## Security caveats

This example prioritises clarity over hardening. Keep the following in mind:

- **The client-facing side is plaintext.** There is no TLS on the listening socket, so
  the mail client's credentials and message content cross the client → proxy hop in the
  clear. **Only bind to a loopback address** (`127.0.0.1` / `::1`); never expose it on a
  routable interface.

- **The upstream side requires a DNS hostname.** The connection to the upstream server
  uses TLS with full certificate *and* hostname verification (`.clientDefault`), so
  `<server-host>` must be a DNS name that matches the server's certificate. An IP
  address will fail SNI/hostname verification and the connection will be rejected — this
  is intentional (it fails closed rather than downgrading security).

- **There are no resource limits.** The proxy accepts an unbounded number of concurrent
  connections and enforces no idle, read, or handshake timeouts, so it is not hardened
  against slow-loris or connection-flood style resource exhaustion. A production proxy
  would add timeouts (e.g. `IdleStateHandler`) and bound concurrency.

Traffic is logged through `CommandStreamPart.descriptionWithoutPII(_:)` and
`Response.descriptionWithoutPII(_:)`, which redact credentials, tokens, message bodies,
and addresses. Byte *lengths* of redacted fields are still shown.
