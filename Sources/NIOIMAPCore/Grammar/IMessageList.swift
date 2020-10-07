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

/// RFC 5092
public struct IMessageList: Equatable {
    public var mailboxReference: IMailboxReference
    public var encodedSearch: EncodedSearch?

    public init(mailboxReference: IMailboxReference, encodedSearch: EncodedSearch? = nil) {
        self.mailboxReference = mailboxReference
        self.encodedSearch = encodedSearch
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeIMessageList(_ ref: IMessageList) -> Int {
        self.writeIMailboxReference(ref.mailboxReference) +
            self.writeIfExists(ref.encodedSearch, callback: { search in
                self.writeString("?") + self.writeEncodedSearch(search)
            })
    }
}
