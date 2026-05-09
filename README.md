# swift-nio-imap

A Swift implementation of the IMAP4rev1 protocol (RFC 3501 and related RFCs), built on [SwiftNIO](https://github.com/apple/swift-nio).

It is intended as a building block for mail clients and servers, and provides:

* Parsing of the IMAPv4 wire format into type-safe Swift values
* Encoding of those Swift values back into the IMAPv4 wire format
* Extensive support for common IMAP extensions
* Integration with SwiftNIO, plus an imperative-style `async`/`await` client interface

> ⚠️ **Note:** This library is still under development and is not yet ready for use in production systems. ⚠️

## Overview

The package is layered, so you can work at whichever level suits your needs:

| Module | What it gives you |
| --- | --- |
| **`NIOIMAPCore`** | The IMAP grammar as Swift types, plus the parser and encoder that convert between those types and the wire format. No networking. |
| **`NIOIMAP`** | SwiftNIO `ChannelHandler`s — `IMAPClientHandler` and `IMAPServerHandler` — that plug the parser/encoder into a `ChannelPipeline`. Re-exports `NIOIMAPCore`. |
| **`IMAPCommands`** | An imperative-style `async`/`await` client built on top of `NIOIMAP`, centered on `IMAPConnection`. |

`NIOIMAPCore` and `NIOIMAP` are the foundation. On top of them, the package offers **two different client interfaces**, described next.

## Two client interfaces — pick the one that fits you

There are two distinct ways to drive an IMAP conversation with this package. They are **two different interface styles**, offered on purpose.

**Neither is preferred over the other**, and neither is "higher level" in a way that makes it the default choice. One will be a better fit for some clients; the other will be a better fit for others. Choose based on how *your* code wants to be structured — not on any recommendation from us, because we intentionally don't make one.

### Interface A — Command-centric (`IMAPCommands`)

An imperative `async`/`await` interface. You open a connection, send commands, and `await` their responses as ordinary asynchronous calls. Commands can be pipelined by sending them concurrently from a task group.

This style fits code that wants to express an IMAP session as a straightforward sequence (or concurrent set) of "send command → handle its responses" steps.

```swift
import IMAPCommands

let configuration = IMAPConnection.Configuration(
    hostname: "mail.example.com",
    port: 993,
    useTLS: true,
    logging: .noLogging
)

try await IMAPConnection.withConnection(configuration: configuration) { greeting, connection in
    // Log in.
    try await connection.send(.login(username: "mrc", password: "secret")) { tag, responses in
        try await responses.waitForCompletion()
    }

    // Select a mailbox and inspect the untagged responses it produces.
    try await connection.send(.select(MailboxName("INBOX"))) { tag, responses in
        try await responses.forEach { response in
            print(response)
        }
    }
}
```

`IMAPCommands` also provides dedicated APIs for the commands that don't fit the simple request/response shape — `sendIdle` for `IDLE`, `sendAuthenticate` for `AUTHENTICATE` challenge/response, and `append` for streaming an `APPEND`.

### Interface B — Event stream (`NIOIMAP` channel handlers)

An event-driven, stream-based interface. `NIOIMAP` provides a pair of SwiftNIO `ChannelHandler`s — `IMAPClientHandler` and `IMAPServerHandler` — that you insert into a `ChannelPipeline`. Wrapped in a `NIOAsyncChannel`, you write `CommandStreamPart` values to the outbound writer and consume decoded `Response` values from the inbound stream.

This style fits code that already lives in a SwiftNIO pipeline, or that wants direct control over the stream of protocol events and encoding options.

```swift
import NIOIMAP

// Connect and wrap the channel so the handler's decoded `Response`s and the
// commands we write flow through async sequences.
let channel = try await ClientBootstrap(group: MultiThreadedEventLoopGroup.singleton)
    .connect(host: "mail.example.com", port: 143)
    .flatMap { channel in
        channel.eventLoop.makeCompletedFuture {
            try channel.pipeline.syncOperations.addHandler(IMAPClientHandler())
            return try NIOAsyncChannel<Response, IMAPClientHandler.OutboundIn>(
                wrappingChannelSynchronously: channel
            )
        }
    }
    .get()

try await channel.executeThenClose { inbound, outbound in
    // Send a command.
    try await outbound.write(
        .part(.tagged(TaggedCommand(tag: "a001", command: .login(username: "mrc", password: "secret"))))
    )

    // Consume the stream of decoded responses.
    for try await response in inbound {
        print(response)
    }
}
```

### Which should I use?

Both interfaces talk to the same server and share the same `NIOIMAPCore` types for commands and responses. As a rough guide:

* Reach for **`IMAPCommands`** when you'd rather write `let response = try await connection.send(...)` and treat each command as an awaitable unit of work.
* Reach for **`NIOIMAP`** when you want to work directly with the SwiftNIO pipeline and consume the raw stream of protocol events.

If neither obviously fits, prototype the part of your client you care about most in each — they're deliberately close in capability, and the better fit usually becomes clear quickly.

## The shared type layer

Whichever interface you choose, commands and responses are the same strongly typed `NIOIMAPCore` values. Here's part of the exchange from RFC 3501 §8, where `S:` and `C:` lines are from the server and client respectively:

```text
S: * OK IMAP4rev1 Service Ready
C: a001 login mrc secret
S: a001 OK LOGIN completed
C: a002 select inbox
S: * 18 EXISTS
S: * FLAGS (\Answered \Flagged \Deleted \Seen \Draft)
S: * OK [UIDVALIDITY 3857529045] UIDs valid
S: a002 OK [READ-WRITE] SELECT completed
```

The client commands above are represented as:

```swift
CommandStreamPart.tagged(TaggedCommand(tag: "a001", command: .login(username: "mrc", password: "secret")))
CommandStreamPart.tagged(TaggedCommand(tag: "a002", command: .select(MailboxName("inbox"))))
```

And the server responses as:

```swift
Response.untagged(.conditionalState(.ok(ResponseText(text: "IMAP4rev1 Service Ready"))))
Response.tagged(.init(tag: "a001", state: .ok(ResponseText(text: "LOGIN completed"))))
Response.untagged(.mailboxData(.exists(18)))
Response.untagged(.mailboxData(.flags([.answered, .flagged, .deleted, .seen, .draft])))
Response.untagged(.conditionalState(.ok(ResponseText(code: .uidValidity(3857529045), text: "UIDs valid"))))
Response.tagged(.init(tag: "a002", state: .ok(ResponseText(code: .readWrite, text: "SELECT completed"))))
```

This gives a general feel for how the types look. See the DocC documentation for `NIOIMAPCore` for the full command and response grammar.

## Adding the dependency

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/apple/swift-nio-imap.git", from: "0.4.0"),
],
```

Then depend on the module for the interface you chose:

```swift
.target(
    name: "MyMailClient",
    dependencies: [
        // Command-centric interface (also pulls in NIOIMAP and NIOIMAPCore):
        .product(name: "IMAPCommands", package: "swift-nio-imap"),
        // ...or the event-stream interface on its own:
        .product(name: "NIOIMAP", package: "swift-nio-imap"),
    ]
)
```

The package requires Swift 6, supports macOS 15 and iOS 18 (or later), and is built on SwiftNIO 2.x.

## Examples

The [`Examples`](Examples) directory contains standalone packages that build on this library, including a command-line IMAP debugging tool (`imap-tool`), a smaller CLI, a logging proxy, a parser fuzzer, and performance benchmarks. Each is its own Swift package with a local path dependency on the repository root, so the library's own dependency graph stays minimal.

See [`Examples/README.md`](Examples/README.md) for details on building and running them.

## Supported extensions

`swift-nio-imap` supports a wide range of IMAP extensions. For the full list, see [`SupportedExtensions`](Sources/NIOIMAPCore/NIOIMAPCore.docc/SupportedExtensions.md) in the `NIOIMAPCore` DocC documentation.

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md) before opening a pull request. Security issues should be reported as described in [SECURITY.md](SECURITY.md).

## License

`swift-nio-imap` is released under the Apache 2.0 license. See [LICENSE.txt](LICENSE.txt) for details.
