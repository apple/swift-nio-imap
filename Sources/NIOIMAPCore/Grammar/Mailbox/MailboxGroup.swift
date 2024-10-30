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

/// A group of addresses.
public struct EmailAddressGroup: Hashable, Sendable {
    /// The name of the group.
    public var groupName: ByteBuffer

    /// The group's source-root.
    public var sourceRoot: ByteBuffer?

    /// Any child groups or addresses.
    public var children: [EmailAddressListElement]

    /// Creates a new `EmailAddressGroup`.
    /// - parameter groupName: The name of the group.
    /// - parameter sourceRoot: The group's source-root.
    /// - parameter children: Any child groups or addresses.
    public init(groupName: ByteBuffer, sourceRoot: ByteBuffer?, children: [EmailAddressListElement]) {
        self.groupName = groupName
        self.sourceRoot = sourceRoot
        self.children = children
    }
}

/// Used inside `Envelope` to distinguish between either a single address, or a group of addresses.
public indirect enum EmailAddressListElement: Hashable, Sendable {
    /// A single address with no children.
    case singleAddress(EmailAddress)

    /// A collection of potentially nested groups and addresses.
    case group(EmailAddressGroup)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeEmailAddressGroup(_ group: EmailAddressGroup) -> Int {
        self.writeEmailAddress(
            .init(
                personName: nil,
                sourceRoot: group.sourceRoot,
                mailbox: group.groupName,
                host: nil
            )
        )
            + self.writeArray(group.children, prefix: "", separator: "", suffix: "", parenthesis: false) {
                (child, self) in
                self.writeEmailAddressOrGroup(child)
            }
            + self.writeEmailAddress(
                .init(
                    personName: nil,
                    sourceRoot: group.sourceRoot,
                    mailbox: nil,
                    host: nil
                )
            )
    }

    @discardableResult mutating func writeEmailAddressOrGroup(_ aog: EmailAddressListElement) -> Int {
        switch aog {
        case .singleAddress(let address):
            return self.writeEmailAddress(address)
        case .group(let group):
            return self.writeEmailAddressGroup(group)
        }
    }
}
