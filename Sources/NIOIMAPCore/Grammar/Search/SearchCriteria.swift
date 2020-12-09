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

extension EncodeBuffer {
    @discardableResult mutating func writeSearchCriteria(_ criteria: [SearchKey]) -> Int {
        self.writeArray(criteria, parenthesis: false) { (key, self) in
            self.writeSearchKey(key)
        }
    }
}
