//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2020 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct NIO.ByteBuffer

/// A tagged response sent by a server to signal that a command has finished processing.
///
/// Every client command receives exactly one tagged response from the server. The response contains
/// the original command tag (to correlate with the sent command), a status code (`OK`, `NO`, or `BAD`),
/// and optional human-readable text with additional information. Tagged responses mark the completion
/// of command processing and may include structured status codes (e.g., `[CANNOT]`, `[TRYCREATE]`)
/// that provide machine-readable details.
/// See [RFC 3501 Section 7.1](https://datatracker.ietf.org/doc/html/rfc3501#section-7.1) for details.
///
/// ### Examples
///
/// ```
/// C: A001 CAPABILITY
/// S: * CAPABILITY IMAP4rev1 STARTTLS LOGIN
/// S: A001 OK CAPABILITY completed
/// ```
///
/// The line `A001 OK CAPABILITY completed` is a tagged response. The tag is `A001`, the state
/// is ``State/ok(_:)``, and the text is `CAPABILITY completed`.
///
/// ```
/// C: A002 SELECT /Nonexistent
/// S: A002 NO [CANNOT] Mailbox does not exist
/// ```
///
/// This tagged response has tag `A002`, state ``State/no(_:)``, and a ``ResponseText`` containing
/// a ``ResponseTextCode/cannot`` code with human-readable text explaining the failure.
///
/// ## Related Types
///
/// - ``Response/tagged(_:)`` - Wraps this type within the ``Response`` enum
/// - ``State`` - Represents the outcome status (OK, NO, or BAD)
/// - ``ResponseText`` - Contains the status code and human-readable message
///
/// - SeeAlso: [RFC 3501 Section 7.1](https://datatracker.ietf.org/doc/html/rfc3501#section-7.1)
public struct TaggedResponse: Hashable, Sendable {
    /// The tag of the command that led to this response.
    ///
    /// This is the same tag that appeared in the original client command, allowing the client
    /// to correlate the response with its request. The tag uniquely identifies the command within
    /// the connection session.
    public var tag: String

    /// The outcome status of the command execution.
    ///
    /// Contains the response state (`OK` for success, `NO` for rejection, or `BAD` for protocol error)
    /// along with a ``ResponseText`` that may include a status code and human-readable message.
    /// See ``State`` for details on each outcome type.
    public var state: State

    /// Creates a new `TaggedResponse`.
    /// - parameter tag: The tag of the command that led to this response.
    /// - parameter state: Signals if the command was successfully executed.
    public init(tag: String, state: State) {
        self.tag = tag
        self.state = state
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeTaggedResponse(_ response: TaggedResponse) -> Int {
        self.writeString("\(response.tag) ") + self.writeTaggedResponseState(response.state) + self.writeString("\r\n")
    }
}
