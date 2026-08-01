//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Logging
import NIO
import NIOIMAP
import NIOSSL
import Synchronization

/// An async connection to an IMAP server.
///
/// Commands can be sent concurrently using IMAP pipelining.
///
/// ```swift
/// try await IMAPConnection.withConnection(configuration: myConfig) { greeting, connection in
///     // Use connection here.
/// }
/// ```
///
/// - Important: IMAP does not tag untagged responses, so while commands are pipelined every
///   untagged `Response` is delivered to _all_ in-flight command handlers (see
///   ``send(_:isolation:_:)``). Handlers must act only on the responses they care about.
public final class IMAPConnection: Sendable {
    private init(
        configuration: Configuration
    ) {
        self.configuration = configuration
        self.outboundWriter = OutboundQueue()
    }

    let configuration: Configuration
    private let outboundWriter: OutboundQueue
    private let state = Mutex(State())

    struct State: Sendable {
        var perCommandResponseStreams = PerCommandResponseStream()
        var greeting: GreetingState = .waiting([])
    }

    /// Creates an IMAP connection and runs the given closure.
    ///
    /// The closure can send commands to the connection and receive responses from the server.
    /// Use task groups to pipeline commands concurrently.
    ///
    /// The connection itself runs in a child task while `body` runs in the calling task. As a
    /// result `body` needs to be neither `@Sendable` nor `@escaping`: it can capture and mutate
    /// non-`Sendable` state, and it runs in the caller’s isolation domain.
    ///
    /// The connection closes when the `body` closure returns or throws.
    ///
    /// - Note: A failing connection does _not_ cancel `body`. Instead, the failure surfaces the
    ///   next time `body` interacts with the connection: pending and subsequent
    ///   ``ResponseStream``s and ``send(_:isolation:_:)`` calls fail with the underlying error.
    ///   A `body` that neither returns nor touches the connection again keeps
    ///   `withConnection(configuration:isolation:_:)` from returning.
    public static func withConnection<Result: _IMAPClosureResult>(
        configuration: Configuration,
        isolation: isolated (any Actor)? = #isolation,
        _ body: (Greeting, IMAPConnection) async throws -> Result
    ) async throws -> Result {
        let connection = IMAPConnection(configuration: configuration)

        return try await withThrowingTaskGroup(
            of: Void.self,
            returning: Result.self
        ) { group in
            // Create a child task that “runs” the connection receiving inbound and sending
            // commands. Its error is never rethrown from here — the group discards the errors
            // of tasks that are still running when this closure returns, and `run(logging:)`
            // reports its failure through `close(reason:)` instead, so that whatever `body`
            // does with the connection next fails with that error.
            group.addTask {
                try await connection.run(logging: configuration.logging)
            }

            // Run the `body` — the caller’s code that sends commands — in _this_ task:
            do {
                // Wait for the greeting:
                let greeting = try await connection.greeting
                let result = try await body(greeting, connection)
                connection.configuration.logger.debug("Closing connection after body completed")
                connection.close(reason: .closed)
                group.cancelAll()
                return result
            } catch {
                connection.configuration.logger.debug(
                    "Closing connection after body threw",
                    metadata: ["error": "\(error)"]
                )
                connection.close(reason: .failed(error))
                group.cancelAll()
                throw error
            }
        }
    }

    /// Sets the encoding options for commands sent to the server.
    public func setEncodingOptions(
        _ new: IMAPClientHandler.EncodingOptions
    ) async throws {
        try await outboundWriter.setEncodingOptions(new)
    }

    /// Sends the given command to the server.
    ///
    /// The closure receives the `Response` values the server produces while the command
    /// runs, up to and including the `TaggedResponse` for this command.
    ///
    /// - Important: IMAP does not associate untagged responses with a particular command.
    ///   Every untagged `Response` the server emits while _any_ command is in flight is
    ///   delivered to _all_ in-flight command handlers — and some untagged responses are
    ///   unsolicited and belong to no command at all. Only the final `TaggedResponse`
    ///   (which `waitForCompletion()` waits for) is specific to this command. This is
    ///   inherent to the protocol and how pipelining works; when you send commands
    ///   concurrently, each handler must inspect only the responses it actually cares about.
    public func send<Result: _IMAPClosureResult>(
        _ command: Command,
        isolation: isolated (any Actor)? = #isolation,
        _ handler: (Tag, ResponseStream) async throws -> Result
    ) async throws -> Result {
        let (tag, responseStream) = try state.withLock { state in
            state.perCommandResponseStreams.makeTagAndResponseStream()
        }.get()

        try await outboundWriter.write(
            TaggedCommand(
                tag: "\(tag)",
                command: command
            )
        )

        return try await handler(tag, ResponseStream(underlying: responseStream))
    }

