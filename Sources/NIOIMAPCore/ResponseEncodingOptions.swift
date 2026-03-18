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

/// Configuration options for encoding IMAP server responses.
///
/// `ResponseEncodingOptions` controls how server responses are encoded into wire format.
/// Since responses are typically simpler than commands, fewer encoding options are needed.
///
/// ## Quoted Strings
///
/// The primary option is whether to use quoted strings or literals for string values
/// in responses. Quoted strings are generally preferred for readability and performance.
///
/// - SeeAlso: [RFC 3501 Section 4.3](https://datatracker.ietf.org/doc/html/rfc3501#section-4.3)
public struct ResponseEncodingOptions: Hashable, Sendable {
    /// Use RFC 3501 quoted strings when possible.
    ///
    /// When `true`, string values in responses are encoded as quoted strings if they
    /// contain only safe characters. When `false`, literals are used instead.
    ///
    /// - SeeAlso: [RFC 3501 Section 4.3](https://datatracker.ietf.org/doc/html/rfc3501#section-4.3)
    public var useQuotedString: Bool

    /// Creates RFC 3501-compliant response encoding options.
    ///
    /// The default options enable quoted strings for compatibility with all IMAP clients.
    public init() {
        self.useQuotedString = true
    }
}

extension ResponseEncodingOptions {
    /// Creates response encoding options based on server capabilities.
    ///
    /// This initializer provides a hook for capability-dependent encoding configuration,
    /// though currently no capabilities affect response encoding options. The capabilities
    /// parameter is provided for future extensibility.
    ///
    /// - Parameter capabilities: Array of ``Capability`` from a `CAPABILITY` response.
    ///
    /// - Returns: Standard response encoding options.
    public init(capabilities: [Capability]) {
        self.init()
    }
}
