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

/// RFC 7162
public struct IMessagePart: Equatable {
    
    public var mailboxReference: IMailboxReference
    public var iUID: IUID
    public var iSection: ISection?
    public var iPartial: IPartial?

    public init(mailboxReference: IMailboxReference, iUID: IUID, iSection: ISection? = nil, iPartial: IPartial? = nil) {
        self.mailboxReference = mailboxReference
        self.iUID = iUID
        self.iSection = iSection
        self.iPartial = iPartial
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeIMessagePart(_ data: IMessagePart) -> Int {
        self.writeIMailboxReference(data.mailboxReference) +
            self.writeIUID(data.iUID) +
            self.writeIfExists(data.iSection, callback: { section in
                self.writeISection(section)
            }) +
            self.writeIfExists(data.iPartial, callback: { partial in
                self.writeIPartial(partial)
            })
    }
}
