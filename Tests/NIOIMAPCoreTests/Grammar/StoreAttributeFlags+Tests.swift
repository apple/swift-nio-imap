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

class StoreAttributeFlags_Tests: EncodeTestClass {}

// MARK: - Encoding

extension StoreAttributeFlags_Tests {
    func testEncode() {
        let inputs: [(StoreFlags, String, UInt)] = [
            (.add(silent: true, list: [.answered]), "+FLAGS.SILENT (\\ANSWERED)", #line),
            (.add(silent: false, list: [.draft]), "+FLAGS (\\DRAFT)", #line),
            (.remove(silent: true, list: [.deleted]), "-FLAGS.SILENT (\\DELETED)", #line),
            (.remove(silent: false, list: [.flagged]), "-FLAGS (\\FLAGGED)", #line),
            (.replace(silent: true, list: [.seen]), "FLAGS.SILENT (\\SEEN)", #line),
            (.replace(silent: false, list: [.deleted]), "FLAGS (\\DELETED)", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeStoreAttributeFlags(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
