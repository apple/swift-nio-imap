# Getting Started with IMAPCommands

Open a connection, log in, and issue commands as awaitable calls.

## Overview

IMAPCommands is centered on ``IMAPConnection``. You open a connection with ``IMAPConnection/withConnection(configuration:isolation:_:)``, then send commands and `await` their responses inside the closure. The connection closes automatically when the closure returns.

### Configuring a connection

Describe the server with an ``IMAPConnection/Configuration``:

```swift
import IMAPCommands

let configuration = IMAPConnection.Configuration(
    hostname: "mail.example.com",
    port: 993,
    useTLS: true,
    logging: .noLogging
)
```

### Opening a connection and sending commands

``IMAPConnection/withConnection(configuration:isolation:_:)`` hands you the server ``IMAPConnection/Greeting`` and a connection. Send a command with ``IMAPConnection/send(_:isolation:_:)``: the closure receives the command’s ``IMAPConnection/Tag`` and a stream of the `Response` values the server produces while the command runs, up to and including its final `TaggedResponse`.

```swift
try await IMAPConnection.withConnection(configuration: configuration) { greeting, connection in
    // Log in. Wait for the tagged completion response.
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

Commands are pipelined by sending them concurrently from a task group. Each `send` awaits its own command’s final `TaggedResponse`. Note, though, that IMAP does not tag untagged responses: while commands are in flight, every untagged `Response` is delivered to *all* in-flight `send` handlers, and some untagged responses are unsolicited and belong to no command at all. This is inherent to the protocol — each handler should act only on the responses it cares about.

### Closures, isolation, and concurrency

None of these closures is `@Sendable` or `@escaping`, and each one inherits the isolation of the code that calls it. A closure can therefore capture and mutate a local variable, or touch state belonging to the actor it was written in — including `@MainActor` state — without any of it having to be `Sendable`:

```swift
@MainActor
func refresh(model: MailboxModel) async throws {
    try await IMAPConnection.withConnection(configuration: configuration) { _, connection in
        try await connection.send(.select(MailboxName("INBOX"))) { _, responses in
            try await responses.forEach { response in
                model.apply(response)  // `model` is @MainActor, and not Sendable
            }
        }
    }
}
```

Concurrency is never imposed on you: if you want commands to overlap, spawn a task group yourself — the `IMAPConnection` and its `ResponseStream`s are `Sendable`, so they can be shared between child tasks.

The connection itself runs in a child task of `withConnection(configuration:isolation:_:)`. If it fails, your closure is *not* cancelled; the failure surfaces the next time the closure touches the connection, as an error from the response stream or from the next command.

### Logging

Diagnostics go to swift-log’s task-local logger. Bind one with `withLogger(_:)` around the connection, and the connection picks it up — there is no logger to configure on the ``IMAPConnection/Configuration``:

```swift
import Logging

var logger = Logger(label: "com.example.mail")
logger.logLevel = .trace  // Connection diagnostics are `.debug` and `.trace`.

try await withLogger(logger) { _ in
    try await IMAPConnection.withConnection(configuration: configuration) { greeting, connection in
        // Connection lifecycle events are logged to `logger`.
    }
}
```

Command handlers run with the command’s tag merged into the task-local logger, so anything *you* log from a handler is attributed to the command it belongs to without your having to thread the tag through:

```swift
try await connection.send(.select(MailboxName("INBOX"))) { _, responses in
    // Logs with metadata `imap.tag: A2, imap.connection: 1`.
    Logger.current.info("Selecting mailbox")
    return try await responses.waitForCompletion()
}
```

Two metadata keys are bound: `imap.tag` identifies the command, and `imap.connection` identifies the connection it runs on — tags restart at `A1` on each connection, so the tag alone is ambiguous once you have more than one open. `imap.connection` is an opaque counter. Nothing derived from the endpoint is logged: a hostname can identify a person, and swift-log has no redaction a library can rely on, since `Logger.MetadataValueAttributes` only takes effect in handlers that opt into inspecting it. Log the endpoint yourself if you want it, where you can judge whether that is appropriate.

Setting ``IMAPConnection/Configuration/logging`` to `logging` adds low-level tracing of every channel event, through the same logger at the `.trace` level:

```swift
let configuration = IMAPConnection.Configuration(
    hostname: "imap.example.com",
    port: 993,
    useTLS: true,
    logging: .logging  // Traces every channel event at `.trace`.
)
```

> Warning: Those traces include the data read and written, so they carry message content and the commands sent to the server — including credentials. Use them for local debugging, not where the log stream is collected or shipped off the device.

### Commands with a different shape

Some commands don’t fit the simple request/response shape and have dedicated APIs:

- ``IMAPConnection/sendIdle(isolation:_:)`` runs `IDLE`, ending it when the closure returns.
- ``IMAPConnection/sendAuthenticate(mechanism:initialResponse:isolation:_:)`` runs `AUTHENTICATE`, giving the closure a ``IMAPConnection/ContinuationWriter`` to answer the server’s challenges.
- ``IMAPConnection/append(to:isolation:writing:reading:)`` streams an `APPEND`: one closure writes the message data with an ``IMAPConnection/AppendWriter`` while the other concurrently reads the command’s responses. ``IMAPConnection/append(to:isolation:_:)`` passes the writer and the responses to a single closure instead, leaving the interleaving — and whether there is any — to you.

### Choosing between the two interfaces

This package offers two interface styles on purpose, and neither is preferred over the other:

- **IMAPCommands** (this module) is command-centric. You open a connection and `await` each command as an ordinary asynchronous call. Reach for it when you’d rather treat each command as an awaitable unit of work.
- **`NIOIMAP`** is event-driven. It provides SwiftNIO `ChannelHandler`s — `IMAPClientHandler` and `IMAPServerHandler` — that you insert into a `ChannelPipeline`, writing commands and consuming decoded responses as a raw stream of protocol events. Reach for it when your code already lives in a NIO pipeline, or when you want direct control over the event stream and encoding options.

Both talk to the same server and share the same `NIOIMAPCore` command and response types, so a client built on one can be ported to the other without changing how commands and responses are constructed. If neither obviously fits, prototype the part you care about most in each — they’re deliberately close in capability, and the better fit usually becomes clear quickly.

## Topics

### Connections

- ``IMAPConnection``
- ``IMAPConnection/Configuration``
