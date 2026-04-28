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
    /// successful completion notifications. It is always present but may be a single space for some
    /// protocol-compliant responses.
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

            // If the text is empty, write an additional space
            // to enforce standard compliance. Oddly, this is
            // perfectly legal IMAP.
            + self.writeText(text.text.count > 0 ? text.text : " ")
    }

    @discardableResult mutating func writeText(_ text: String) -> Int {
        self.writeString(text)
    }
}

extension ResponseText: CustomDebugStringConvertible {
    public var debugDescription: String {
        EncodeBuffer.makeDescription {
            $0.writeResponseText(self)
        }
    }
}
