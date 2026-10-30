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
    /// - Warning: The text is written to the wire verbatim and must not contain NUL, CR, or LF:
    ///   `No mailbox x\r\n* BYE pwned` would inject a whole response. Writing such text traps in
    ///   debug builds.
    /// - Note: The parser skips spaces before the text, so leading spaces are not read back.
    /// - Warning: With a `nil` ``code``, a text that starts with `[` may be read back as a code:
    ///   text `[ALERT] hi` is sent as `* OK [ALERT] hi`. Don't start it with untrusted input.
    public var text: String

    /// Creates a new `ResponseText`.
    /// - parameter code: The optional structured status code. Defaults to `nil`.
    /// - parameter text: The human-readable description from the server.
    public init(code: ResponseTextCode? = nil, text: String) {
        self.code = code
        self.text = text
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
            + self.writeText(text.text.isEmpty ? " " : text.text)
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
