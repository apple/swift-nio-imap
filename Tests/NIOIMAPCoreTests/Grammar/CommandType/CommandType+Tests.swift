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

class CommandType_Tests: EncodeTestClass {}

// MARK: - Encoding

extension CommandType_Tests {
    func testEncode() {
        let inputs: [(Command, CommandEncodingOptions, [String], UInt)] = [
            (.list(nil, reference: .init(""), .mailbox(""), []), CommandEncodingOptions(), ["LIST \"\" \"\""], #line),
            (.list(reference: .init(""), .mailbox("")), CommandEncodingOptions(), ["LIST \"\" \"\""], #line),
            (.list(reference: .init(""), .mailbox("")), CommandEncodingOptions(), ["LIST \"\" \"\""], #line), // no ret-opts but has capability
            (.list(nil, reference: .inbox, .mailbox(""), [.children]), CommandEncodingOptions(), ["LIST \"INBOX\" \"\" RETURN (CHILDREN)"], #line), // ret-opts with capability

            (.namespace, CommandEncodingOptions(), ["NAMESPACE"], #line),

            // MARK: Login

            (.login(username: "username", password: "password"), CommandEncodingOptions(), [#"LOGIN "username" "password""#], #line),
            (.login(username: "david evans", password: "great password"), CommandEncodingOptions(), [#"LOGIN "david evans" "great password""#], #line),
            (.login(username: "\r\n", password: "\\\""), CommandEncodingOptions(), ["LOGIN {2}\r\n", "\r\n {2}\r\n", "\\\""], #line),

            (.select(MailboxName("Events")), CommandEncodingOptions(), [#"SELECT "Events""#], #line),
            (.examine(MailboxName("Events")), CommandEncodingOptions(), [#"EXAMINE "Events""#], #line),
            (.move([1], .inbox), CommandEncodingOptions(), ["MOVE 1 \"INBOX\""], #line),
            (.id([]), CommandEncodingOptions(), ["ID NIL"], #line),
        ]

        self.iterateInputs(inputs: inputs, encoder: { try self.testBuffer.writeCommandType($0) })
    }
}
