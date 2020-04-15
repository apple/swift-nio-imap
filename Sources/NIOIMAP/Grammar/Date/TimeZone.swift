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

// MARK: IMAP
extension ByteBuffer {
    
    @discardableResult mutating func writeTimezone(_ timezone: NIOIMAP.Date.TimeZone) -> Int {
        let string = String(abs(timezone.backing))
        
        let zeroedString: String
        if string.count < 4 {
            var output = ""
            output.reserveCapacity(4)
            output.append(contentsOf: repeatElement("0", count: 4 - string.count))
            output.append(string)
            zeroedString = output
        } else {
            zeroedString = string
        }
        
        let modifier = (timezone.backing >= 0) ? "+" : "-"
        return self.writeString("\(modifier)\(zeroedString)")
    }
    
}
