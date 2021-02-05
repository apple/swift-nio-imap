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

/// Various options that may be added to a message when it is appended to a mailbox.
public struct AppendOptions: Equatable {
    /// Flags that will be added to the message
    public var flagList: [Flag]

    /// The date associated with the message, typically the date of delivery
    public var internalDate: InternalDate?

    /// Any additional pieces of information to be associated with the message. Implemented as a "catch-all" to support future extensions.
    public var extensions: KeyValues<String, ParameterValue>

    /// Creates a new `AppendOptions`
    /// - parameter flagList: Flags that will be added to the message.
    /// - parameter internalDate: An optional date to be associated with the message, typically representing the date of delivery. Defaults to `nil`.
    /// - parameter extensions: Any additional pieces of information to be associated with the message. Implemented as a "catch-all" to support future extensions.
    public init(flagList: [Flag], internalDate: InternalDate? = nil, extensions: KeyValues<String, ParameterValue>) {
        self.flagList = flagList
        self.internalDate = internalDate
        self.extensions = extensions
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeAppendOptions(_ options: AppendOptions) -> Int {
        self.write(if: options.flagList.count >= 1) {
            self.writeSpace() + self.writeFlags(options.flagList)
        } +
            self.writeIfExists(options.internalDate) { (internalDate) -> Int in
                self.writeSpace() +
                    self.writeInternalDate(internalDate)
            } +
            self.writeKeyValues(options.extensions, prefix: " ", parenthesis: false) { (ext, self) -> Int in
                self.writeTaggedExtension(ext)
            }
    }
}
