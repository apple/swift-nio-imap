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

public struct AppendExtension: Equatable {
    public var name: String
    public var value: TaggedExtensionValue

    public init(name: String, value: NIOIMAP.TaggedExtensionValue) {
        self.name = name
        self.value = value
    }
}

// MARK: - Encoding

extension ByteBuffer {
    @discardableResult mutating func writeAppendExtension(_ data: AppendExtension) -> Int {
        self.writeAppendExtensionName(data.name) +
            self.writeSpace() +
            self.writeTaggedExtensionValue(data.value)
    }
}
