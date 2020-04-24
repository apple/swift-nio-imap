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

class NamespaceResponse_Tests: EncodeTestClass {}

// MARK: - Encoding

extension NamespaceResponse_Tests {
    func testEncode() {
        let inputs: [(NIOIMAP.NamespaceResponse, String, UInt)] = [
            (.userNamespace([], otherUserNamespace: [], sharedNamespace: []), "NAMESPACE NIL NIL NIL", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeNamespaceResponse(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
