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
    public enum Month: String {
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

    public var day: Int
    public var month: Month
    public var year: Int

    public init(day: Int, month: Date.Month, year: Int) {
        self.day = day
        self.month = month
        self.year = year
    }
}

// MARK: - IMAP

extension EncodeBuffer {
    @discardableResult mutating func writeDate(_ date: Date) -> Int {
        self.writeString("\(date.day)-\(date.month.rawValue)-\(date.year)")
    }
}
