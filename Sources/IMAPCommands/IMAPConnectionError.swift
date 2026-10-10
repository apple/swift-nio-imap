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

import NIOIMAP

extension IMAPConnection {
    /// An error the connection throws on its own behalf.
    ///
    /// Everything a command can fail with falls into one of three groups, and only this one is
    /// an `IMAPConnection.Error`:
    ///
    /// - The *connection* failed — it could not be opened, the channel broke, a response could
    ///   not be parsed, or it was closed while a command was still running. That is this type.
    /// - The *server* refused the command with a `NO` or `BAD` tagged response. That is not an
    ///   error: it arrives as a `TaggedResponse`, and only becomes one —
    ///   ``TaggedResponse/StateNotOK`` — if you ask for it with `checkOK()` or `getOK()`.
    /// - *Your own* handler closure threw. ``IMAPConnection/send(_:_:)`` and its siblings
    ///   rethrow that error unchanged; they never wrap it in this type.
    public enum Error: Swift.Error, Sendable {
        /// The connection was closed in an orderly fashion before the operation completed.
        ///
        /// Either the ``IMAPConnection/withConnection(configuration:_:)`` closure returned, or
        /// the server sent EOF.
        case connectionClosed

        /// The connection failed.
        ///
        /// The associated value is what caused the failure — a `NIOCore`, `NIOSSL`, or
        /// `NIOIMAPCore` error, depending on whether the connection could not be opened, the
        /// TLS handshake failed, the channel broke, or a response could not be parsed. The set
        /// of errors that can appear here is open, which is why it is carried as `any Error`
        /// rather than enumerated.
        case connectionFailed(any Swift.Error)

        /// The server's first response was something other than a greeting.
        case unexpectedGreeting(Response)

        /// The command's response stream ended without the `TaggedResponse` that completes it.
        case missingTaggedResponse

        /// The server sent a tagged response for a tag that no in-flight command owns.
        ///
        /// The associated value is the tag the server used.
        case unknownTag(String)
    }
}

extension IMAPConnection.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .connectionClosed:
            "The connection was closed."
        case .connectionFailed(let underlying):
            "The connection failed: \(underlying)"
        case .unexpectedGreeting(let response):
            "The server sent \(response) instead of a greeting."
        case .missingTaggedResponse:
            "The command ended without a tagged response."
        case .unknownTag(let tag):
            "The server sent a response for the unknown tag '\(tag)'."
        }
    }
}

extension IMAPConnection.Error {
    /// Maps the plumbing's errors — which a caller cannot name — onto this one.
    init(wrapping error: any Swift.Error) {
        if let error = error as? IMAPConnection.Error {
            self = error
            return
        }
        if error is CommandStreamPartQueue.DidClose {
            self = .connectionClosed
            return
        }
        if let error = error as? OutboundQueue.Error, case .inFailedState = error {
            self = .connectionClosed
            return
        }
        self = .connectionFailed(error)
    }
}
