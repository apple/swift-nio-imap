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

class MetadataResponse_Tests: EncodeTestClass {}

// MARK: - IMAP

extension MetadataResponse_Tests {
    func testEncode() {
        let inputs: [(MetadataResponse, String, UInt)] = [
            (.list(list: ["a"], mailbox: .inbox), "METADATA \"INBOX\" \"a\"", #line),
            (.list(list: ["a", "b", "c"], mailbox: .inbox), "METADATA \"INBOX\" \"a\" \"b\" \"c\"", #line),
            (
                .values(values: ["a":.init(nil)], mailbox: .inbox),
                "METADATA \"INBOX\" (\"a\" NIL)",
                #line
            ),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeMetadataResponse($0) })
    }
}
