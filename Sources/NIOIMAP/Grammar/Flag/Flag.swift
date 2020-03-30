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

    /// IMAP4 `flag-list`
    public typealias FlagList = [Flag]
 
    /// IMAPv4 `flag`
    public enum Flag: Equatable {
        case answered
        case flagged
        case deleted
        case seen
        case draft
        case keyword(Keyword)
        case `extension`(String)
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
        switch flag {
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
