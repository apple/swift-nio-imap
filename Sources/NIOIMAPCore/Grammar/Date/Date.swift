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

/// IMAPv4 `date` (`date-text`)
public struct Date: Equatable {
    public var year: Int
    public var month: Int
    public var day: Int

    public init?(year: Int, month: Int, day: Int) {
        guard
            day >= 1,
            day <= 31,
            month >= 1,
            month <= 12,
            year >= 1900,
            year <= 2500
        else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }
}

// MARK: - IMAP

extension EncodeBuffer {
    @discardableResult mutating func writeDate(_ date: Date) -> Int {
        self.writeString("\(date.day)-\(date.monthString)-\(date.year)")
    }
}

extension Date {
    var monthString: String {
        switch month {
        case 1: return "Jan"
        case 2: return "Feb"
        case 3: return "Mar"
        case 4: return "Apr"
        case 5: return "May"
        case 6: return "Jun"
        case 7: return "Jul"
        case 8: return "Aug"
        case 9: return "Sep"
        case 10: return "Oct"
        case 11: return "Nov"
        case 12: return "Dec"
        default: preconditionFailure("Expected 1 <= month <= 12")
        }
    }

    static func month(text: String) -> Int? {
        switch text.lowercased() {
        case "jan": return 1
        case "feb": return 2
        case "mar": return 3
        case "apr": return 4
        case "may": return 5
        case "jun": return 6
        case "jul": return 7
        case "aug": return 8
        case "sep": return 9
        case "oct": return 10
        case "nov": return 11
        case "dec": return 12
        default: return nil
        }
    }
}
