# ``IMAPCommands``

Drive an IMAP4rev1 conversation with a command-centric `async`/`await` client.

## Overview

IMAPCommands is a high-level IMAP client built on top of the `NIOIMAP` module. It is centered on ``IMAPConnection``: you open a connection, send commands, and `await` their responses as ordinary asynchronous calls.

This is an **imperative, command-centric** interface. Each command is an awaitable unit of work — `try await connection.send(.login(...)) { ... }` — and the closure you pass receives the `Response` values the server produces while that command runs, up to and including its final `TaggedResponse`. Commands are pipelined by sending them concurrently from a task group. This style fits code that wants to express an IMAP session as a straightforward sequence, or concurrent set, of “send command → handle its responses” steps.

Alongside ``IMAPConnection/send(_:isolation:_:)``, the module provides dedicated APIs for the commands that don’t fit the simple request/response shape: ``IMAPConnection/sendIdle(isolation:_:)`` for `IDLE`, ``IMAPConnection/sendAuthenticate(mechanism:initialResponse:isolation:_:)`` for `AUTHENTICATE` challenge/response, and ``IMAPConnection/append(to:isolation:writing:reading:)`` for streaming an `APPEND`.

- Note: This is one of **two** interface styles this package offers, and neither is preferred over the other. If you’d rather work directly with the SwiftNIO pipeline and the raw stream of protocol events, see the `NIOIMAP` module, which provides the event-driven `ChannelHandler`s this client is built on. Both interfaces talk to the same server and share the same `NIOIMAPCore` command and response types; choose based on how your own code wants to be structured. See <doc:GettingStarted> for a side-by-side comparison.

### Layering

The package is layered so you can work at whichever level suits your needs:

| Module | What it gives you |
| --- | --- |
| `NIOIMAPCore` | The IMAP grammar as Swift types, plus the parser and encoder. No networking. |
| `NIOIMAP` | SwiftNIO `ChannelHandler`s that plug the parser and encoder into a `ChannelPipeline`. Re-exports `NIOIMAPCore`. |
| **`IMAPCommands`** | A high-level `async`/`await` client centered on ``IMAPConnection``, built on top of NIOIMAP. |

## Topics

### Essentials

- <doc:GettingStarted>
- ``IMAPConnection``

### Configuration

- ``IMAPConnection/Configuration``
- ``IMAPCredential``

### Streaming an APPEND

- ``IMAPConnection/AppendWriter``

### Authentication Challenges

- ``IMAPConnection/ContinuationWriter``

### Command Results

- ``CompletedCommand``
- ``SuccessfulCommand``

### Debugging

- ``makeInboundDebugHandler(name:)``
- ``makeOutboundDebugHandler(name:)``
