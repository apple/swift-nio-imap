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

extension NIOIMAP {

    /// IMAPv4 `date` (`date-text`)
    public struct Date: Equatable {
        
        /// IMAPv4 `date-day` (`date-day-fixed`)
        typealias Day = Int
        
        /// IMAPv4 `date-year`
        typealias Year = Int
        
        enum Month: String {
            case jan
            case feb
            case mar
            case apr
            case may
            case jun
            case jul
            case aug
            case sep
            case oct
            case nov
            case dec
        }
        
        var day: Day
        var month: Month
        var year: Year
    }
    
}

// MARK: - IMAP
extension ByteBuffer {
    
    @discardableResult mutating func writeDate(_ date: NIOIMAP.Date) -> Int {
        self.writeString("\(date.day)-\(date.month.rawValue)-\(date.year)")
    }
    
}