    /// Sends an `IDLE` command to the server.
    ///
    /// The handler receives the `Response` values the server produces while idling. Returning
    /// from the handler ends the `IDLE`: `sendIdle(isolation:_:)` then sends `DONE`.
    ///
    /// - Important: The command’s `TaggedResponse` only arrives _after_ `DONE`, so the handler
    ///   must not wait for the command to complete — use the stream to observe untagged
    ///   responses and return once you want to stop idling.
    public func sendIdle<Result: _IMAPClosureResult>(
        isolation: isolated (any Actor)? = #isolation,
        _ handler: (Tag, ResponseStream) async throws -> Result
    ) async throws -> Result {
        let (tag, responseStream) = try state.withLock { state in
            state.perCommandResponseStreams.makeTagAndResponseStream()
        }.get()

        try await outboundWriter.write(
            TaggedCommand(
                tag: "\(tag)",
                command: .idleStart
            )
        )

        let result: Result
        do {
            result = try await handler(tag, ResponseStream(underlying: responseStream))
        } catch {
            // Best-effort: leave IDLE even when the handler fails, so a caller
            // that catches the error and keeps using the connection doesn't
            // leave the server stuck in IDLE. (If the connection is already
            // torn down, this write simply fails and we still rethrow.)
            try? await outboundWriter.writeIdleDone()
            throw error
        }
        try await outboundWriter.writeIdleDone()
        return result
    }

    /// Sends an `AUTHENTICATE` command to the server.
    ///
    /// Use the ``ContinuationWriter`` to respond to authentication challenges.
    public func sendAuthenticate<Result: _IMAPClosureResult>(
        mechanism: AuthenticationMechanism,
        initialResponse: InitialResponse?,
        isolation: isolated (any Actor)? = #isolation,
        _ handler: (Tag, ResponseStream, borrowing ContinuationWriter) async throws -> Result
    ) async throws -> Result {
        let (tag, responseStream) = try state.withLock { state in
            state.perCommandResponseStreams.makeTagAndResponseStream()
        }.get()

        try await outboundWriter.write(
            TaggedCommand(
                tag: "\(tag)",
                command: .authenticate(
                    mechanism: mechanism,
                    initialResponse: initialResponse
                )
            )
        )

        do {
            return try await handler(
                tag,
                ResponseStream(underlying: responseStream),
                ContinuationWriter(underlying: outboundWriter)
            )
        } catch {
            // There is no clean way to abort an in-progress AUTHENTICATE exchange (the
            // `*` cancellation cannot be expressed through a base64 continuation
            // response), so if the handler fails mid-challenge we close the connection
            // rather than leave it in a half-authenticated state that can't be reused.
            close(reason: .failed(error))
            throw error
        }
    }

