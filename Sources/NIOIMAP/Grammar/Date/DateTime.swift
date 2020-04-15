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
    
    @discardableResult mutating func writeDateTime(_ dateTime: IMAPCore.Date.DateTime) -> Int {
        self.writeString("\"\(dateTime.date.day)-\(dateTime.date.month.rawValue)-\(dateTime.date.year) ") +
        self.writeTime(dateTime.time) +
        self.writeSpace() +
        self.writeTimezone(dateTime.zone) +
        self.writeString("\"")
    }
    
}
