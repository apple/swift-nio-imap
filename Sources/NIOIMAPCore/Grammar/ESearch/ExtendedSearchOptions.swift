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

/// Options for performing an extended search as defined in RFC 6237
public struct ExtendedSearchOptions: Equatable {
    /// The search criteria.
    public var key: SearchKey

    /// The charset to use when performing the search.
    public var charset: String?

    /// Return options to filter the data that is returned.
    public var returnOptions: [SearchReturnOption]

    /// Specifies where should be searched, for example a single mailbox.
    public var sourceOptions: ExtendedSearchSourceOptions?

    /// Creates a new `ExtendedSearchOptions`
    /// - parameter key: The search criteria.
    /// - parameter charset: The charset to use when performing the search.
    /// - parameter returnOptions: Return options to filter the data that is returned.
    /// - parameter sourceOptions: Specifies where should be searched, for example a single mailbox.
    public init(
        key: SearchKey,
        charset: String? = nil,
        returnOptions: [SearchReturnOption] = [],
        sourceOptions: ExtendedSearchSourceOptions? = nil
    ) {
        self.key = key
        self.charset = charset
        self.returnOptions = returnOptions
        self.sourceOptions = sourceOptions
    }
}

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeExtendedSearchOptions(_ options: ExtendedSearchOptions) -> Int {
        self.writeIfExists(options.sourceOptions) { (options) -> Int in
            self.writeSpace() + self.writeExtendedSearchSourceOptions(options)
        } +
            self.writeIfExists(options.returnOptions) { (options) -> Int in
                self.writeSearchReturnOptions(options)
            } +
            self.writeSpace() +
            self.writeIfExists(options.charset) { (charset) -> Int in
                self._writeString("CHARSET \(charset) ")
            } +
            self.writeSearchKey(options.key)
    }
}
