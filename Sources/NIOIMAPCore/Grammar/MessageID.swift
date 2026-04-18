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

/// The RFC 2822 Message-ID identifier for a message.
///
/// A Message-ID is an optional but recommended unique identifier for a message. It is typically
/// formatted as angle-bracketed text, for example <B27397-0100000@cac.washington.edu>. The Message-ID
/// appears in the In-Reply-To header and is used to correlate related messages in threads.
///
/// This type wraps the raw string value including angle brackets as sent by the server.
///
/// ### Example
///
/// ```
/// C: A001 FETCH 1 (ENVELOPE)
/// S: * 1 FETCH (ENVELOPE (...  “<msg-001@example.com>” ...))
/// ```
///
/// The Message-ID appears in the envelope structure returned by the FETCH response.
///
/// - SeeAlso: [RFC 2822 Section 3.6.4 Message Identifier](https://datatracker.ietf.org/doc/html/rfc2822#section-3.6.4)
/// - SeeAlso: [RFC 3501 Section 7.4.2 Envelope Structure](https://datatracker.ietf.org/doc/html/rfc3501#section-7.4.2)
public struct MessageID: Hashable, Sendable {
    /// The `String` message identifier.
    var rawValue: String

    /// Creates a new `MessageID` from the given string.
    /// - parameter rawValue: The `String` message identifier.
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

extension String {
    public init(_ id: MessageID) {
        self = id.rawValue
    }
}

// MARK: - ExpressibleByStringLiteral

extension MessageID: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMessageID(_ id: MessageID) -> Int {
        self.writeIMAPString(id.rawValue)
    }
}