    /// Sends an `APPEND` command as a stream to the server.
    ///
    /// The closure writes the message data with the provided ``AppendWriter`` and consumes the
    /// command's responses from the ``ResponseStream``. `APPEND` needs at least one message, and
    /// the command is complete when the closure returns — or as soon as the closure calls
    /// ``AppendWriter/finish()``.
    ///
    /// The server sends the command's `TaggedResponse` only once the command is complete, so a
    /// closure that waits for it finishes the command first:
    ///
    /// ```swift
    /// let tagged = try await connection.append(to: mailbox) { tag, responses, writer in
    ///     try await writer.write(message: message) { messageWriter in
    ///         try await messageWriter.write(messageBytes: bytes)
    ///     }
    ///     try await writer.finish()
    ///     return try await responses.waitForCompletion()
    /// }
    /// ```
    ///
    /// To act on responses while the message data is still going out, read them from a task group
    /// of your own. The ``ResponseStream`` is `Sendable` and the ``AppendWriter`` is not, so the
    /// writer stays in the parent task:
    ///
    /// ```swift
    /// try await connection.append(to: mailbox) { tag, responses, writer in
    ///     try await withThrowingTaskGroup(of: Void.self) { group in
    ///         group.addTask {
    ///             for try await response in responses {
    ///                 print(response)
    ///             }
    ///         }
    ///         try await writer.write(message: message) { messageWriter in
    ///             try await messageWriter.write(messageBytes: bytes)
    ///         }
    ///         try await writer.finish()
    ///     }
    /// }
    /// ```
    ///
    /// ``append(to:isolation:writing:reading:)`` is that second form written for you: it takes a
    /// write closure and a `@Sendable` read closure, and runs them concurrently.
    ///
    /// - Warning: The `TaggedResponse` cannot arrive while the command is still open. Waiting for
    ///   it inside the closure without first calling ``AppendWriter/finish()`` — and without
    ///   another task writing concurrently — therefore never returns.
    /// - Note: `APPEND` cannot be pipelined: the protocol only allows the message literals to
    ///   follow the command, so any other command sent on this connection while `append` runs
    ///   is queued and written once the append completes. As with ``send(_:isolation:_:)``, the
    ///   stream also delivers untagged responses that belong to other commands, or to no command
    ///   at all; only the `TaggedResponse` is this command's.
    /// - Important: A synchronizing literal cannot be cancelled once begun. If the closure leaves
    ///   the command incomplete — because it throws part-way through, writes no message, or
    ///   begins a message it never finishes — the command cannot be completed, so this method
    ///   closes the connection. It rethrows the closure's error, or throws ``IncompleteAppend``
    ///   if the closure itself succeeded. An error the closure throws _after_ completing the
    ///   command leaves the connection intact, exactly like an error from a
    ///   ``send(_:isolation:_:)`` handler.
    /// - Parameters:
    ///   - mailbox: The mailbox to append the message to.
    ///   - isolation: The actor to run the closure on. Defaults to the caller’s isolation.
    ///   - body: Writes the message(s) with the provided ``AppendWriter`` and handles the
    ///     command's responses. It also receives the ``Tag`` that identifies this command in the
    ///     `TaggedResponse` completing it.
    /// - Returns: The value `body` returns.
    public func append<Result: _IMAPClosureResult>(
        to mailbox: MailboxName,
        isolation: isolated (any Actor)? = #isolation,
        _ body: (Tag, ResponseStream, inout AppendWriter) async throws -> Result
    ) async throws -> Result {
        let (tag, responseStream) = try state.withLock { state in
            state.perCommandResponseStreams.makeTagAndResponseStream()
        }.get()

        // Whether the `APPEND` command was written in full. If it wasn't, the server is still
        // waiting for the rest of it, and no other command can be sent on this connection.
        var didCompleteCommand = false
        do {
            // The `consuming` ownership of the closure parameter is spelled out
            // explicitly: Swift 6.0 otherwise infers it as `borrowing` here and
            // rejects handing it on to `AppendWriter.withAppendWriter`.
            return try await outboundWriter.withAppendWriter {
                (writer: consuming OutboundQueue.AppendQueueWriter) in
                try await AppendWriter.withAppendWriter(
                    tag: "\(tag)",
                    appendingTo: mailbox,
                    underlying: writer,
                    didCompleteCommand: &didCompleteCommand
                ) { innerWriter in
                    try await body(tag, ResponseStream(underlying: responseStream), &innerWriter)
                }
            }
        } catch {
            guard
                !didCompleteCommand
            else { throw error }
            // The command was started but never finished. There is no way to abort it — sending
            // anything but the remaining append data would be a protocol violation — so the
            // connection is unusable.
            configuration.logger.debug(
                "Closing connection after APPEND was left incomplete",
                metadata: ["error": "\(error)"]
            )
            close(reason: .failed(error))
            throw error
        }
    }

