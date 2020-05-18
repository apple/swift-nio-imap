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

class BodyStructure_Tests: EncodeTestClass {}

// MARK: - init

extension BodyStructure_Tests {
    func testInit_mediaSubtype() {
        let type = BodyStructure.MediaSubtype("TYPE")
        XCTAssertEqual(type._backing, "type")
    }
}

// MARK: - Encoding

extension BodyStructure_Tests {
    func testEncode_mediaSubtype() {
        let inputs: [(BodyStructure.MediaSubtype, String, UInt)] = [
            (.related, #""multipart/related""#, #line),
            (.mixed, #""multipart/mixed""#, #line),
            (.alternative, #""multipart/alternative""#, #line),
            (.init("other"), #""other""#, #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeMediaSubtype($0) })
    }
}
