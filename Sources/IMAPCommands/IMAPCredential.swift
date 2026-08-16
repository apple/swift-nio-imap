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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import NIOIMAP

/// A credential used to authenticate an IMAP connection.
public enum IMAPCredential: Equatable, Sendable {
    case username(String, password: String)
    case sasl(mechanism: AuthenticationMechanism, response: Data)
}

extension IMAPCredential: CustomStringConvertible {
    /// A description with the secret redacted.
    ///
    /// The password (and SASL response) is replaced with a `[N bytes]` placeholder,
    /// matching the _personally identifiable information_ redaction convention used by
    /// `NIOIMAPCore` when encoding commands in logging mode. This keeps credentials
    /// out of logs even when a credential is interpolated into a string.
    public var description: String {
        switch self {
        case .username(let u, password: let p):
            return "\(u):[\(p.utf8.count) bytes]"
        case .sasl(mechanism: let mechanism, response: let response):
            return "SASL \(String(mechanism)) [\(response.count) bytes]"
        }
    }
}

extension IMAPCredential {
    /// Creates a credential by extracting authentication information from URL, SASL, or username text.
    ///
    /// Exactly one of the parameters must be non-`nil`. If a URL is provided, the initializer
    /// extracts the username and password from the URL's user info component.
    public init(
        url urlText: String?,
        sasl saslText: String?,
        username userText: String?
    ) throws {
        // The `urlText` may or may not be an actual URL. That’s ok.
        // Only _if_ it’s a URL, try to get credentials from it.
        // And we also want to support a valid URL without credentials.
        let url = urlText.flatMap { URL(string: $0) }
        switch (url?.user, url?.password, saslText, userText) {
        case (let u?, let p?, nil, nil):
            self = .username(u, password: p)
        case (nil, nil, let s?, nil):
            let name = s.prefix { $0 != ":" }
            let remainder = s[name.endIndex...]
            // `AuthenticationMechanism` normalizes the name to uppercase, and rejects a name that
            // RFC 4422 doesn’t allow — which subsumes checking for an empty name.
            guard
                let mechanism = AuthenticationMechanism(String(name)),
                remainder.first == ":",
                let response = Self.parseSASLResponse(remainder.dropFirst())
            else { throw UnableToParseSASL() }
            self = .sasl(mechanism: mechanism, response: response)
        case (nil, nil, nil, let text?):
            let parts = text.split(separator: ":", omittingEmptySubsequences: false)
            guard
                parts.count == 2,
                !parts[0].isEmpty,
                !parts[1].isEmpty
            else { throw UnableToParseUsernamePassword() }
            self = .username(String(parts[0]), password: String(parts[1]))
        case (nil, nil, nil, nil):
            throw NoCredentials()
        default:
            throw ConflictingCredentials()
        }
    }

    struct UnableToParseSASL: Swift.Error, CustomStringConvertible {
        let description = "Unable to parse SASL input."
    }

    struct UnableToParseURL: Swift.Error, CustomStringConvertible {
        let description = "Unable to parse IMAP URL."
    }

    struct UnableToParseUsernamePassword: Swift.Error, CustomStringConvertible {
        let description = "Unable to parse username + password. Use username:password pattern."
    }

    struct ConflictingCredentials: Swift.Error, CustomStringConvertible {
        let description = "Found multiple (conflicting) credentials."
    }

    struct NoCredentials: Swift.Error, CustomStringConvertible {
        let description = "No credentials specified."
    }
}

// MARK: -

extension IMAPCredential {
    /// Parses the part of the SASL text that follows the `mechanism:` prefix.
    ///
    /// A response that is a single base64 encoded value is decoded as-is. Anything else is
    /// treated as a list of whitespace separated parts, which are joined with a `NUL`
    /// separator — the wire format used by mechanisms such as `PLAIN`.
    ///
    /// Returns `nil` if the text is neither.
    private static func parseSASLResponse(_ text: Substring) -> Data? {
        singleBase64SASLResponse(text) ?? whitespaceSeparatedSASLResponse(text)
    }

    private static func singleBase64SASLResponse(_ text: Substring) -> Data? {
        guard
            !text.isEmpty,
            text.utf8.allSatisfy({ $0.isBase64Byte })
        else { return nil }
        return Data(base64Encoded: String(text))
    }

    private static func whitespaceSeparatedSASLResponse(_ text: Substring) -> Data? {
        // A response must not start with whitespace. An empty response is allowed, and
        // results in an empty (zero byte) response.
        guard !(text.first?.isSASLWhitespace ?? false) else { return nil }
        return
            text
            .split(whereSeparator: { $0.isSASLWhitespace })
            .reduce(into: Data()) {
                if !$0.isEmpty {
                    $0.append(0)
                }
                $0.append(contentsOf: $1.utf8)
            }
    }
}

extension Character {
    /// Whether this is a space or tab.
    ///
    /// SASL responses are separated by ASCII whitespace only.
    fileprivate var isSASLWhitespace: Bool {
        (self == " ") || (self == "\t")
    }
}

extension UInt8 {
    /// Whether this is a byte that can appear in base64 encoded data, including its padding.
    fileprivate var isBase64Byte: Bool {
        switch self {
        case UInt8(ascii: "0")...UInt8(ascii: "9"): true
        case UInt8(ascii: "A")...UInt8(ascii: "Z"): true
        case UInt8(ascii: "a")...UInt8(ascii: "z"): true
        case UInt8(ascii: "/"), UInt8(ascii: "+"), UInt8(ascii: "="): true
        default: false
        }
    }
}
