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

/// A wrapper around a non-empty array of key/value pairs. This is used to provide
/// a catch-all for future extensions, as no options are currently explicitly defined.
public struct ExtendedSearchScopeOptions: Equatable {
    /// An array of Scope Option key/value pairs. Note that the array must not be empty.
    public private(set) var content: KeyValues<String, ParameterValue?>

    /// Creates a new `ExtendedSearchScopeOptions` from a non-empty array of options.
    ///  - parameter options: One or more options.
    /// - returns: A `nil` if `options` is empty, otherwise a new `ExtendedSearchScopeOptions`.
    init?(_ options: KeyValues<String, ParameterValue?>) {
        guard options.count >= 1 else {
            return nil
        }
        self.content = options
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeExtendedSearchScopeOptions(_ options: ExtendedSearchScopeOptions) -> Int {
        self.writeKeyValues(options.content, parenthesis: false) { (option, buffer) -> Int in
            buffer.writeParameter(option)
        }
    }
}
