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

class URLMessageSection_Tests: EncodeTestClass {}

// MARK: - IMAP

extension URLMessageSection_Tests {
    func testEncode_URLMessageSection() {
        let inputs: [(URLMessageSection, String, UInt)] = [
            (.init(encodedSection: .init(section: "test")), "/;SECTION=test", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeURLMessageSection($0) })
    }

    func testEncode_URLMessageSectionOnly() {
        let inputs: [(URLMessageSection, String, UInt)] = [
            (.init(encodedSection: .init(section: "test")), ";SECTION=test", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeURLMessageSectionOnly($0) })
    }
}
