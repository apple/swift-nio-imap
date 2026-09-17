# Getting Started with NIOIMAP

Open a connection, insert the client handler, and exchange commands and responses as a stream of events.

## Overview

NIOIMAP gives you a SwiftNIO `ChannelHandler` — ``IMAPClientHandler`` — that decodes the inbound byte stream into `Response` values and encodes the `CommandStreamPart` values you write into IMAP wire format. To drive a session with `async`/`await`, add the handler to a `ChannelPipeline` and wrap the channel in a `NIOAsyncChannel`.

### Connecting

Connect to the server, add ``IMAPClientHandler`` to the pipeline, and wrap the channel so that decoded responses and the commands you write flow through async sequences:

```swift
import NIOIMAP

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
```

For a TLS connection (typically port 993), insert an `NIOSSLClientHandler` ahead of ``IMAPClientHandler`` in the pipeline.

### Sending commands and consuming responses

Each command is written as a `CommandStreamPart`. Decoded responses — including untagged responses and the final `TaggedResponse` — arrive on the inbound async sequence:

```swift
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

Because this is an event stream, correlating responses with the commands that produced them — matching on the command tag — is your responsibility. Commands are pipelined simply by writing several before reading their responses.

### Choosing between the two interfaces

This package offers two interface styles on purpose, and neither is preferred over the other:

- **NIOIMAP** (this module) is event-driven. You work directly with the SwiftNIO pipeline and the raw stream of protocol events. Reach for it when your code already lives in a NIO pipeline, or when you want direct control over the event stream and encoding options.
- **`IMAPCommands`** is command-centric. You open a connection and `await` each command as an ordinary asynchronous call — `try await connection.send(.login(...)) { ... }`. Reach for it when you'd rather treat each command as an awaitable unit of work.

Both talk to the same server and share the same `NIOIMAPCore` command and response types, so a client built on one can be ported to the other without changing how commands and responses are constructed. If neither obviously fits, prototype the part you care about most in each — they're deliberately close in capability, and the better fit usually becomes clear quickly.

## Topics

### Channel Handlers

- ``IMAPClientHandler``
- ``IMAPServerHandler``
