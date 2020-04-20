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

    public enum EntryTypeRequest: Equatable {
        case response(EntryTypeResponse)
        case all
    }

}

// MARK: - Encoding
extension ByteBuffer {
    
    @discardableResult mutating func writeEntryTypeRequest(_ request: NIOIMAP.EntryTypeRequest) -> Int {
        switch request {
        case .response(let response):
            return self.writeEntryTypeResponse(response)
        case .all:
            return self.writeString("all")
        }
    }
    
}
