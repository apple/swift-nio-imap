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

/// Authentication credentials for an IMAP connection.
public enum IMAPCredential: Equatable, Sendable {
    case username(String, password: String)
    case sasl(mechanism: String, response: Data)
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
            return "SASL \(mechanism) [\(response.count) bytes]"
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
            let scanner = Scanner(string: s)
            scanner.charactersToBeSkipped = nil
            guard
                let mechanism = scanner.scanSASLMechanism(),
                scanner.scanString(":") != nil,
                let response = scanner.scanSASLResponseUntilEnd()
            else { throw UnableToParseSASL() }
            self = .sasl(mechanism: mechanism, response: response)
        case (nil, nil, nil, let text?):
            let scanner = Scanner(string: text)
            scanner.charactersToBeSkipped = nil
            guard
                let user = scanner.scanUpToString(":"),
                scanner.scanString(":") != nil,
                let password = scanner.scanUpToString(":"),
                scanner.isAtEnd
            else { throw UnableToParseUsernamePassword() }
            self = .username(user, password: password)
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

extension Scanner {
    func scanSASLMechanism() -> String? {
        scanCharacters(from: .saslMechanism).map { $0.uppercased() }
    }

    func scanSASLResponseUntilEnd() -> Data? {
        self.scanSASLResponseUntilEnd_singleBase64() ?? self.scanSASLResponseUntilEnd_stringParts()
    }

    private func scanSASLResponseUntilEnd_singleBase64() -> Data? {
        let original = currentIndex
        guard
            let t = scanCharacters(from: .base64),
            isAtEnd,
            let d = Data(base64Encoded: t)
        else {
            currentIndex = original
            return nil
        }
        return d
    }

    private func scanSASLResponseUntilEnd_stringParts() -> Data? {
        let original = currentIndex
        var parts: [String] = []
        while let next = scanUpToCharacters(from: .whitespaces) {
            parts.append(next)
            guard scanCharacters(from: .whitespaces) != nil else { break }
        }
        guard isAtEnd else {
            currentIndex = original
            return nil
        }
        return
            parts
            .map { $0.data(using: .utf8)! }
            .reduce(into: Data()) {
                if !$0.isEmpty {
                    $0.append(0)
                }
                $0.append($1)
            }
    }
}

extension CharacterSet {
    static let saslMechanism = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
    static let base64 = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/+=")
}
