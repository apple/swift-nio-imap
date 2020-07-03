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

public struct ResponseEncodingOptions: Equatable {
    /// Use RFC 3501 _quoted strings_ when possible (and the string is relatively short).
    public var useQuotedString: Bool

    /// Create RFC 3501 compliant encoding options, i.e. without any IMAP extensions.
    public init() {
        self.useQuotedString = true
    }
}

extension ResponseEncodingOptions {
    public init(capabilities: [Capability]) {
        self.init()
    }
}
