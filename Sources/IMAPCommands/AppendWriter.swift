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
    /// Create an append writer using ``IMAPConnection/append(to:writeClosure:readClosure:)``.
    public struct AppendWriter: ~Copyable, Sendable {
        var underlying: OutboundQueue.AppendQueueWriter

        fileprivate init(
            underlying: consuming OutboundQueue.AppendQueueWriter
        ) {
            self.underlying = underlying
        }

        static func withAppendWriter<R>(
            tag: String,
            appendingTo mailbox: MailboxName,
            underlying: consuming OutboundQueue.AppendQueueWriter,
            closure: (inout AppendWriter) async throws -> R
        ) async throws -> R {
            try await underlying.write([.start(tag: tag, appendingTo: mailbox)])
            var writer = AppendWriter(underlying: underlying)
            let r = try await closure(&writer)
            try await writer.finish()
            return r
        }

        fileprivate func finish() async throws {
            try await underlying.write([.finish])
        }
    }
}

extension IMAPConnection.AppendWriter {
    /// Writes a message to be appended.
    ///
    /// The byte count in `message` must match the number of bytes written in the closure.
    /// A mismatch closes the connection.
    public mutating func write(
        message: AppendMessage,
        closure: (inout MessageWriter) async throws -> Void
    ) async throws {
        try await underlying.write([.beginMessage(message: message)])
        var w = MessageWriter(underlying: self.underlying)
        do {
            try await closure(&w)
            self = Self(underlying: w.underlying)
        } catch {
            self = Self(underlying: w.underlying)
            throw error
        }
        try await underlying.write([.endMessage])
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
    /// Writes a message to be appended.
    ///
    /// The byte count in `message` must match the number of bytes written in the closure.
    /// A mismatch closes the connection.
    public mutating func catenate(
        options: AppendOptions,
        closure: (borrowing CatenateWriter) async throws -> Void
    ) async throws {
        try await underlying.write([.beginCatenate(options: options)])
        let w = CatenateWriter(underlying: self.underlying)
        do {
            try await closure(w)
            self = Self(underlying: w.underlying)
        } catch {
            self = Self(underlying: w.underlying)
            throw error
        }
        try await underlying.write([.endCatenate])
    }

    public struct CatenateWriter: ~Copyable, Sendable {
        var underlying: OutboundQueue.AppendQueueWriter

        public mutating func writeURL(
            _ bytes: ByteBuffer
        ) async throws {
            try await underlying.write([.catenateURL(bytes)])
        }

        public mutating func writeData(
            byteCount: Int,
            closure: (borrowing CatenateDataWriter) async throws -> Void
        ) async throws {
            try await underlying.write([.catenateData(.begin(size: byteCount))])
            let w = CatenateDataWriter(underlying: self.underlying)
            do {
                try await closure(w)
                self = CatenateWriter(underlying: w.underlying)
            } catch {
                self = CatenateWriter(underlying: w.underlying)
                throw error
            }
            try await underlying.write([.catenateData(.end)])
        }
    }

    public struct CatenateDataWriter: ~Copyable, Sendable {
        var underlying: OutboundQueue.AppendQueueWriter

        public mutating func write(
            _ bytes: ByteBuffer
        ) async throws {
            try await underlying.write([.catenateData(.bytes(bytes))])
        }
    }
}
