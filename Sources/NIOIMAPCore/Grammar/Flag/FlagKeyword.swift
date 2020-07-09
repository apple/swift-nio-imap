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

extension Flag {
    /// IMAP Flag Keyword
    ///
    /// Flags are case preserving, but case insensitive.
    /// As such e.g. `Flag.Keyword("$Forwarded") == Flag.Keyword("$forwarded")`, but
    /// it will round-trip preserving its case.
    public struct Keyword: Hashable {
        public var rawValue: String

        public static func == (lhs: Keyword, rhs: Keyword) -> Bool {
            lhs.rawValue.uppercased() == rhs.rawValue.uppercased()
        }

        public func hash(into hasher: inout Hasher) {
            rawValue.uppercased().hash(into: &hasher)
        }

        public init(_ string: String) {
            precondition(string.utf8.allSatisfy { (c) -> Bool in
                c.isAtomChar
            }, "String contains invalid characters")
            self.rawValue = string
        }

        fileprivate init(unchecked string: String) {
            assert(string.utf8.allSatisfy { (c) -> Bool in
                c.isAtomChar
            })
            self.rawValue = string
        }
    }
}

// MARK: - Convenience

extension Flag.Keyword {
    /// `$Forwarded`
    public static let forwarded = Self(unchecked: "$Forwarded")

    /// `$Junk`
    public static let junk = Self(unchecked: "$Junk")

    /// `$NotJunk`
    public static let notJunk = Self(unchecked: "$NotJunk")

    /// `Redirected`
    public static let unregistered_redirected = Self(unchecked: "Redirected")

    /// `Forwarded`
    public static let unregistered_forwarded = Self(unchecked: "Forwarded")

    /// `Junk`
    public static let unregistered_junk = Self(unchecked: "Junk")

    /// `NotJunk`
    public static let unregistered_notJunk = Self(unchecked: "NotJunk")

    /// `$MailFlagBit0`
    public static let colorBit0 = Self(unchecked: "$MailFlagBit0")

    /// `$MailFlagBit1`
    public static let colorBit1 = Self(unchecked: "$MailFlagBit1")

    /// `$MailFlagBit2`
    public static let colorBit2 = Self(unchecked: "$MailFlagBit2")

    /// `$MDNSent`
    public static let mdnSent = Self(unchecked: "$MDNSent")
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeFlagKeyword(_ keyword: Flag.Keyword) -> Int {
        self.writeString(keyword.rawValue)
    }
}