    /// Sends an `APPEND` command as a stream to the server, reading its responses as it writes.
    ///
    /// This is ``append(to:isolation:_:)`` with the task group written for you: `write` writes the
    /// message data while `read` concurrently consumes the responses the server sends — including
    /// any that arrive while the message data is still in flight. `read` receives the command's
    /// ``Tag`` and ``ResponseStream`` and returns the result, the same shape
    /// ``send(_:isolation:_:)``'s handler has.
    ///
    /// ```swift
    /// let tagged = try await connection.append(
    ///     to: mailbox,
    ///     writing: { tag, writer in
    ///         try await writer.write(message: message) { messageWriter in
    ///             for try await bytes in file {
    ///                 try await messageWriter.write(messageBytes: bytes)
    ///             }
    ///         }
    ///     },
    ///     reading: { tag, responses in
    ///         try await responses.waitForCompletion()
    ///     }
    /// )
    /// ```
    ///
    /// `write` has to write at least one message, and the command completes once it returns — so
    /// `read` can wait for the command's `TaggedResponse`, which arrives after the message data
    /// has gone out in full.
    ///
    /// - Note: `read` runs in a child task, which is why — alone among the closures in this API —
    ///   it has to be `@Sendable`, and `Result` has to be `Sendable`. `write` holds the
    ///   ``AppendWriter``, which cannot leave the task that owns it, so `write` runs in the
    ///   calling task and needs neither. Use ``append(to:isolation:_:)`` to keep everything in
    ///   one task.
    /// - Note: As with ``send(_:isolation:_:)``, `read` also sees untagged responses that belong
    ///   to other commands, or to no command at all; only the `TaggedResponse` is this command's.
    /// - Important: If `read` throws, `write` still writes the message in full before this method
    ///   rethrows the error: abandoning a synchronizing literal part-way would leave the
    ///   connection unusable. If `write` throws, or leaves the command incomplete, this method
    ///   cancels `read` and closes the connection, as ``append(to:isolation:_:)`` describes.
    /// - Parameters:
    ///   - mailbox: The mailbox to append the message to.
    ///   - isolation: The actor to run `write` on. Defaults to the caller’s isolation.
    ///   - write: Writes the message(s) using the provided ``AppendWriter``.
    ///   - read: Receives the responses the server sends for the command, concurrently with
    ///     `write`.
    /// - Returns: The value `read` returns.
    public func append<Result: Sendable>(
        to mailbox: MailboxName,
        isolation: isolated (any Actor)? = #isolation,
        writing write: (Tag, inout AppendWriter) async throws -> Void,
        reading read: @Sendable @escaping (Tag, ResponseStream) async throws -> Result
    ) async throws -> Result {
        try await append(to: mailbox, isolation: isolation) { tag, responses, writer in
            try await withThrowingTaskGroup(of: Result.self, returning: Result.self) { group in
                group.addTask {
                    try await read(tag, responses)
                }
                // The writer cannot be sent to another task — it is non-copyable and `inout` —
                // so writing happens here, in this task, while `read` runs in the child.
                try await write(tag, &writer)
                // The `TaggedResponse` can only arrive once the command is complete, so `read`
                // would never finish if the command were left open until this closure returns.
                try await writer.finish()
                guard
                    let result = try await group.next()
                else { throw AppendCompletedWithoutReadResult() }
                return result
            }
        }
    }

    /// An error indicating the `APPEND` read closure finished without producing a result.
    private struct AppendCompletedWithoutReadResult: Swift.Error {}
}

// MARK: -

extension IMAPConnection {
    private func makeChannel(
        logging: Configuration.Logging
    ) async throws -> NIOAsyncChannel<Response, IMAPClientHandler.OutboundIn> {
        let configuration = self.configuration
        return try await ClientBootstrap(group: MultiThreadedEventLoopGroup.sharedEventLoopGroup)
            .connect(endpoint: configuration.endpoint)
            .flatMap { [configuration] channel in
                channel.eventLoop.makeCompletedFuture {
                    var handlers: [ChannelHandler] = []
                    if configuration.useTLS {
                        handlers.append(
                            try NIOSSLClientHandler(
                                context: NIOSSLContext(configuration: .clientDefault),
                                serverHostname: configuration.endpoint.hostname
                            )
                        )
                    }
                    switch logging {
                    case .noLogging:
                        break
                    case .logging:
                        handlers.append(makeInboundDebugHandler(name: "A"))
                        handlers.append(makeOutboundDebugHandler(name: "A"))
                    }
                    handlers.append(IMAPClientHandler())
                    try channel.pipeline.syncOperations.addHandlers(handlers)
                    return try NIOAsyncChannel<Response, IMAPClientHandler.OutboundIn>(
                        wrappingChannelSynchronously: channel
                    )
                }
            }
            .get()
    }

