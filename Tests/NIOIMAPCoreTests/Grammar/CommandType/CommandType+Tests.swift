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
        let inputs: [(Command, EncodingCapabilities, EncodingOptions, String, UInt)] = [
            (.list(nil, reference: .init(""), .mailbox(""), []), [], .default, "LIST \"\" \"\"", #line),
            (.list(reference: .init(""), .mailbox("")), [], .default, "LIST \"\" \"\"", #line),
            (.list(reference: .init(""), .mailbox("")), [.listExtended], .default, "LIST \"\" \"\"", #line), // no ret-opts but has capability
            (.list(nil, reference: .inbox, .mailbox(""), [.children]), [.listExtended], .default, "LIST \"INBOX\" \"\" RETURN (CHILDREN)", #line), // ret-opts with capability

            (.namespace, [.namespace], .default, "NAMESPACE", #line),

            // MARK: Login

            (.login(username: "username", password: "password"), [], .default, #"LOGIN "username" "password""#, #line),
            (.login(username: "david evans", password: "great password"), [], .default, #"LOGIN "david evans" "great password""#, #line),
            (.login(username: "\r\n", password: "\\\""), [], .default, "LOGIN {2}\r\n\r\n {2}\r\n\\\"", #line),

            (.select(MailboxName("Events")), [], .default, #"SELECT "Events""#, #line),
            (.examine(MailboxName("Events")), [], .default, #"EXAMINE "Events""#, #line),
            (.move([1], .inbox), [.move], .default, "MOVE 1 \"INBOX\"", #line),
            (.id([]), [.id], .default, "ID NIL", #line),
        ]

        self.iterateInputs(inputs: inputs, encoder: { try self.testBuffer.writeCommandType($0) })
    }
}
