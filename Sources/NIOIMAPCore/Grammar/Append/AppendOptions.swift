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

public struct AppendOptions: Equatable {
    public var flagList: [Flag]
    public var internalDate: InternalDate?
    public var extensions: [TaggedExtension]

    public init(flagList: [Flag], internalDate: InternalDate? = nil, extensions: [TaggedExtension]) {
        self.flagList = flagList
        self.internalDate = internalDate
        self.extensions = extensions
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeAppendOptions(_ options: AppendOptions) -> Int {
        self.writeIfArrayHasMinimumSize(array: options.flagList) { (array, self) -> Int in
            self.writeSpace() +
                self.writeFlags(array)
        } +
            self.writeIfExists(options.internalDate) { (internalDate) -> Int in
                self.writeSpace() +
                    self.writeInternalDate(internalDate)
            } +
            self.writeArray(options.extensions, prefix: " ", separator: "", parenthesis: false) { (ext, self) -> Int in
                self.writeTaggedExtension(ext)
            }
    }
}
