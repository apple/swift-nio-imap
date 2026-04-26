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

/// Configuration options for encoding IMAP commands.
///
/// `CommandEncodingOptions` controls how IMAP commands are encoded into wire format,
/// particularly affecting the choice of literal formats and string quoting. These options
/// allow clients to select encoding strategies based on server capabilities and protocol
/// versions.
///
/// ## Literal Formats
///
/// The IMAP protocol defines several literal formats, each with different tradeoffs:
/// - **Quoted strings**: Safe, fast, but limited to certain characters
/// - **Synchronizing literals** (`{20}`): Standard in RFC 3501, requires continuation
/// - **Non-synchronizing literals** (`{20+}`/`{20-}`): RFC 7888, faster, no continuation needed
/// - **Binary literals** (`~{20}`): RFC 3516, for binary data in `APPEND` commands
///
/// The options below control which formats the encoder will use when serializing strings
/// and binary data.
///
/// ## Example
///
/// ```swift
/// var options = CommandEncodingOptions()
/// options.useNonSynchronizingLiteralPlus = true  // Use LITERAL+ format
/// options.useBinaryLiteral = true  // Support binary data
/// ```
///
/// - SeeAlso: [RFC 3501 Section 4.3](https://datatracker.ietf.org/doc/html/rfc3501#section-4.3) (quoted strings),
///   [RFC 3501 Section 4.3.3](https://datatracker.ietf.org/doc/html/rfc3501#section-4.3.3) (literals),
///   [RFC 7888](https://datatracker.ietf.org/doc/html/rfc7888) (non-synchronizing literals),
///   [RFC 3516](https://datatracker.ietf.org/doc/html/rfc3516) (binary literals)
public struct CommandEncodingOptions: Hashable, Sendable {
    /// Use RFC 3501 quoted strings when possible.
    ///
    /// Quoted strings are the preferred encoding for short strings containing only
    /// safe characters. Setting this to `false` forces use of literals instead.
    ///
    /// - SeeAlso: [RFC 3501 Section 4.3](https://datatracker.ietf.org/doc/html/rfc3501#section-4.3)
    public var useQuotedString: Bool

    /// Use the RFC 3501 synchronizing literal format (`{20}\r\n`).
    ///
    /// The standard literal format that requires the server to send a `+`
    /// continuation request before the client sends the literal data. Set to `true`
    /// for RFC 3501-compliant encoding.
    ///
    /// - SeeAlso: [RFC 3501 Section 4.3.3](https://datatracker.ietf.org/doc/html/rfc3501#section-4.3.3)
    public var useSynchronizingLiteral: Bool

    /// Use the non-synchronizing literal plus format (`{20+}\r\n`).
    ///
    /// Defined in RFC 7888, this format allows sending literal data immediately
    /// without waiting for a continuation request, improving performance at the cost
    /// of requiring server support.
    ///
    /// Requires server capability: ``Capability/literalPlus``
    ///
    /// - SeeAlso: [RFC 7888](https://datatracker.ietf.org/doc/html/rfc7888)
    public var useNonSynchronizingLiteralPlus: Bool

    /// Use the non-synchronizing literal minus format (`{20-}\r\n`).
    ///
    /// An alternative non-synchronizing literal format. If both this and
    /// ``useNonSynchronizingLiteralPlus`` are `true`, the implementation may choose
    /// either format.
    ///
    /// - SeeAlso: [RFC 7888](https://datatracker.ietf.org/doc/html/rfc7888)
    public var useNonSynchronizingLiteralMinus: Bool

    /// Use binary content literals (`~{20}\r\n`).
    ///
    /// Defined in RFC 3516, this format allows sending arbitrary binary data.
    /// Note that binary literals can only be used in certain contexts, such as the
    /// `APPEND` command with the `BINARY` extension.
    ///
    /// Requires server capability: ``Capability/binary``
    ///
    /// - Note: These can only be used in some places, namely `APPEND`.
    /// - SeeAlso: [RFC 3516](https://datatracker.ietf.org/doc/html/rfc3516)
    public var useBinaryLiteral: Bool

