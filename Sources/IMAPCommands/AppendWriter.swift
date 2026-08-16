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

import NIO
import NIOIMAP

extension IMAPConnection {
    /// Writes message data to the server as part of an `APPEND` command.
    ///
    /// Create an append writer using ``IMAPConnection/append(to:writing:reading:)`` or
    /// ``IMAPConnection/append(to:_:)``.
    public struct AppendWriter: ~Copyable, Sendable {
        var underlying: OutboundQueue.AppendQueueWriter
        var state: State

        /// Tracks how far along the `APPEND` command is.
        ///
        /// Only some sequences of append data are valid IMAP, and the writer must not emit an
        /// invalid one — the client state machine treats that as a programming error and traps.
        enum State: Hashable {
            /// Nothing written yet: `APPEND` needs at least one message.
            case empty
            /// At least one complete message, and no partial one: the command can be finished.
            case complete
            /// A message was begun but never completed. Nothing more can be written, and the
            /// command cannot be finished.
            case incomplete
            /// The command has been written in full. Nothing more can be written, and the
            /// server's `TaggedResponse` can now arrive.
            case finished
        }

        fileprivate init(
            underlying: consuming OutboundQueue.AppendQueueWriter,
            state: State
        ) {
            self.underlying = underlying
            self.state = state
        }

        static func withAppendWriter<R>(
            tag: String,
            appendingTo mailbox: MailboxName,
            underlying: consuming OutboundQueue.AppendQueueWriter,
            didCompleteCommand: inout Bool,
            closure: nonisolated(nonsending) (inout AppendWriter) async throws -> R
        ) async throws -> R {
            try await underlying.write([.start(tag: tag, appendingTo: mailbox)])
            var writer = AppendWriter(underlying: underlying, state: .empty)
            do {
                let r = try await closure(&writer)
                // Completing the command is idempotent, so this is a no-op if the closure
                // already did it in order to read the command's responses.
                try await writer.finish()
                didCompleteCommand = true
                return r
            } catch {
                // Report whether the command made it out in full: if it didn't, the server is
                // left waiting for the rest of it and the connection cannot be reused.
                didCompleteCommand = (writer.state == .finished)
                throw error
            }
        }

        /// Completes the `APPEND` command.
        ///
        /// The server only sends the command's `TaggedResponse` once the command has been
        /// written in full, so call this before waiting for the command to complete:
        ///
        /// ```swift
        /// try await connection.append(to: mailbox) { tag, responses, writer in
        ///     try await writer.write(message: message) { messageWriter in
        ///         try await messageWriter.write(messageBytes: bytes)
        ///     }
        ///     try await writer.finish()
        ///     return try await responses.waitForCompletion()
        /// }
        /// ```
        ///
        /// Calling this is optional and idempotent: ``IMAPConnection/append(to:_:)``
        /// completes the command when its closure returns.
        ///
        /// - Throws: ``IMAPConnection/IncompleteAppend`` if no message was written, or if a
        ///   message was begun but never finished. Neither can be completed.
        /// - Important: The command is over once this returns, so writing any further message
        ///   throws ``IMAPConnection/AppendAlreadyFinished``. Write everything you mean to append
        ///   before finishing.
        public mutating func finish() async throws {
            guard
                state != .finished
            else { return }
            try state.checkIsComplete()
            try await underlying.write([.finish])
            state = .finished
        }
    }

    /// An error indicating that an `APPEND` command cannot be completed.
    ///
    /// The partially written command cannot be taken back, so the connection is closed.
    public struct IncompleteAppend: Swift.Error, Hashable, Sendable {
        /// Why the command cannot be completed.
        public enum Reason: Hashable, Sendable {
            /// No message was written. `APPEND` requires at least one message — or one
            /// catenated message.
            case noMessage
            /// A message was begun but never completed, typically because writing it failed
            /// and the error was not propagated.
            case unfinishedMessage
        }

        public var reason: Reason

        public init(reason: Reason) {
            self.reason = reason
        }
    }

    /// An error indicating that append data was written after the `APPEND` command was
    /// completed by ``AppendWriter/finish()``.
    public struct AppendAlreadyFinished: Swift.Error, Hashable, Sendable {
        public init() {}
    }
}

extension IMAPConnection.AppendWriter.State {
    /// Throws if the command is in a state that nothing more can be written in.
    func checkCanWrite() throws {
        switch self {
        case .empty, .complete:
            break
        case .incomplete:
            throw IMAPConnection.IncompleteAppend(reason: .unfinishedMessage)
        case .finished:
            throw IMAPConnection.AppendAlreadyFinished()
        }
    }