    private func run(
        logging: Configuration.Logging
    ) async throws {
        do {
            try await makeChannel(
                logging: logging
            ).executeThenClose { inbound, outbound in
                let outboundWriter = self.outboundWriter
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask {
                        await self.runInbound(inbound)
                    }
                    group.addTask {
                        do {
                            try await outboundWriter.run(outbound: outbound)
                        } catch {
                            // Tear the connection down: the channel is gone, so anything the
                            // caller does next must fail with this error rather than park.
                            self.close(reason: .failed(error))
                            throw error
                        }
                    }

                    try await group.waitForAll()
                }
            }
            close(reason: .closed)
        } catch {
            // Ensure any awaiting caller is unblocked no matter how this exits — in
            // particular a task parked on `greeting` when the channel fails to open — and
            // that it sees _why_ the connection went away.
            close(reason: .failed(error))
            throw error
        }
    }

    /// Reads the greeting and then every subsequent response, until the stream ends.
    ///
    /// When the inbound stream ends — via a graceful EOF, a read error, or cancellation — this
    /// tears the connection down. That finishes any in-flight command response streams (and any
    /// greeting waiter) and closes the outbound queue so the outbound runner stops, instead of
    /// leaving callers parked forever.
    private func runInbound(
        _ inbound: NIOAsyncChannelInboundStream<Response>
    ) async {
        do {
            var iterator = inbound.makeAsyncIterator()
            // Get the greeting:
            guard
                let first = try await iterator.next()
            else {
                // EOF before the greeting.
                close(reason: .closed)
                return
            }
            guard
                case .untagged(.conditionalState(let s)) = first
            else {
                throw ServerSendOtherResponseBeforeGreeting(response: first)
            }
            didReceive(greeting: Greeting(status: s))
            // Loop through the remaining:
            while let response = try await iterator.next() {
                switch response {
                case .tagged(let tagged):
                    try commandDidComplete(response: tagged)
                default:
                    didReceive(response: response)
                }
            }
            close(reason: .closed)
        } catch {
            configuration.logger.debug(
                "Closing connection after inbound error",
                metadata: ["error": "\(error)"]
            )
            // The error is not rethrown: `close(reason:)` hands it to the caller instead, as
            // the error of every response stream that was still running, and of every
            // subsequent interaction with this connection.
            close(reason: .failed(error))
        }
    }

    /// Why the connection was closed.
    ///
    /// The reason determines what anything still using — or subsequently using — this
    /// connection fails with.
    enum CloseReason {
        /// The connection was closed in an orderly fashion: the caller is done with it, or the
        /// server sent EOF.
        case closed
        /// The connection failed with this error.
        case failed(any Swift.Error)

        var error: (any Swift.Error)? {
            switch self {
            case .closed: nil
            case .failed(let error): error
            }
        }
    }

    /// Mark the state as closed:
    ///
    /// Only the first call has an effect; a connection that already failed keeps the error it
    /// failed with.
    private func close(reason: CloseReason) {
        state.withLock { state in
            state.markAsClosed(reason: reason)
        }.run(logger: configuration.logger)
        outboundWriter.close()
    }

    private func commandDidComplete(response: TaggedResponse) throws {
        configuration.logger.trace("Command did complete", metadata: ["tag": "\(response.tag)"])
        try state.withLock { state in
            state.perCommandResponseStreams.popCompletedCommand(response: response)
        }.run()
    }

    private func didReceive(response: Response) {
        let all = state.withLock { state in
            state.perCommandResponseStreams.allContinuations
        }
        for c in all {
            c.yield(response)
        }
    }
}

extension ClientBootstrap {
    /// Connects to the given configuration endpoint.
    public func connect(endpoint: IMAPConnection.Configuration.Endpoint) -> EventLoopFuture<Channel> {
        switch endpoint {
        case .hostname(let host, port: let port):
            connect(host: host, port: Int(port))
        case .unixDomainSocket(path: let path):
            connect(unixDomainSocketPath: path)
        }
    }
}

extension IMAPConnection {
    /// An error indicating the server sent an unexpected response before the greeting.
    public struct ServerSendOtherResponseBeforeGreeting: Swift.Error {
        public var response: Response

        public init(
            response: Response
        ) {
            self.response = response
        }
    }
}

// MARK: -

extension IMAPConnection {
    /// A stream of responses from the server received while a specific command runs.
    public struct ResponseStream: AsyncSequence, Sendable {
        public struct AsyncIterator: AsyncIteratorProtocol {
            public typealias Element = Response

            var underlying: AsyncThrowingStream<Response, any Swift.Error>.AsyncIterator

            public mutating func next() async throws -> Response? {
                try await underlying.next()
            }
        }

        public typealias Element = Response

        let underlying: AsyncThrowingStream<Response, any Swift.Error>

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(underlying: underlying.makeAsyncIterator())
        }
    }
}

