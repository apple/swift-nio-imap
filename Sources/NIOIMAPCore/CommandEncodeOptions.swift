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

public struct CommandEncodingOptions: Equatable {
    /// Use RFC 3501 _quoted strings_ when possible (and the string is relatively short).
    var useQuotedString: Bool
    /// Use the RFC 3501 `{20}` style literals.
    var useSynchronizingLiteral: Bool
    /// Use the `{20+}` style non-synchronizing literals
    /// - SeeAlso: https://tools.ietf.org/html/rfc2088
    var useNonSynchronizingLiteral: Bool
    /// Use binary content literals, i.e. `~{20}` style literals as defined in RFC 3516.
    /// - Note: These can only be used in some places, namely `APPEND`.
    /// - SeeAlso: https://tools.ietf.org/html/rfc3516
    var useBinaryLiteral: Bool

    /// Create RFC 3501 compliant encoding options, i.e. without any IMAP extensions.
    public init() {
        self.useQuotedString = true
        self.useSynchronizingLiteral = true
        self.useNonSynchronizingLiteral = false
        self.useBinaryLiteral = false
    }
}

extension CommandEncodingOptions {
    init(capabilities: [Capability]) {
        self.init()
        if capabilities.contains(.literal(.plus)) {
            self.useNonSynchronizingLiteral = true
        }
        if capabilities.contains(.binary) {
            self.useBinaryLiteral = true
        }
    }
}
