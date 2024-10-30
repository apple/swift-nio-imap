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
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import XCTest

class EncodedSection_Tests: EncodeTestClass {}

// MARK: - Encoding

extension EncodedSection_Tests {
    func testEncode() {
        let inputs: [(EncodedSection, String, UInt)] = [
            (.init(section: "hello"), "hello", #line)
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeEncodedSection($0) })
    }
}
