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

class IMAPURLSection_Tests: EncodeTestClass {}

// MARK: - IMAP

extension IMAPURLSection_Tests {
    func testEncode_IMAPURLSection() {
        let inputs: [(IMAPURLSection, String, UInt)] = [
            (.init(encodedSection: .init(section: "test")), "/;SECTION=test", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeIMAPURLSection($0) })
    }

    func testEncode_IMAPURLSectionOnly() {
        let inputs: [(IMAPURLSection, String, UInt)] = [
            (.init(encodedSection: .init(section: "test")), ";SECTION=test", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeIMAPURLSectionOnly($0) })
    }
}
