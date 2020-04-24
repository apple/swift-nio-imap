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

extension NIOIMAP {
    public enum EntryTypeResponse: Equatable {
        case `private`
        case shared
    }
}

// MARK: - Encoding

extension ByteBuffer {
    @discardableResult mutating func writeEntryTypeResponse(_ response: NIOIMAP.EntryTypeResponse) -> Int {
        switch response {
        case .private:
            return self.writeString("priv")
        case .shared:
            return self.writeString("shared")
        }
    }
}
