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

/// Untagged status responses from the server.
///
/// The base protocol (RFC 3501) defines four untagged status response types that servers can send
/// at any time to indicate conditions or provide greetings. Unlike tagged responses, untagged responses
/// do not include a command tag and are not directly correlated with specific commands. See [RFC 3501 Section 7.1](https://datatracker.ietf.org/doc/html/rfc3501#section-7.1)
/// for details.
///
/// ### Examples
///
/// ```
/// S: * OK [CAPABILITY IMAP4rev1 STARTTLS] server ready
/// S: * NO [ALERT] Disk full
/// S: * PREAUTH [CAPABILITY IMAP4rev1] already authenticated
/// S: * BYE [UNAVAILABLE] Server shutting down
/// ```
///
/// The first line is wrapped as ``ok(_:)`` with server capabilities and a ready message.
/// The second is ``no(_:)`` with an alert code and warning message.
/// The third is ``preauth(_:)`` indicating the connection is already authenticated.
/// The fourth is ``bye(_:)`` indicating the server is closing the connection.
///
/// - SeeAlso: ``ResponseText``, [RFC 3501 Section 7.1](https://datatracker.ietf.org/doc/html/rfc3501#section-7.1)
public enum UntaggedStatus: Hashable, Sendable {
    /// Indicates a success condition.
    ///
    /// An untagged OK indicates a server condition that is not an error. When used as a greeting
    /// (before any command is issued), it indicates the server is ready to accept commands.
    /// When returned during command processing, it provides informational status that is not
    /// associated with a specific command.
    ///
    /// ### Example
    ///
    /// ```
    /// S: * OK [CAPABILITY IMAP4rev1 STARTTLS LOGIN] server ready
    /// ```
    ///
    /// This line is wrapped as ``ok(_:)`` with a ``ResponseText`` containing the server's capabilities
    /// and a ready message. This is typically the first response received after connecting.
    ///
    /// - SeeAlso: [RFC 3501 Section 7.1.2.1](https://datatracker.ietf.org/doc/html/rfc3501#section-7.1.2.1)
    case ok(ResponseText)

    /// Indicates an operational warning or rejection that does not require protocol-level intervention.
    ///
    /// When tagged, a NO status indicates unsuccessful completion of the associated command.
    /// The untagged form indicates a warning; the current or a later command may still complete
    /// successfully. The human-readable text describes the condition, and a response code may
    /// provide additional details.
    ///
    /// ### Example
    ///
    /// ```
    /// S: * NO [ALERT] Server disk is low on space
    /// ```
    ///
    /// This line is wrapped as ``no(_:)`` with a ``ResponseText`` containing code
    /// ``ResponseTextCode/alert`` and warning text about disk space.
    ///
    /// - SeeAlso: [RFC 3501 Section 7.1.2.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.1.2.2)
    case no(ResponseText)

    /// Indicates a protocol-level error.
    ///
    /// The `BAD` response indicates an error message from the server. When tagged, it reports a
    /// protocol-level error in the client's command; the tag indicates the command that caused the
    /// error. The untagged form indicates a protocol-level error for which the associated command
    /// cannot be determined; it can also indicate an internal server failure. After a `BAD` response,
    /// the connection may be in an undefined state.
    ///
    /// ### Example
    ///
    /// ```
    /// S: * BAD Unexpected character in message sequence
    /// ```
    ///
    /// This line is wrapped as ``bad(_:)`` with a ``ResponseText`` describing the protocol error.
    ///
    /// - SeeAlso: [RFC 3501 Section 7.1.2.3](https://datatracker.ietf.org/doc/html/rfc3501#section-7.1.2.3)
    case bad(ResponseText)

    /// Indicates that the connection has already been authenticated by external means.
    ///
    /// The `PREAUTH` response is always untagged and is one of three possible greetings at connection
    /// startup (along with `OK` and `BYE`). It indicates that the connection has already been
    /// authenticated through external means (e.g., TLS client certificate verification), so no
    /// `LOGIN` command is needed. After `PREAUTH`, the client is in the authenticated state and can
    /// access mailboxes.
    ///
    /// ### Example
    ///
    /// ```
    /// S: * PREAUTH [CAPABILITY IMAP4rev1 SELECT CREATE] already authenticated
    /// ```
    ///
    /// This line is wrapped as ``preauth(_:)`` with a ``ResponseText`` indicating the client is
    /// already authenticated and listing available capabilities.
    ///
    /// - SeeAlso: [RFC 3501 Section 7.1.2.4](https://datatracker.ietf.org/doc/html/rfc3501#section-7.1.2.4)
    case preauth(ResponseText)

    /// Indicates that the server is about to close the connection.
    ///
    /// The `BYE` response is always untagged and indicates that the server is about to close the
    /// connection. This may be sent by the server as a closing greeting, or to inform the client
    /// of an unexpected shutdown. After receiving `BYE`, the client should close the connection.
    /// The server may provide a human-readable explanation in the response text.
    ///
    /// ### Example
    ///
    /// ```
    /// S: * BYE [UNAVAILABLE] Server maintenance in progress, please reconnect later
    /// ```
    ///
    /// This line is wrapped as ``bye(_:)`` with a ``ResponseText`` containing code
    /// ``ResponseTextCode/unavailable`` and an explanation of why the connection is closing.
    ///
    /// - SeeAlso: [RFC 3501 Section 7.1.2.5](https://datatracker.ietf.org/doc/html/rfc3501#section-7.1.2.5)
    case bye(ResponseText)

    init?(code: String, responseText: ResponseText) {
        switch code.lowercased() {
        case "ok": self = .ok(responseText)
        case "no": self = .no(responseText)
        case "bad": self = .bad(responseText)
        case "preauth": self = .preauth(responseText)
        case "bye": self = .bye(responseText)
        default: return nil
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeUntaggedStatus(_ cond: UntaggedStatus) -> Int {
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
        case .preauth(let text):
            return
                self.writeString("PREAUTH ") + self.writeResponseText(text)
        case .bye(let text):
            return
                self.writeString("BYE ") + self.writeResponseText(text)
        }
    }
}
