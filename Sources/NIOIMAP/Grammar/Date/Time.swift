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

import NIO
import IMAPCore

// MARK: - Encoding
extension ByteBuffer {
    
    @discardableResult mutating func writeTime(_ time: IMAPCore.Date.Time) -> Int {
        let hour = time.hour < 10 ? "0\(time.hour)" : "\(time.hour)"
        let minute = time.minute < 10 ? "0\(time.minute)" : "\(time.minute)"
        let second = time.second < 10 ? "0\(time.second)" : "\(time.second)"
        return self.writeString("\(hour):\(minute):\(second)")
    }
    
}
