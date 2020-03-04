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
 
    /// IMAPv4 `mailbox`
    public struct Mailbox: Equatable {
        
        /// IMAPv4 `list-mailbox`
        public typealias ListMailbox = IMAPString
        
        public var name: String
        
        public static let inbox = Self("inbox")
        
        public static func other(_ name: String) -> Self {
            return Self(name)
        }

        public init(_ name: String) {
            if name.lowercased() == "inbox" {
                self.name = "INBOX"
            } else {
                self.name = name
            }
        }
        
    }
    
}

// MARK: - ExpressibleByStringLiteral
extension NIOIMAP.Mailbox: ExpressibleByStringLiteral {
    
    public typealias StringLiteralType = String
    
    public init(stringLiteral value: String) {
        self.init(value)
    }
    
}

// MARK: - Encoding
extension ByteBuffer {
    
    @discardableResult mutating func writeMailbox(_ mailbox: NIOIMAP.Mailbox) -> Int {
        let buffer = ByteBuffer(ByteBufferView(mailbox.name.utf8))
        return self.writeIMAPString(buffer)
    }
    
}
