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

/// Text and optional status code returned by the server in a response.
///
/// Response text is always included with tagged responses and some untagged responses to provide
/// human-readable information about the result. The optional code field can contain structured
/// machine-readable status codes that provide additional semantic information. See [RFC 3501 Section 7.1](https://datatracker.ietf.org/doc/html/rfc3501#section-7.1)
/// for details on response text format.
///
/// ### Examples
///
/// ```
/// S: A001 OK CAPABILITY completed
/// S: A002 NO [CANNOT] Mailbox does not exist
/// S: A003 OK [UIDNEXT 4392] APPEND completed
/// ```
///
/// The first line wraps the response text "CAPABILITY completed" with no code.
/// The second line wraps the response text "Mailbox does not exist" with code ``ResponseTextCode/cannot``.
/// The third line wraps the response text "APPEND completed" with code ``ResponseTextCode/uidNext(_:)``.
///
/// - SeeAlso: ``ResponseTextCode``, [RFC 3501 Section 7.1](https://datatracker.ietf.org/doc/html/rfc3501#section-7.1)
public struct ResponseText: Hashable, Sendable {
    /// The optional structured status code providing additional semantic information.
    ///
    /// Status codes are brief tokens that communicate specific server conditions (for example, `[ALERT]`,
    /// `[CANNOT]`, `[PERMANENT]`). They provide machine-readable information to clients that extends
    /// the human-readable text. Not all responses include a code; `nil` indicates no code is present.
    ///
    /// - SeeAlso: ``ResponseTextCode``
    public var code: ResponseTextCode?

    /// A human-readable description from the server.
    ///
    /// The text provides context-specific information about the response, such as error messages or
    /// successful completion notifications. It may be empty.
    ///
    /// - Warning: With a `nil` ``code``, a text that starts with `[` may be read back as a code:
    ///   text `[ALERT] hi` is sent as `* OK [ALERT] hi`. Don't start it with untrusted input.
    public var text: Text

    /// Creates a new `ResponseText`.
    /// - parameter code: The optional structured status code. Defaults to `nil`.
    /// - parameter text: The human-readable description from the server.
    public init(code: ResponseTextCode? = nil, text: Text) {
        self.code = code
        self.text = text
    }
}

extension ResponseText {
    /// The human-readable part of a ``ResponseText``, for example `CAPABILITY completed`.
    ///
    /// ## Validity
    ///
    /// Text is written to the wire verbatim, so anything that can't be written as `text` is
    /// rejected:
    ///
    /// - ``init(_:)`` returns `nil`. Use it for text derived from input.
    /// - ``init(stringLiteral:)`` traps. A literal is written by the programmer, so an invalid one
    ///   is a bug to be caught on first run rather than handled.
    ///
    /// - SeeAlso: [RFC 9051 Section 9](https://datatracker.ietf.org/doc/html/rfc9051#section-9)
    public struct Text: Hashable, Sendable {
        let stringValue: String

        /// Creates text from a string, if the string can be written as `text`.
        ///
        /// A string literal resolves to ``init(stringLiteral:)`` instead, which traps rather than
        /// returning `nil`.
        ///
        /// - parameter stringValue: The text, for example `CAPABILITY completed`.
        /// - returns: New text, or `nil` if `stringValue` contains NUL, CR, or LF, or starts with a
        ///   space.
        public init?(_ stringValue: String) {
            guard Self.isValidText(stringValue) else { return nil }
            self.stringValue = stringValue
        }

        init(unchecked stringValue: String) {
            assert(Self.isValidText(stringValue))
            self.stringValue = stringValue
        }

        /// Whether the given string can be written as `text`
        /// ([RFC 9051 Section 9](https://datatracker.ietf.org/doc/html/rfc9051#section-9)):
        /// ```
        /// text      = 1*(TEXT-CHAR / UTF8-2 / UTF8-3 / UTF8-4)
        /// TEXT-CHAR = <any CHAR except CR and LF>
        /// ```
        /// A `String` is well-formed UTF-8, so every non-ASCII byte is part of a UTF8-2/3/4.
        ///
        /// Also allowed: empty, which is written as a single space. Not allowed: a leading space,
        /// since the parser skips spaces before the text (`OK  hi` reads as `hi`).
        static func isValidText(_ string: String) -> Bool {
            guard string.utf8.first != UInt8(ascii: " ") else { return false }
            return string.utf8.allSatisfy(\.isUTF8TextByte)
        }
    }
}

extension String {
    /// Creates a `String` from a ``ResponseText/Text``.
    ///
    /// - parameter other: The text to convert.
    public init(_ other: ResponseText.Text) {
        self = other.stringValue
    }
}

extension ResponseText.Text: ExpressibleByStringLiteral {
    /// Creates text from a string literal.
    ///
    /// A literal is written by the programmer, so an invalid one is a bug to be caught on first
    /// run rather than handled. Use ``init(_:)`` for anything else.
    ///
    /// - parameter value: The string literal.
    /// - Precondition: `value` can be written as `text`; this traps if it can't.
    public init(stringLiteral value: String) {
        precondition(Self.isValidText(value), "Invalid response text: \(String(reflecting: value))")
        self.init(unchecked: value)
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeResponseText(_ text: ResponseText) -> Int {
        self.writeIfExists(text.code) { (code) -> Int in
            self.writeString("[") + self.writeResponseTextCode(code) + self.writeString("] ")
        }

            // `text` is `1*…`, so empty text is written as a single space, which parses back as
            // empty.
            + self.writeText(text.text.stringValue.isEmpty ? " " : text.text.stringValue)
    }

    @discardableResult mutating func writeText(_ text: String) -> Int {
        assert(text.utf8.allSatisfy(\.isUTF8TextByte), "Invalid text: \(String(reflecting: text))")
        return self.writeString(text)
    }
}

extension ResponseText: CustomDebugStringConvertible {
    public var debugDescription: String {
        EncodeBuffer.makeDescription {
            $0.writeResponseText(self)
        }
    }
}