// The iterator wraps `AsyncThrowingStream.AsyncIterator`, which is not `Sendable`.
@available(*, unavailable)
extension IMAPConnection.ResponseStream.AsyncIterator: Sendable {}

extension IMAPConnection.ResponseStream {
    /// Iterates over all responses and returns the command’s `TaggedResponse` on completion.
    public func forEach(
        isolation: isolated (any Actor)? = #isolation,
        _ closure: (AsyncIterator.Element) async throws -> Void
    ) async throws -> TaggedResponse {
        var t: TaggedResponse?
        for try await r in self {
            if case .tagged(let tagged) = r {
                t = tagged
            }
            try await closure(r)
        }
        guard
            let t
        else {
            struct NoTaggedResponse: Swift.Error {}
            throw NoTaggedResponse()
        }
        return t
    }

    /// Waits for the command to complete, discarding intermediate responses.
    public func waitForCompletion(
        isolation: isolated (any Actor)? = #isolation
    ) async throws -> TaggedResponse {
        try await forEach { _ in }
    }
}

// MARK: - Mark as Closed

extension IMAPConnection.State {
    mutating func markAsClosed(reason: IMAPConnection.CloseReason) -> CloseAction {
        return CloseAction(
            perCommandResponseStreams: perCommandResponseStreams.markAsClosed(reason: reason),
            greeting: greeting.markAsClosed(reason: reason)
        )
    }

    struct CloseAction {
        var perCommandResponseStreams: IMAPConnection.PerCommandResponseStream.CloseAction
        var greeting: GreetingState.StoreAction

        func run(logger: Logger) {
            perCommandResponseStreams.run(logger: logger)
            greeting.run()
        }
    }
}

// MARK: - Per Command Response Stream

extension IMAPConnection {
    enum PerCommandResponseStream {
        case streams(Tag, [Tag: AsyncThrowingStream<Response, any Swift.Error>.Continuation])
        /// The connection is gone. Anything that interacts with it fails with this error.
        case connectionClosed(any Swift.Error)

        init() {
            self = .streams(Tag.first, [:])
        }
    }
}

extension IMAPConnection.PerCommandResponseStream {
    mutating func makeTagAndResponseStream() -> Result<
        (IMAPConnection.Tag, AsyncThrowingStream<Response, any Swift.Error>), any Swift.Error
    > {
        switch self {
        case .streams(var nextTag, var continuations):
            let tag = nextTag
            nextTag = tag.makeNext()

            let (stream, continuation) = AsyncThrowingStream<Response, any Swift.Error>.makeStream(of: Response.self)

            // Copy-on-write exclusivity dance: assigning the payload-free
            // `.connectionClosed` case first drops `self`'s reference to
            // `continuations`, so the dictionary is uniquely referenced when we insert
            // into it below and no copy-on-write copy is made. We immediately restore
            // the real `.streams` state.
            self = .connectionClosed(ConnectionClosed())
            continuations[tag] = continuation
            self = .streams(nextTag, continuations)
            return .success((tag, stream))

        case .connectionClosed(let error):
            return .failure(error)
        }
    }

    var allContinuations: [IMAPConnection.Tag: AsyncThrowingStream<Response, any Swift.Error>.Continuation].Values {
        switch self {
        case .streams(_, let c): c.values
        case .connectionClosed: [:].values
        }
    }

    mutating func popCompletedCommand(
        response: TaggedResponse
    ) -> PopAction {
        switch self {
        case .streams(let nextTag, var continuations):
            guard
                let tag = IMAPConnection.Tag(response.tag),
                let continuation = continuations.removeValue(forKey: tag)
            else { return .unknownTag(response.tag) }
            self = .streams(nextTag, continuations)
            return .finishContinuation(continuation, response)
        case .connectionClosed:
            return .none
        }
    }

    enum PopAction {
        case none
        case unknownTag(String)
        case finishContinuation(AsyncThrowingStream<Response, any Swift.Error>.Continuation, TaggedResponse)

        func run() throws {
            switch self {
            case .none:
                break
            case .unknownTag(let tag):
                throw UnknownTag(tag: tag)
            case .finishContinuation(let c, let response):
                c.yield(with: .success(.tagged(response)))
                c.finish()
            }
        }
    }