    /// Use the CHARSET parameter in `SEARCH` commands.
    ///
    /// RFC 3501 requires this parameter; later standards (RFC 9051, RFC 9755)
    /// recommend against or forbid it. This is typically modified based on the
    /// `UTF8=ACCEPT` capability (see ``updateEnabledOptions(capabilities:)``).
    ///
    /// - SeeAlso: [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4),
    ///   [RFC 9051](https://datatracker.ietf.org/doc/html/rfc9051),
    ///   [RFC 9755](https://datatracker.ietf.org/doc/html/rfc9755)
    public var useSearchCharset: Bool

    /// The default RFC 3501-compliant encoding options.
    ///
    /// These options enable quoted strings and synchronizing literals only,
    /// providing baseline compatibility with any IMAP server.
    public static let rfc3501: Self = .init()

    /// Creates new command encoding options with specified literal format preferences.
    ///
    /// By default, quoted strings and synchronizing literals are enabled, providing
    /// RFC 3501-compliant behavior.
    ///
    /// - Parameters:
    ///   - useQuotedString: Whether to use quoted strings. Defaults to `true`.
    ///   - useSynchronizingLiteral: Whether to use synchronizing literals. Defaults to `true`.
    ///   - useNonSynchronizingLiteralPlus: Whether to use LITERAL+ format. Defaults to `false`.
    ///   - useNonSynchronizingLiteralMinus: Whether to use LITERAL- format. Defaults to `false`.
    ///   - useBinaryLiteral: Whether to use binary literals. Defaults to `false`.
    public init(
        useQuotedString: Bool = true,
        useSynchronizingLiteral: Bool = true,
        useNonSynchronizingLiteralPlus: Bool = false,
        useNonSynchronizingLiteralMinus: Bool = false,
        useBinaryLiteral: Bool = false
    ) {
        self.useQuotedString = useQuotedString
        self.useSynchronizingLiteral = useSynchronizingLiteral
        self.useNonSynchronizingLiteralPlus = useNonSynchronizingLiteralPlus
        self.useNonSynchronizingLiteralMinus = useNonSynchronizingLiteralMinus
        self.useBinaryLiteral = useBinaryLiteral
        // set this to true instead of passing it from the caller, since
        // it shouldn't be based on CAPABILITY, only modified based on
        // ENABLED.
        self.useSearchCharset = true
    }
}

extension CommandEncodingOptions {
    /// Creates encoding options by inspecting server capabilities.
    ///
    /// Automatically enables extended literal formats based on
    /// server capabilities, making it easy to use the best available encoding strategy.
    ///
    /// The initialization process:
    /// - Starts with RFC 3501 defaults (quoted strings + synchronizing literals)
    /// - If server has `LITERAL+` capability: enables ``useNonSynchronizingLiteralPlus``
    /// - If server has `LITERAL-` capability: enables ``useNonSynchronizingLiteralMinus``
    /// - If server has `BINARY` capability: enables ``useBinaryLiteral``
    ///
    /// - Parameter capabilities: Array of ``Capability`` from a `CAPABILITY` response.
    ///
    /// - SeeAlso: ``Capability/literalPlus``, ``Capability/literalMinus``, ``Capability/binary``
    public init(capabilities: [Capability]) {
        self.init()
        if capabilities.contains(.literalPlus) {
            self.useNonSynchronizingLiteralPlus = true
        } else if capabilities.contains(.literalMinus) {
            self.useNonSynchronizingLiteralMinus = true
        }
        if capabilities.contains(.binary) {
            self.useBinaryLiteral = true
        }
    }

    /// Updates encoding options based on ENABLE response capabilities.
    ///
    /// After a client successfully enables extensions with the `ENABLE` command,
    /// this method updates the encoding options to reflect any newly enabled capabilities.
    /// Currently, this only affects the `useSearchCharset` option.
    ///
    /// When `UTF8=ACCEPT` is enabled, the `useSearchCharset` option is set to `false`
    /// because the server no longer requires charset specifications in SEARCH commands.
    ///
    /// - Parameter capabilities: Server capabilities that have been enabled.
    ///
    /// - SeeAlso: ``Capability/utf8(_:)``, [RFC 6531 Section 3.1](https://datatracker.ietf.org/doc/html/rfc6531#section-3.1)
    public mutating func updateEnabledOptions(capabilities: [Capability]) {
        if capabilities.contains(.utf8(.accept)) {
            self.useSearchCharset = false
        }
    }
}
