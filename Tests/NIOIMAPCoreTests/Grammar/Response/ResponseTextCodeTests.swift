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

class ResponseTextCodeTests: EncodeTestClass {}

// MARK: - Encoding

extension ResponseTextCodeTests {
    func testEncode() {
        let inputs: [(NIOIMAP.ResponseTextCode, String, UInt)] = [
            (.alert, "ALERT", #line),
            (.parse, "PARSE", #line),
            (.readOnly, "READ-ONLY", #line),
            (.readWrite, "READ-WRITE", #line),
            (.tryCreate, "TRYCREATE", #line),
            (.uidNext(123), "UIDNEXT 123", #line),
            (.uidValidity(234), "UIDVALIDITY 234", #line),
            (.unseen(345), "UNSEEN 345", #line),
            (.badCharset(["some", "string"]), "BADCHARSET (some string)", #line),
            (.permanentFlags([.wildcard]), #"PERMANENTFLAGS (\*)"#, #line),
            (.permanentFlags([.wildcard, .wildcard]), #"PERMANENTFLAGS (\* \*)"#, #line),
            (.permanentFlags([.flag(.deleted), .flag(.draft)]), #"PERMANENTFLAGS (\DELETED \DRAFT)"#, #line),
            (.other("some", nil), "some", #line),
            (.other("some", "thing"), "some thing", #line),
            (.capability([]), "CAPABILITY IMAP4 IMAP4rev1", #line),
            (.capability([.unselect]), "CAPABILITY IMAP4 IMAP4rev1 UNSELECT", #line),
            (.capability([.unselect, .binary, .children]), "CAPABILITY IMAP4 IMAP4rev1 UNSELECT BINARY CHILDREN", #line),
            (.namespace(.userNamespace([], otherUserNamespace: [], sharedNamespace: [])), "NAMESPACE NIL NIL NIL", #line),
        ]

        for (code, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeResponseTextCode(code)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
