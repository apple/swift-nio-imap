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

    /// IMAPv4 `search-return-data`
    public enum SearchReturnData: Equatable {
        case min(Int)
        case max(Int)
        case all([NIOIMAP.SequenceRange])
        case count(Int)
        case dataExtension(SearchReturnDataExtension)
    }

}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeSearchReturnData(_ data: NIOIMAP.SearchReturnData) -> Int {
        switch data {
        case .min(let num):
            return self.writeString("MIN \(num)")
        case .max(let num):
            return self.writeString("MAX \(num)")
        case .all(let set):
            return
                self.writeString("ALL ") +
                self.writeSequenceSet(set)
        case .count(let num):
            return self.writeString("COUNT \(num)")
        case .dataExtension(let optionExt):
            return self.writeSearchReturnDataExtension(optionExt)
        }
    }

}
