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
    enum _Flag: Hashable {
        case answered
        case flagged
        case deleted
        case seen
        case draft
        case keyword(Flag.Keyword)
        case `extension`(String)
    }

    public struct Flag: Hashable {
        var _backing: _Flag

        public static var answered: Self {
            Self(_backing: .answered)
        }

        public static var flagged: Self {
            Self(_backing: .flagged)
        }

        public static var deleted: Self {
            Self(_backing: .deleted)
        }

        public static var seen: Self {
            Self(_backing: .seen)
        }

        public static var draft: Self {
            Self(_backing: .draft)
        }

        public static func keyword(_ keyword: Keyword) -> Self {
            Self(_backing: .keyword(keyword))
        }

        public static func `extension`(_ string: String) -> Self {
            Self(_backing: .extension(string))
        }
    }
}

// MARK: - Encoding

extension ByteBuffer {
    @discardableResult mutating func writeFlags(_ flags: [NIOIMAP.Flag]) -> Int {
        self.writeArray(flags) { (flag, self) -> Int in
            self.writeFlag(flag)
        }
    }

    @discardableResult mutating func writeFlag(_ flag: NIOIMAP.Flag) -> Int {
        switch flag._backing {
        case .answered:
            return self.writeString("\\Answered")
        case .flagged:
            return self.writeString("\\Flagged")
        case .deleted:
            return self.writeString("\\Deleted")
        case .seen:
            return self.writeString("\\Seen")
        case .draft:
            return self.writeString("\\Draft")
        case .keyword(let keyword):
            return self.writeFlagKeyword(keyword)
        case .extension(let x):
            return self.writeString("\\\(x)")
        }
    }
}