    mutating func markAsClosed(reason: IMAPConnection.CloseReason) -> CloseAction {
        // Keep the error the connection first failed with: a later, orderly close must not
        // overwrite the reason the caller is waiting to hear about.
        switch self {
        case .streams(_, let continuations):
            let error = reason.error ?? ConnectionClosed()
            self = .connectionClosed(error)
            return .finishContinuations(continuations, error)
        case .connectionClosed:
            return .none
        }
    }

    enum CloseAction {
        case none
        case finishContinuations(
            [IMAPConnection.Tag: AsyncThrowingStream<Response, any Swift.Error>.Continuation],
            any Swift.Error
        )

        func run(logger: Logger) {
            switch self {
            case .none:
                break
            case .finishContinuations(let continuations, let error):
                for (tag, c) in continuations {
                    logger.debug("Command was still running when connection was closed", metadata: ["tag": "\(tag)"])
                    c.yield(with: .failure(error))
                    c.finish()
                }
            }
        }
    }

    struct ConnectionClosed: Swift.Error {}
    struct UnknownTag: Swift.Error {
        var tag: String
    }
}

// MARK: - Greeting

extension IMAPConnection {
    /// The server's initial greeting received when the connection opens.
    public struct Greeting: Hashable, Sendable {
        public var status: UntaggedStatus

        public init(
            status: UntaggedStatus
        ) {
            self.status = status
        }
    }

    private func didReceive(greeting: Greeting) {
        state.withLock { state in
            state.greeting.store(greeting)
        }.run()
    }

    var greeting: IMAPConnection.Greeting {
        get async throws {
            try await withCheckedThrowingContinuation { c in
                state.withLock { state in
                    state.greeting.get(continuation: c)
                }.run()
            }
        }
    }
}

extension IMAPConnection.State {
    enum GreetingState: Sendable {
        case greeting(IMAPConnection.Greeting)
        case waiting([CheckedContinuation<IMAPConnection.Greeting, any Swift.Error>])
        /// The connection is gone. Anything waiting for the greeting fails with this error.
        case connectionClosed(any Swift.Error)
    }
}

extension IMAPConnection.State.GreetingState {
    mutating func store(_ new: IMAPConnection.Greeting) -> StoreAction {
        switch self {
        case .greeting:
            return .none
        case .waiting(let waiting):
            self = .greeting(new)
            return .resume(waiting, new)
        case .connectionClosed:
            // The connection is already gone: keep the failure, don't resurrect the state.
            return .none
        }
    }

    enum StoreAction: Sendable {
        case none
        case resume([CheckedContinuation<IMAPConnection.Greeting, any Swift.Error>], IMAPConnection.Greeting)
        case fail([CheckedContinuation<IMAPConnection.Greeting, any Swift.Error>], any Swift.Error)

        func run() {
            switch self {
            case .none:
                break
            case .resume(let continuations, let result):
                for c in continuations {
                    c.resume(returning: result)
                }
            case .fail(let continuations, let error):
                for c in continuations {
                    c.resume(throwing: error)
                }
            }
        }
    }

    mutating func markAsClosed(reason: IMAPConnection.CloseReason) -> StoreAction {
        switch self {
        case .greeting:
            // The greeting arrived; nothing is waiting and later commands report the closure.
            return .none
        case .waiting(let waiting):
            let error = reason.error ?? ConnectionClosedWhileWaitingForGreeting()
            self = .connectionClosed(error)
            return .fail(waiting, error)
        case .connectionClosed:
            // Keep the error the connection first failed with.
            return .none
        }
    }

    mutating func get(
        continuation: CheckedContinuation<IMAPConnection.Greeting, any Swift.Error>
    ) -> GetAction {
        switch self {
        case .greeting(let g):
            return .resume(continuation, g)
        case .waiting(var w):
            w.append(continuation)
            self = .waiting(w)
            return .none
        case .connectionClosed(let error):
            return .fail(continuation, error)
        }
    }

    enum GetAction: Sendable {
        case none
        case resume(CheckedContinuation<IMAPConnection.Greeting, any Swift.Error>, IMAPConnection.Greeting)
        case fail(CheckedContinuation<IMAPConnection.Greeting, any Swift.Error>, any Swift.Error)

        func run() {
            switch self {
            case .none:
                break
            case .resume(let continuation, let result):
                continuation.resume(returning: result)
            case .fail(let continuation, let error):
                continuation.resume(throwing: error)
            }
        }
    }

    struct ConnectionClosedWhileWaitingForGreeting: Swift.Error {}
}
