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

/// A wrapper for message preview text from the PREVIEW extension.
///
/// `PreviewText` wraps a string containing the client-facing preview of a message body.
/// The PREVIEW extension (RFC 8970) allows servers to generate and provide these previews
/// along with the full message, improving client UX without requiring clients to parse
/// message structures themselves.
///
/// This type provides type safety by wrapping the raw string in a distinct type, making
/// it clear in the API that a given string is specifically a message preview.
///
/// - SeeAlso: [RFC 8970](https://datatracker.ietf.org/doc/html/rfc8970), ``MessageAttribute/preview(_:)``
public struct PreviewText: Hashable, Sendable {
    fileprivate let text: String

    /// Creates a new preview text wrapper.
    ///
    /// - Parameter text: The preview text content from the server.
    public init(_ text: String) {
        self.text = text
    }
}

extension String {
    /// Extracts the preview text from a `PreviewText` wrapper.
    ///
    /// - Parameter other: The preview text to unwrap.
    public init(_ other: PreviewText) {
        self = other.text
    }
}
