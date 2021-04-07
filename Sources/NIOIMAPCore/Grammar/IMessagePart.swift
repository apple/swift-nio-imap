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

/// Can be used as a direct path to a specific message section and part.
public struct IMessagePart: Equatable {
    /// Connection details for a server and a specific mailbox hosted on that server.
    public var mailboxReference: MailboxUIDValidity

    /// The UID of the message in question.
    public var iUID: IUID

    /// An optional section of the message in question.
    public var section: URLMessageSection?

    /// A specific range of bytes of the message/section in question.
    public var iPartial: IPartial?

    /// Create a new `IMessagePart`.
    /// - parameter mailboxUIDValidity: Connection details for a server and a specific mailbox hosted on that server.
    /// - parameter iUID: The UID of the message in question.
    /// - parameter IMAPURLSection: An optional section of the message in question.
    /// - parameter iPartial: A specific range of bytes of the message/section in question.
    public init(mailboxReference: MailboxUIDValidity, iUID: IUID, section: URLMessageSection? = nil, iPartial: IPartial? = nil) {
        self.mailboxReference = mailboxReference
        self.iUID = iUID
        self.section = section
        self.iPartial = iPartial
    }
}

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeIMessagePart(_ data: IMessagePart) -> Int {
        self.writeEncodedMailboxUIDValidity(data.mailboxReference) +
            self.writeIUID(data.iUID) +
            self.writeIfExists(data.section) { section in
                self.writeURLMessageSection(section)
            } +
            self.writeIfExists(data.iPartial) { partial in
                self.writeIPartial(partial)
            }
    }
}
