# ``NIOIMAP``

Drive an IMAP4rev1 conversation as a stream of protocol events on a SwiftNIO `ChannelPipeline`.

## Overview

NIOIMAP connects the parser and encoder from `NIOIMAPCore` to [SwiftNIO](https://github.com/apple/swift-nio). It provides a pair of `ChannelHandler`s — ``IMAPClientHandler`` and ``IMAPServerHandler`` — that you insert into a `ChannelPipeline`. The client handler turns the inbound byte stream into decoded `Response` values and encodes the `CommandStreamPart` values you write back into IMAP wire format.

This is an **event-driven** interface. You work directly with the stream of protocol events: you write commands to the pipeline and consume decoded responses as they arrive, typically by wrapping the channel in a `NIOAsyncChannel`. This style fits code that already lives in a SwiftNIO pipeline, or that wants direct control over the flow of protocol events and over encoding options.

NIOIMAP re-exports `NIOIMAPCore`, so the strongly-typed command and response values are available without a separate import.

- Note: This is one of **two** interface styles this package offers, and neither is preferred over the other. If you'd rather treat each command as an awaitable unit of work — `let result = try await connection.send(...)` — see the `IMAPCommands` module, which provides a command-centric `async`/`await` client built on top of NIOIMAP. Both interfaces talk to the same server and share the same `NIOIMAPCore` command and response types; choose based on how your own code wants to be structured. See <doc:GettingStarted> for a side-by-side comparison.

### Layering

The package is layered so you can work at whichever level suits your needs:

| Module | What it gives you |
| --- | --- |
| `NIOIMAPCore` | The IMAP grammar as Swift types, plus the parser and encoder. No networking. |
| **`NIOIMAP`** | SwiftNIO `ChannelHandler`s that plug the parser and encoder into a `ChannelPipeline`. Re-exports `NIOIMAPCore`. |
| `IMAPCommands` | A high-level `async`/`await` client centered on `IMAPConnection`, built on top of NIOIMAP. |

## Topics

### Essentials

- <doc:GettingStarted>

### Channel Handlers

- ``IMAPClientHandler``
- ``IMAPServerHandler``

### Framing

- ``FrameDecoder``
- ``FramingParser``
- ``FramingResult``

### Errors

- ``InvalidFrame``
- ``LiteralSizeParsingError``
- ``ReceivedIncompleteFrame``
- ``ReceivedInvalidFrame``
- ``IMAPDecoderError``
- ``UnexpectedResponse``
- ``UnexpectedContinuationRequest``
- ``UnexpectedAppendCommand``
- ``UnexpectedChunk``
- ``DuplicateCommandTag``
- ``InvalidClientState``
- ``InvalidCommandForState``
- ``InvalidIdleState``
