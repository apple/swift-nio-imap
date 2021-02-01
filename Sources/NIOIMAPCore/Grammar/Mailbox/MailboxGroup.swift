//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2021 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct NIO.ByteBuffer

public struct AddressGroup: Equatable {
    
    
    public var mailboxName: MailboxName
    
    public var sourceRoot: ByteBuffer?
    
    public var children: [AddressOrGroup]
    
    public init(mailboxName: MailboxName, sourceRoot: ByteBuffer?, children: [AddressOrGroup]) {
        self.mailboxName = mailboxName
        self.sourceRoot = sourceRoot
        self.children = children
    }
}

public indirect enum AddressOrGroup: Equatable {
    case address(Address)
    case group(AddressGroup)
}

// MARK: - Encoding
extension EncodeBuffer {
    
    @discardableResult mutating func writeAddressGroup(_ group: AddressGroup) -> Int {
        
        self.writeAddress(.init(
            personName: nil,
            sourceRoot: group.sourceRoot,
            mailbox: group.mailboxName.storage,
            host: nil)
        ) +
        self.writeArray(group.children, prefix: "", separator: "", suffix: "", parenthesis: false) { (child, self) in
            self.writeAddressOrGroup(child)
        } +
        self.writeAddress(.init(
            personName: nil,
            sourceRoot: group.sourceRoot,
            mailbox: nil,
            host: nil)
        )
        
    }
    
    @discardableResult mutating func writeAddressOrGroup(_ aog: AddressOrGroup) -> Int {
        switch aog {
        case .address(let address):
            return self.writeAddress(address)
        case .group(let group):
            return self.writeAddressGroup(group)
        }
    }
    
}
