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

class URLRumpMechanism_Tests: EncodeTestClass {}

// MARK: - Encoding

extension URLRumpMechanism_Tests {
    func testEncode() {
        let inputs: [(RumpURLAndMechanism, String, UInt)] = [
            (.init(urlRump: "test", mechanism: .internal), "\"test\" INTERNAL", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeURLRumpMechanism($0) })
    }
}
