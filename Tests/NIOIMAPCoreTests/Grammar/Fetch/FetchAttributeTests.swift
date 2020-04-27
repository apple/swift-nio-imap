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

class FetchAttributeTests: EncodeTestClass {}

// MARK: - IMAP

extension FetchAttributeTests {
    func testEncode() {
        let inputs: [(NIOIMAP.FetchAttribute, String, UInt)] = [
            (.envelope, "ENVELOPE", #line),
            (.flags, "FLAGS", #line),
            (.uid, "UID", #line),
            (.internaldate, "INTERNALDATE", #line),
            (.rfc822(.header), "RFC822.HEADER", #line),
            (.body(structure: false), "BODY", #line),
            (.body(structure: true), "BODYSTRUCTURE", #line),
            (.bodySection(.text(.header), nil), "BODY[HEADER]", #line),
            (.bodyPeekSection(.text(.header), nil), "BODY.PEEK[HEADER]", #line),
            (.binarySize(section: [1]), "BINARY.SIZE[1]", #line),
            (.binary(peek: true, section: [1, 2, 3], partial: nil), "BINARY.PEEK[1.2.3]", #line),
            (.binary(peek: false, section: [3, 4, 5], partial: nil), "BINARY[3.4.5]", #line),
            (.modSequence(.zero), "0", #line),
            (.modSequence(.value(3)), "3", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeFetchAttribute(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
