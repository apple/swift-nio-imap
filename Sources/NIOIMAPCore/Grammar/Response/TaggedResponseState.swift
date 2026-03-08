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

extension TaggedResponse {
    /// The outcome status of a tagged response.
    ///
    /// Tagged responses use one of three status codes to indicate the outcome of command execution:
    /// OK (success), NO (rejection with reason), or BAD (protocol error). Each case includes
    /// a ``ResponseText`` containing optional structured status codes and human-readable text.
    /// See [RFC 3501 Section 7.1](https://datatracker.ietf.org/doc/html/rfc3501#section-7.1) for details.
    ///
    /// ### Examples
    ///
    /// ```
    /// S: A001 OK CAPABILITY completed
    /// S: A002 NO [CANNOT] Mailbox does not exist
    /// S: A003 BAD Invalid syntax
    /// ```
    ///
    /// The first line is wrapped as ``State/ok(_:)`` with a ``ResponseText`` containing the text
    /// "CAPABILITY completed". The second line is ``State/no(_:)`` with a ``ResponseText`` containing
    /// code ``ResponseTextCode/cannot`` and text "Mailbox does not exist". The third line is
    /// ``State/bad(_:)`` with a ``ResponseText`` containing the text "Invalid syntax".
    ///
    /// - SeeAlso: ``ResponseText``, ``ResponseTextCode``, [RFC 3501 Section 7.1](https://datatracker.ietf.org/doc/html/rfc3501#section-7.1)
    public enum State: Hashable, Sendable {
        /// The command executed successfully.
        ///
        /// An OK status indicates the server has completed the command without error. The associated
        /// ``ResponseText`` may contain optional status codes (e.g., ``ResponseTextCode/uidNext(_:)``)
        /// with additional information about the command result. This is the expected outcome for most
        /// successful commands.
        ///
        /// ### Example
        ///
        /// ```
        /// S: A001 OK [UIDVALIDITY 3] SELECT completed
        /// ```
        ///
        /// This line is wrapped as ``State/ok(_:)`` with a ``ResponseText`` containing code
        /// ``ResponseTextCode/uidValidity(_:)`` and text "SELECT completed".
        ///
        /// - SeeAlso: [RFC 3501 Section 7.1.2.1](https://datatracker.ietf.org/doc/html/rfc3501#section-7.1.2.1)
        case ok(ResponseText)

        /// The command was valid, but the server rejected it.
        ///
        /// A NO status indicates the server understood the command syntax but declined to execute it
        /// for logical or protocol reasons. The associated ``ResponseText`` often includes a structured
        /// status code (e.g., ``ResponseTextCode/cannot``, ``ResponseTextCode/tryCreate``, or
        /// ``ResponseTextCode/overQuota``) explaining the reason for rejection. This is not a protocol
        /// error; the client may retry with different parameters.
        ///
        /// ### Example
        ///
        /// ```
        /// S: A002 NO [TRYCREATE] APPEND failed - mailbox does not exist
        /// ```
        ///
        /// This line is wrapped as ``State/no(_:)`` with a ``ResponseText`` containing code
        /// ``ResponseTextCode/tryCreate`` and text "APPEND failed - mailbox does not exist".
        ///
        /// - SeeAlso: [RFC 3501 Section 7.1.2.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.1.2.2)
        case no(ResponseText)

        /// The command was invalid or the server encountered a protocol error.
        ///
        /// A BAD status indicates the server could not parse the command or encountered a serious
        /// error processing it. This typically means the client sent syntactically incorrect data
        /// or the server experienced an unexpected condition. After a BAD response, the connection
        /// may be in an undefined state, and the client should consider reconnecting.
        ///
        /// ### Example
        ///
        /// ```
        /// S: A003 BAD Invalid command syntax
        /// ```
        ///
        /// This line is wrapped as ``State/bad(_:)`` with a ``ResponseText`` containing text
        /// "Invalid command syntax".
        ///
        /// - SeeAlso: [RFC 3501 Section 7.1.2.3](https://datatracker.ietf.org/doc/html/rfc3501#section-7.1.2.3)
        case bad(ResponseText)

        init?(code: String, responseText: ResponseText) {
            switch code.lowercased() {
            case "ok": self = .ok(responseText)
            case "no": self = .no(responseText)
            case "bad": self = .bad(responseText)
            default: return nil
            }
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeTaggedResponseState(_ cond: TaggedResponse.State) -> Int {
        switch cond {
        case .ok(let text):
            return
                self.writeString("OK ") + self.writeResponseText(text)
        case .no(let text):
            return
                self.writeString("NO ") + self.writeResponseText(text)
        case .bad(let text):
            return
                self.writeString("BAD ") + self.writeResponseText(text)
        }
    }
}
