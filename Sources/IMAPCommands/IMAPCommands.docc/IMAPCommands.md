# ``IMAPCommands``

Drive an IMAP4rev1 conversation with a command-centric `async`/`await` client.

## Overview

IMAPCommands is a high-level IMAP client built on top of the `NIOIMAP` module. It is centered on ``IMAPConnection``: you open a connection, send commands, and `await` their responses as ordinary asynchronous calls.

This is an **imperative, command-centric** interface. Each command is an awaitable unit of work — `try await connection.send(.login(...)) { ... }` — and the closure you pass receives the `Response` values the server produces while that command runs, up to and including its final `TaggedResponse`. Commands are pipelined by sending them concurrently from a task group. This style fits code that wants to express an IMAP session as a straightforward sequence, or concurrent set, of “send command → handle its responses” steps.

Alongside ``IMAPConnection/send(_:_:)``, the module provides dedicated APIs for the commands that don’t fit the simple request/response shape: ``IMAPConnection/sendIdle(_:)`` for `IDLE`, ``IMAPConnection/sendAuthenticate(mechanism:initialResponse:_:)`` for `AUTHENTICATE` challenge/response, and ``IMAPConnection/append(to:writing:reading:)`` for streaming an `APPEND`.

- Note: This is one of **two** interface styles this package offers, and neither is preferred over the other. If you’d rather work directly with the SwiftNIO pipeline and the raw stream of protocol events, see the `NIOIMAP` module, which provides the event-driven `ChannelHandler`s this client is built on. Both interfaces talk to the same server and share the same `NIOIMAPCore` command and response types; choose based on how your own code wants to be structured. See <doc:GettingStarted> for a side-by-side comparison.

### How a command can fail

Three different things are easy to conflate, and only the first is an error the connection raises:

| What went wrong | How you see it |
| --- | --- |
| The connection — could not open, broke, or closed mid-command | ``IMAPConnection/Error``, thrown from `send`, `append`, and the response stream |
| The server refused the command with `NO` or `BAD` | Not an error. It arrives as the command's `TaggedResponse`; `checkOK()` or `getOK()` turns it into ``TaggedResponse/StateNotOK`` |
| Your own handler closure threw | Rethrown unchanged. `send` and friends never wrap a handler's error |

Declarations whose failures are limited to one of these use typed throws, so the error type is part of the signature: ``IMAPConnection/ResponseStream/waitForCompletion()`` throws ``IMAPConnection/Error``, and `checkOK()` / `getOK()` throw ``TaggedResponse/StateNotOK``. The closure-taking APIs stay untyped, because the error a handler throws is by definition open.

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

### Errors

- ``IMAPConnection/Error``
- ``IMAPConnection/IncompleteAppend``
- ``IMAPConnection/AppendAlreadyFinished``

### Debugging

- ``makeInboundDebugHandler(logger:)``
- ``makeOutboundDebugHandler(logger:)``
