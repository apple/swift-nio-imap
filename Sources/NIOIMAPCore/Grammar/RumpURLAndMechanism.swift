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

/// An IMAP URL rump and the authentication mechanism used to generate its URLAUTH token.
///
/// In RFC 4467 GENURLAUTH command processing, the client provides a "rump URL" (the URL minus
/// the `:<mechanism>:<token>` portion) and specifies which mechanism should be used to generate
/// the authorization token. The server uses these together to generate and return a complete
/// URLAUTH-authorized URL.
///
/// The rump URL is the complete IMAP URL including expiration and access information, but
/// excluding the mechanism name and verification token. The mechanism name indicates which
/// algorithm the server should use for token generation.
///
/// ### Example
///
/// In a GENURLAUTH command:
/// ```
/// C: a001 GENURLAUTH "imap://user@example.com/INBOX/;uid=20;urlauth=anonymous" INTERNAL
/// S: * GENURLAUTH "imap://user@example.com/INBOX/;uid=20;urlauth=anonymous:internal:TOKEN"
/// ```
///
/// The client sends:
/// - **URL rump**: `imap://user@example.com/INBOX/;uid=20;urlauth=anonymous`
/// - **Mechanism**: `INTERNAL`
///
/// The server generates the token using the INTERNAL mechanism and returns the complete URL
/// with the token appended.
///
/// ## RFC 4467 Context
///
/// According to RFC 4467 Section 5, the GENURLAUTH command accepts "one or more URL/mechanism pairs".
/// Represents one such pair: the rump URL and the corresponding mechanism.
///
/// ## Related types
///
/// - ``URLAuthenticationMechanism`` specifies the token generation algorithm
/// - ``AuthenticatedURLRump`` contains the EXPIRE and ACCESS components
/// - ``AuthenticatedURLVerifier`` pairs mechanism with the generated token
/// - ``AuthenticatedURL`` combines rump and verifier for verification
///
/// - SeeAlso: [RFC 4467 Section 7](https://datatracker.ietf.org/doc/html/rfc4467#section-7) - GENURLAUTH Command
public struct RumpURLAndMechanism: Hashable, Sendable {
    /// The IMAP URL without the mechanism and token components.
    ///
    /// The complete URL including all components except the final `:mechanism:token` portion.
    /// It includes the server, mailbox, UID, optional section, optional byte range, expiration,
    /// and access identifier.
    public var urlRump: ByteBuffer

    /// The authentication mechanism that should be used to generate the URLAUTH token.
    ///
    /// Specifies which algorithm the server should use to calculate the authorization token
    /// for this URL.
    public var mechanism: URLAuthenticationMechanism

    /// Creates a new rump URL and mechanism pair.
    /// - parameter urlRump: The URL rump (without mechanism and token).
    /// - parameter mechanism: The mechanism for token generation.
    public init(urlRump: ByteBuffer, mechanism: URLAuthenticationMechanism) {
        self.urlRump = urlRump
        self.mechanism = mechanism
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeURLRumpMechanism(_ data: RumpURLAndMechanism) -> Int {
        self.writeIMAPString(data.urlRump) + self.writeSpace() + self.writeURLAuthenticationMechanism(data.mechanism)
    }
}
