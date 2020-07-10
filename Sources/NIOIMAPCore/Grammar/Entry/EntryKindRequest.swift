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

public enum EntryKindRequest: Equatable {
    case response(EntryKindResponse)
    case all
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeEntryKindRequest(_ request: EntryKindRequest) -> Int {
        switch request {
        case .response(let response):
            return self.writeEntryKindResponse(response)
        case .all:
            return self.writeString("all")
        }
    }
}
