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
@testable import NIOIMAPCore
import XCTest

class IMessageList_Tests: EncodeTestClass {}

// MARK: - IMAP

extension IMessageList_Tests {
    func testEncode() {
        let inputs: [(IMessageList, String, UInt)] = [
            (
                .init(mailboxReference: .init(encodeMailbox: .init(mailbox: "box"), uidValidity: nil), encodedSearch: nil),
                "box",
                #line
            ),
            (
                .init(mailboxReference: .init(encodeMailbox: .init(mailbox: "box"), uidValidity: nil), encodedSearch: .init(query: "search")),
                "box?search",
                #line
            )
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeIMessageList($0) })
    }
}
