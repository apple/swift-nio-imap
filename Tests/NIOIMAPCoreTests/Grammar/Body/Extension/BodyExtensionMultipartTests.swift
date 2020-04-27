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

class BodyExtensionMultipartTests: EncodeTestClass {}

// MARK: - Encoding

extension BodyExtensionMultipartTests {
    func testEncode() {
        let inputs: [(NIOIMAP.BodyStructure.ExtensionMultipart, String, UInt)] = [
            (.parameter([.field("f", value: "v")], dspLanguage: nil), "(\"f\" \"v\")", #line),
            (
                .parameter([.field("f1", value: "v1")], dspLanguage: .fieldDSP(.string("string", parameter: [.field("f2", value: "v2")]), fieldLanguage: nil)),
                "(\"f1\" \"v1\") (\"string\" (\"f2\" \"v2\"))",
                #line
            ),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeBodyExtensionMultipart(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
