//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2021 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// An authentication mechanism supported by the server for the `AUTHENTICATE` command.
///
/// The `AUTHENTICATE` command allows clients to use SASL (Simple Authentication and Security Layer)
/// mechanisms to authenticate. Each mechanism defines how credentials are formatted and transmitted.
/// The server advertises supported mechanisms via `AUTH=` capabilities.
///
/// ### Example
///
/// ```
/// S: * CAPABILITY IMAP4rev1 AUTH=PLAIN AUTH=GSSAPI
/// C: A001 AUTHENTICATE PLAIN
/// S: +
/// C: dXNlcm5hbWVAZXhhbXBsZS5jb206cGFzc3dvcmQ=
/// S: A001 OK authenticated
/// ```
///
/// The server advertises `AUTH=PLAIN` and `AUTH=GSSAPI` capabilities. The client chooses `PLAIN` mechanism,
/// and sends base64-encoded credentials in response to the server challenge.
///
/// - SeeAlso: [RFC 3501 Section 6.2.2](https://datatracker.ietf.org/doc/html/rfc3501#section-6.2.2)
/// - SeeAlso: [RFC 4616 PLAIN Authentication](https://datatracker.ietf.org/doc/html/rfc4616)
/// - SeeAlso: [RFC 4752 GSSAPI Authentication](https://datatracker.ietf.org/doc/html/rfc4752)
public struct AuthenticationMechanism: Hashable, Sendable {
    /// `TOKEN` mechanism - generates authentication tokens via algorithm.
    public static let token = Self(unchecked: "TOKEN")

    /// `PLAIN` mechanism - encodes username and password in base64 (RFC 4616).
    public static let plain = Self(unchecked: "PLAIN")

    /// `PTOKEN` mechanism - proprietary token mechanism.
    public static let pToken = Self(unchecked: "PTOKEN")

    /// `WETOKEN` mechanism - Windowed Encrypted Token mechanism.
    public static let weToken = Self(unchecked: "WETOKEN")

    /// `WSTOKEN` mechanism - Windowed Signed Token mechanism.
    public static let wsToken = Self(unchecked: "WSTOKEN")

    /// `GSSAPI` mechanism - uses Generic Security Service API (RFC 4752).
    public static let gssAPI = Self(unchecked: "GSSAPI")

    /// The mechanism name.
    public let rawValue: String

    /// Creates a new authentication mechanism from a string.
    ///
    /// The provided value is uppercased for consistency with IMAP protocol conventions.
    ///
    /// - parameter value: The mechanism name (for example, PLAIN or GSSAPI).
    public init(_ value: String) {
        self.rawValue = value.uppercased()
    }

    fileprivate init(unchecked: String) {
        self.rawValue = unchecked
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeAuthenticationMechanism(_ mechanism: AuthenticationMechanism) -> Int {
        self.writeString(mechanism.rawValue)
    }
}
