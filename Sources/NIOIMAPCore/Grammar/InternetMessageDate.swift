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

/// A textual RFC 2822 date as it appears in email message headers.
///
/// This type represents the date field value from an email message's `Date` header,
/// formatted according to RFC 2822 section 3.3. Unlike ``ServerMessageDate``, which records
/// when the server received the message, this date represents the date the message was
/// composed by its sender.
///
/// The value is stored as a string without parsing or validation. To use the string value,
/// construct a `String` from this type using the `init(_ date:)` initializer.
///
/// ### Example
///
/// ```
/// * 1 FETCH (BODY[HEADER.FIELDS (DATE)] “Date: Fri, 15 Mar 2026 10:30:45 +0100”)
/// ```
///
/// The date header value `Fri, 15 Mar 2026 10:30:45 +0100` can be represented as an
/// ``InternetMessageDate``. Use `String(InternetMessageDate(...))` to retrieve the string value.
///
/// - SeeAlso: [RFC 2822 Section 3.3](https://datatracker.ietf.org/doc/html/rfc2822#section-3.3)
public struct InternetMessageDate: Hashable, Sendable {
    var value: String

    /// Creates a new `InternetMessageDate` from a given `String`.
    ///
    /// The string is stored as-is without parsing or validation. The caller is responsible
    /// for ensuring the string represents a valid RFC 2822 date format.
    ///
    /// - Parameter string: A `String` containing the RFC 2822 date value (e.g., `”Fri, 15 Mar 2026 10:30:45 +0100”`).
    public init(_ string: String) {
        self.value = string
    }
}

extension String {
    /// Creates a new `String` from an `InternetMessageDate`.
    ///
    /// This extracts the underlying string value from the ``InternetMessageDate``.
    ///
    /// - Parameter date: The `InternetMessageDate` to convert.
    public init(_ date: InternetMessageDate) {
        self = date.value
    }
}

extension InternetMessageDate: ExpressibleByStringLiteral {
    /// Creates a new `InternetMessageDate` from a string literal.
    ///
    /// This allows you to write RFC 2822 dates as string literals:
    /// ```swift
    /// let date: InternetMessageDate = “Fri, 15 Mar 2026 10:30:45 +0100”
    /// ```
    ///
    /// - Parameter stringLiteral: A `String` containing the RFC 2822 date value.
    public init(stringLiteral value: String) {
        self.value = value
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeInternetMessageDate(_ date: InternetMessageDate) -> Int {
        self.writeString(date.value)
    }
}
