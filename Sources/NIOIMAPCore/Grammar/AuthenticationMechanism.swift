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
/// ## Names
///
/// A mechanism name is 1 to 20 characters long, and contains only ASCII letters, digits, `-` and
/// `_`, as required by
/// [RFC 4422 section 3.1](https://datatracker.ietf.org/doc/html/rfc4422#section-3.1). ``init(_:)``
/// rejects anything else, which guarantees that a mechanism can always be encoded as a single
/// IMAP atom.
///
/// - SeeAlso: [RFC 3501 Section 6.2.2](https://datatracker.ietf.org/doc/html/rfc3501#section-6.2.2)
/// - SeeAlso: [RFC 4422 Section 3.1](https://datatracker.ietf.org/doc/html/rfc4422#section-3.1)
/// - SeeAlso: [RFC 4616 PLAIN Authentication](https://datatracker.ietf.org/doc/html/rfc4616)
/// - SeeAlso: [RFC 4752 GSSAPI Authentication](https://datatracker.ietf.org/doc/html/rfc4752)
public struct AuthenticationMechanism: Hashable, Sendable {
    fileprivate let rawValue: String

    /// Creates a new authentication mechanism from a string, if the string is a valid mechanism name.
    ///
    /// The provided value is uppercased for consistency with IMAP protocol conventions, and is then
    /// checked against the rules that
    /// [RFC 4422 section 3.1](https://datatracker.ietf.org/doc/html/rfc4422#section-3.1) sets for
    /// mechanism names: 1 to 20 characters of ASCII letter, digit, `-` or `_`. Lowercase input is
    /// accepted, because it is uppercased before being checked.
    ///
    /// - parameter value: The mechanism name (for example, PLAIN or GSSAPI).
    /// - returns: A new mechanism, or `nil` if `value` is not a valid mechanism name.
    public init?(_ value: String) {
        let name = value.uppercased()
        guard Self.isValidName(name) else { return nil }
        self.rawValue = name
    }

    fileprivate init(unchecked: String) {
        assert(Self.isValidName(unchecked))
        self.rawValue = unchecked
    }
}

extension AuthenticationMechanism {
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
}

extension AuthenticationMechanism {
    /// The greatest number of characters a mechanism name may contain.
    private static let maximumNameLength = 20

    /// Whether the given name satisfies
    /// [RFC 4422 section 3.1](https://datatracker.ietf.org/doc/html/rfc4422#section-3.1).
    ///
    /// The name is expected to be uppercased already.
    private static func isValidName(_ name: String) -> Bool {
        (1...maximumNameLength).contains(name.utf8.count)
            && name.utf8.allSatisfy {
                $0.isAlphaNum || ($0 == UInt8(ascii: "-")) || ($0 == UInt8(ascii: "_"))
            }
    }
}

extension String {
    /// Creates a `String` from an ``AuthenticationMechanism``.
    ///
    /// - parameter other: The authentication mechanism to convert.
    public init(_ other: AuthenticationMechanism) {
        self = other.rawValue
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeAuthenticationMechanism(_ mechanism: AuthenticationMechanism) -> Int {
        self.writeString(mechanism.rawValue)
    }
}
