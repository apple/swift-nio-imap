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

/// Specifies what items of data should be returned for each matching mailbox when
/// executing a `.list` command.
public enum ReturnOption: Hashable, Sendable {
    /// Causes the LIST command to return subscription state
    /// for all matching mailbox names.
    case subscribed

    /// Requests mailbox child information
    case children

    /// The server MUST return an untagged LIST response followed by an untagged STATUS
    /// response containing the information requested in the STATUS return option.
    case statusOption([MailboxAttribute])

    /// Designed as a catch-all to support return options defined in future extensions
    case optionExtension(KeyValue<OptionExtensionKind, OptionValueComp?>)

    /// The LIST command MUST return only those mailboxes that have a
    /// special-use attribute set.
    case specialUse
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeReturnOption(_ option: ReturnOption) -> Int {
        switch option {
        case .subscribed:
            return self.writeString("SUBSCRIBED")
        case .children:
            return self.writeString("CHILDREN")
        case .statusOption(let option):
            return self.writeMailboxOptions(option)
        case .optionExtension(let option):
            return self.writeOptionExtension(option)
        case .specialUse:
            return self.writeString("SPECIAL-USE")
        }
    }
}
