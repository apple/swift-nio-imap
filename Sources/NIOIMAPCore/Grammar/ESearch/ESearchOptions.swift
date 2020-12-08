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
public struct ESearchOptions: Equatable {
    /// The search criteria.
    public var key: SearchKey

    /// The charset to use when performing the search.
    public var charset: String?

    /// Return options to filter the data that is returned.
    public var returnOptions: [SearchReturnOption]

    /// Specifies where should be searched, for example a single mailbox.
    public var sourceOptions: ESearchSourceOptions?

    /// Creates a new `ESearchOptions`
    /// - parameter key: The search criteria.
    /// - parameter charset: The charset to use when performing the search.
    /// - parameter returnOptions: Return options to filter the data that is returned.
    /// - parameter sourceOptions: Specifies where should be searched, for example a single mailbox.
    public init(
        key: SearchKey,
        charset: String? = nil,
        returnOptions: [SearchReturnOption] = [],
        sourceOptions: ESearchSourceOptions? = nil
    ) {
        self.key = key
        self.charset = charset
        self.returnOptions = returnOptions
        self.sourceOptions = sourceOptions
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeESearchOptions(_ options: ESearchOptions) -> Int {
        self.writeIfExists(options.sourceOptions) { (options) -> Int in
            self.writeSpace() + self.writeESearchSourceOptions(options)
        } +
            self.writeIfExists(options.returnOptions) { (options) -> Int in
                self.writeSearchReturnOptions(options)
            } +
            self.writeSpace() +
            self.writeIfExists(options.charset) { (charset) -> Int in
                self.writeString("CHARSET \(charset) ")
            } +
            self.writeSearchKey(options.key)
    }
}
