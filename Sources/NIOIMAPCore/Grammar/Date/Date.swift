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
    public var day: Int
    public var month: Int
    public var year: Int

    public init?(day: Int, month: Int, year: Int) {
        guard
            1 <= day,
            day <= 31,
            1 <= month,
            month <= 12,
            1900 <= year,
            year <= 2500
            else { return nil }
        self.day = day
        self.month = month
        self.year = year
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
        case 1: return "jan"
        case 2: return "feb"
        case 3: return "mar"
        case 4: return "apr"
        case 5: return "may"
        case 6: return "jun"
        case 7: return "jul"
        case 8: return "aug"
        case 9: return "sep"
        case 10: return "oct"
        case 11: return "nov"
        case 12: return "dec"
        default: fatalError()
        }
    }

    static func month(text: String) -> Int? {
        switch text {
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