    /// Throws unless at least one complete message has been written.
    func checkIsComplete() throws {
        switch self {
        case .complete, .finished:
            break
        case .empty:
            throw IMAPConnection.IncompleteAppend(reason: .noMessage)
        case .incomplete:
            throw IMAPConnection.IncompleteAppend(reason: .unfinishedMessage)
        }
    }
}

extension IMAPConnection.AppendWriter {
    /// Writes a message to be appended.
    ///
    /// The closure must write exactly as many bytes as the `byteCount` of `message`'s
    /// `AppendData` declares: that count goes out ahead of the data as the literal's length,
    /// and the server reads precisely that many bytes as the message. Writing a different number
    /// desynchronizes the command stream, leaving the connection unusable.
    ///
    /// If the closure throws, the message — and with it the whole `APPEND` command — is left
    /// unfinished: nothing more can be written, and the command cannot be completed. Even if
    /// the error is caught, `append` then throws ``IMAPConnection/IncompleteAppend`` and closes
    /// the connection.
    public mutating func write(
        message: AppendMessage,
        closure: nonisolated(nonsending) (inout MessageWriter) async throws -> Void
    ) async throws {
        try state.checkCanWrite()
        try await underlying.write([.beginMessage(message: message)])
        var w = MessageWriter(underlying: self.underlying)
        do {
            try await closure(&w)
        } catch {
            // The message was begun but not ended, so `self` stays `.incomplete`.
            self = Self(underlying: w.underlying, state: .incomplete)
            throw error
        }
        self = Self(underlying: w.underlying, state: .incomplete)
        try await underlying.write([.endMessage])
        state = .complete
    }

    public struct MessageWriter: ~Copyable, Sendable {
        var underlying: OutboundQueue.AppendQueueWriter

        /// Writes message bytes to the server.
        public mutating func write(messageBytes: ByteBuffer) async throws {
            try await underlying.write([.messageBytes(messageBytes)])
        }
    }
}

extension IMAPConnection.AppendWriter {
    /// Writes a catenated message — assembled from `IMAP URL`s and literal data — to be
    /// appended.
    ///
    /// The closure must add at least one URL or one piece of data. As with
    /// ``write(message:closure:)``, a failure part-way through leaves the `APPEND`
    /// command unfinishable.
    public mutating func catenate(
        options: AppendOptions,
        closure: nonisolated(nonsending) (inout CatenateWriter) async throws -> Void
    ) async throws {
        try state.checkCanWrite()
        try await underlying.write([.beginCatenate(options: options)])
        var w = CatenateWriter(underlying: self.underlying, state: .empty)
        do {
            try await closure(&w)
        } catch {
            self = Self(underlying: w.underlying, state: .incomplete)
            throw error
        }
        let catenateState = w.state
        self = Self(underlying: w.underlying, state: .incomplete)
        try catenateState.checkIsComplete()
        try await underlying.write([.endCatenate])
        state = .complete
    }

    public struct CatenateWriter: ~Copyable, Sendable {
        var underlying: OutboundQueue.AppendQueueWriter
        var state: State

        /// Adds the message the given `IMAP URL` refers to.
        public mutating func writeURL(
            _ bytes: ByteBuffer
        ) async throws {
            try state.checkCanWrite()
            try await underlying.write([.catenateURL(bytes)])
            state = .complete
        }

        /// Adds a message given as literal data.
        ///
        /// The closure must write exactly `byteCount` bytes, for the same reason
        /// ``IMAPConnection/AppendWriter/write(message:closure:)`` requires: the count
        /// goes out ahead of the data as the literal's length. Writing a different number
        /// desynchronizes the command stream, leaving the connection unusable.
        public mutating func writeData(
            byteCount: Int,
            closure: nonisolated(nonsending) (inout CatenateDataWriter) async throws -> Void
        ) async throws {
            try state.checkCanWrite()
            try await underlying.write([.catenateData(.begin(size: byteCount))])
            var w = CatenateDataWriter(underlying: self.underlying)
            do {
                try await closure(&w)
            } catch {
                self = CatenateWriter(underlying: w.underlying, state: .incomplete)
                throw error
            }
            self = CatenateWriter(underlying: w.underlying, state: .incomplete)
            try await underlying.write([.catenateData(.end)])
            state = .complete
        }
    }

    public struct CatenateDataWriter: ~Copyable, Sendable {
        var underlying: OutboundQueue.AppendQueueWriter

        /// Writes message bytes to the server.
        public mutating func write(
            _ bytes: ByteBuffer
        ) async throws {
            try await underlying.write([.catenateData(.bytes(bytes))])
        }
    }
}
