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

class ListSelectOption_Tests: EncodeTestClass {}

// MARK: - Encoding

extension ListSelectOption_Tests {
    func testEncode() {
        let inputs: [(ListSelectOption, String, UInt)] = [
            (.base(.subscribed), "SUBSCRIBED", #line),
            (.independent(.remote), "REMOTE", #line),
            (.modified(.recursiveMatch), "RECURSIVEMATCH", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeListSelectOption($0) })
    }

    func testEncode_multiple() {
        let inputs: [(ListSelectOptions?, String, UInt)] = [
            (nil, "()", #line),
            (.init(baseOption: .subscribed, options: [.base(.subscribed)]), "(SUBSCRIBED SUBSCRIBED)", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeListSelectOptions($0) })
    }
}
