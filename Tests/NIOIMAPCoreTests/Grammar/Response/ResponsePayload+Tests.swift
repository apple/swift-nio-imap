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
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import XCTest

class ResponsePayload_Tests: EncodeTestClass {}

// MARK: - Encoding

extension ResponsePayload_Tests {
    func testEncode() {
        let inputs: [(ResponsePayload, String, UInt)] = [
            (.capabilityData([.enable]), "CAPABILITY ENABLE", #line),
            (.conditionalState(.ok(.init(code: nil, text: "test"))), "OK test", #line),
            (.conditionalState(.bye(.init(code: nil, text: "test"))), "BYE test", #line),
            (.mailboxData(.exists(1)), "1 EXISTS", #line),
            (.messageData(.expunge(2)), "2 EXPUNGE", #line),
            (.enableData([.enable]), "ENABLED ENABLE", #line),
            (.id(["key": nil]), "ID (\"key\" NIL)", #line),
            (.quotaRoot(.init("INBOX"), .init("Root")), "QUOTAROOT \"INBOX\" \"Root\"", #line),
            (
                .quota(.init("Root"), [.init(resourceName: "STORAGE", usage: 10, limit: 512)]),
                "QUOTA \"Root\" (STORAGE 10 512)",
                #line
            ),
            (.metadata(.list(list: ["a"], mailbox: .inbox)), "METADATA \"INBOX\" \"a\"", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeResponsePayload($0) })
    }
}
