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

import AsyncAlgorithms
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
///   ``send(_:_:)``). Handlers must act only on the responses they care about.
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

    private enum ChildResult<Result: Sendable>: Sendable {
        case run
        case body(Result)
    }

    /// Creates an IMAP connection and runs the given closure.
    ///
    /// The closure can send commands to the connection and receive responses from the server.
    /// Use task groups to pipeline commands concurrently.
    ///
    /// The connection closes when the `body` closure returns.
    public static func withConnection<Result: Sendable>(
        configuration: Configuration,
        _ body: @Sendable @escaping (Greeting, IMAPConnection) async throws -> Result
    ) async throws -> Result {
        let connection = IMAPConnection(configuration: configuration)

        return try await withThrowingTaskGroup(
            of: ChildResult<Result>.self,
            returning: Result.self
        ) { group in

            // Create a task that “runs” the connection receiving inbound and sending commands:
            group.addTask {
                // Run the connection:
                try await connection.run(logging: configuration.logging)
                return ChildResult<Result>.run
            }

            // Create a task that runs the passed in `body` closure:
            group.addTask {
                do {
                    // Wait for the greeting:
                    let greeting = try await connection.greeting
                    // Run the `body` that lets the caller send commands:
                    let result = try await body(greeting, connection)
                    connection.configuration.logger.debug("Closing connection after body completed")
                    connection.close()
                    return ChildResult.body(result)
                } catch {
                    connection.configuration.logger.debug(
                        "Closing connection after body threw",
                        metadata: ["error": "\(error)"]
                    )
                    connection.close()
                    throw error
                }
            }

            var result: ChildResult<Result>?
            for try await task in group {
                if case .body = task {
                    result = task
                }
                group.cancelAll()
            }
            guard
                case .body(let r) = result
            else { throw ConnectionClosedBeforeBodyCompleted() }
            return r
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
    public func send<Result: Sendable>(
        _ command: Command,
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
    public func sendIdle<Result: Sendable>(
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
    public func sendAuthenticate<Result: Sendable>(
        mechanism: AuthenticationMechanism,
        initialResponse: InitialResponse?,
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
            close()
            throw error
        }
    }

    /// Sends an `APPEND` command as a stream to the server.
    /// - Parameters:
    ///   - mailbox: The mailbox to append the message to.
    ///   - writeClosure: Writes message parts using the provided ``AppendWriter``.
    ///   - readClosure: Receives server responses during the append operation.
    public func append<Result: Sendable>(
        to mailbox: MailboxName,
        writeClosure: @Sendable @escaping (inout AppendWriter) async throws -> Void,
        readClosure: @Sendable @escaping (Tag, ResponseStream) async throws -> Result
    ) async throws -> Result {
        let (tag, responseStream) = try state.withLock { state in
            state.perCommandResponseStreams.makeTagAndResponseStream()
        }.get()

        return try await withThrowingTaskGroup(
            of: AppendChildResult<Result>.self,
            returning: Result.self
        ) { [outboundWriter] group in
            group.addTask {
                .read(try await readClosure(tag, ResponseStream(underlying: responseStream)))
            }
            group.addTask {
                try await outboundWriter.withAppendWriter { writer in
                    try await AppendWriter.withAppendWriter(
                        tag: "\(tag)",
                        appendingTo: mailbox,
                        underlying: writer
                    ) { innerWriter in
                        try await writeClosure(&innerWriter)
                    }
                }
                return .write
            }

            // Wait for both children. If either throws, the group rethrows and
            // cancels the other. The read child provides the result.
            var readResult: Result?
            for try await child in group {
                switch child {
                case .read(let r):
                    readResult = r
                case .write:
                    break
                }
            }
            guard let readResult else {
                throw AppendCompletedWithoutReadResult()
            }
            return readResult
        }
    }

    private enum AppendChildResult<Result: Sendable>: Sendable {
        case read(Result)
        case write
    }

    /// An error indicating the `APPEND` operation finished without the read closure producing a result.
    struct AppendCompletedWithoutReadResult: Swift.Error {}
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
        // Ensure any awaiting caller is unblocked no matter how `run()` exits — in
        // particular a task parked on `greeting` when the channel fails to open.
        defer { self.close() }
        try await makeChannel(
            logging: logging
        ).executeThenClose { inbound, outbound in
            let outboundWriter = self.outboundWriter
            try await withThrowingTaskGroup { group in
                group.addTask {
                    // When the inbound stream ends — via a graceful EOF, a read error, or
                    // cancellation — tear the connection down. This finishes any in-flight
                    // command response streams (and any greeting waiter) and closes the
                    // outbound queue so the outbound runner stops, instead of leaving
                    // callers parked forever.
                    defer { self.close() }
                    // Get the greeting:
                    var iterator = inbound.makeAsyncIterator()
                    do {
                        guard
                            let response = try await iterator.next()
                        else { return }
                        guard
                            case .untagged(.conditionalState(let s)) = response
                        else {
                            throw ServerSendOtherResponseBeforeGreeting(response: response)
                        }
                        self.didReceive(greeting: Greeting(status: s))
                    }
                    // Loop through the remaining:
                    do {
                        while let response = try await iterator.next() {
                            switch response {
                            case .tagged(let tagged):
                                try self.commandDidComplete(response: tagged)
                            default:
                                self.didReceive(response: response)
                            }
                        }
                    } catch {
                        self.configuration.logger.debug(
                            "Ignoring inbound read error; closing connection",
                            metadata: ["error": "\(error)"]
                        )
                        // Ignore any read errors; the `defer { self.close() }` above tears
                        // the connection down. The write closures (if any) will observe
                        // the errors from the connection being closed.
                    }
                }
                group.addTask {
                    try await outboundWriter.run(outbound: outbound)
                }

                try await group.waitForAll()
            }
            close()
        }
    }

    /// Mark the state as closed:
    private func close() {
        state.withLock { state in
            state.markAsClosed()
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
    private struct ConnectionClosedBeforeBodyCompleted: Swift.Error {}

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

extension IMAPConnection.ResponseStream {
    /// Iterates over all responses and returns the command’s `TaggedResponse` on completion.
    public func forEach(
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
    public func waitForCompletion() async throws -> TaggedResponse {
        try await forEach { _ in }
    }
}

// MARK: - Mark as Closed

extension IMAPConnection.State {
    mutating func markAsClosed() -> CloseAction {
        return CloseAction(
            perCommandResponseStreams: perCommandResponseStreams.markAsClosed(),
            greeting: greeting.markAsClosed()
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
        case connectionClosed

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
            self = .connectionClosed
            continuations[tag] = continuation
            self = .streams(nextTag, continuations)
            return .success((tag, stream))

        case .connectionClosed:
            return .failure(ConnectionClosed())
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

    mutating func markAsClosed() -> CloseAction {
        let action: CloseAction =
            switch self {
            case .streams(_, let c): .finishContinuations(c)
            case .connectionClosed: .none
            }
        self = .connectionClosed
        return action
    }

    enum CloseAction {
        case none
        case finishContinuations([IMAPConnection.Tag: AsyncThrowingStream<Response, any Swift.Error>.Continuation])

        func run(logger: Logger) {
            switch self {
            case .none:
                break
            case .finishContinuations(let continuations):
                for (tag, c) in continuations {
                    logger.debug("Command was still running when connection was closed", metadata: ["tag": "\(tag)"])
                    c.yield(with: .failure(ConnectionClosed()))
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
        case connectionClosed
    }
}

extension IMAPConnection.State.GreetingState {
    mutating func store(_ new: IMAPConnection.Greeting) -> StoreAction {
        let action: StoreAction =
            switch self {
            case .greeting: .none
            case .waiting(let waiting): .resume(waiting, new)
            case .connectionClosed: .none
            }
        self = .greeting(new)
        return action
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

    mutating func markAsClosed() -> StoreAction {
        let action: StoreAction =
            switch self {
            case .greeting: .none
            case .waiting(let w): .fail(w, ConnectionClosedWhileWaitingForGreeting())
            case .connectionClosed: .none
            }
        self = .connectionClosed
        return action
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
        case .connectionClosed:
            return .fail(continuation, ConnectionClosedWhileWaitingForGreeting())
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
