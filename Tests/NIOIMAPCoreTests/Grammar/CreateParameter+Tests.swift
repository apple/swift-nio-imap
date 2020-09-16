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

class CreateParameter_Tests: EncodeTestClass {}

// MARK: - Encoding

extension CreateParameter_Tests {
    func testEncode() {
        let inputs: [(CreateParameter, String, UInt)] = [
            (.labelled(.init(name: "name")), "name", #line),
            (.labelled(.init(name: "name", value: .sequence([1]))), "name 1", #line),
            (.attributes([]), "USE ()", #line),
            (.attributes([.all]), "USE (\\All)", #line),
            (.attributes([.all, .flagged]), "USE (\\All \\Flagged)", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeCreateParameter($0) })
    }
}
