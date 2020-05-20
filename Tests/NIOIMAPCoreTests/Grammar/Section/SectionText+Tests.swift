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

class SectionText_Tests: EncodeTestClass {}

// MARK: - Encoding

extension SectionText_Tests {
    func testEncode() {
        let inputs: [(SectionText, String, UInt)] = [
            (.mime, "MIME", #line),
            (.header, "HEADER", #line),
            (.text, "TEXT", #line),
            (.headerFields(["f1"]), "HEADER.FIELDS (f1)", #line),
            (.headerFields(["f1", "f2", "f3"]), "HEADER.FIELDS (f1 f2 f3)", #line),
            (.notHeaderFields(["n1", "n2"]), "HEADER.FIELDS.NOT (n1 n2)", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeSectionText($0) })
    }
}
