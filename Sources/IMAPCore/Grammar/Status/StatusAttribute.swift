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

extension IMAPCore {

    /// IMAPv4 `status-att`
    public enum StatusAttribute: String, CaseIterable {
        case messages = "MESSAGES"
        case recent = "RECENT"
        case uidnext = "UIDNEXT"
        case uidvalidity = "UIDVALIDITY"
        case unseen = "UNSEEN"
        case size = "SIZE"
        case highestModSeq = "HIGHESTMODSEQ"
    }
    
}

// MARK: - IMAP
extension ByteBufferProtocol {
    
    @discardableResult mutating func writeStatusAttributes(_ atts: [IMAPCore.StatusAttribute]) -> Int {
        self.writeArray(atts, parenthesis: false) { (element, self) in
            self.writeStatusAttribute(element)
        }
    }
    
    @discardableResult mutating func writeStatusAttribute(_ att: IMAPCore.StatusAttribute) -> Int {
        self.writeString(att.rawValue)
    }
    
}
