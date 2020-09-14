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

class AttributeFlag_Tests: EncodeTestClass {}

// MARK: - Encoding

extension AttributeFlag_Tests {
    func testEncoding() {
        let inputs: [(AttributeFlag, String, UInt)] = [
            (.answered, "\\\\Answered", #line),
            (.deleted, "\\\\Deleted", #line),
            (.draft, "\\\\Draft", #line),
            (.flagged, "\\\\Flagged", #line),
            (.seen, "\\\\Seen", #line),
            (.init(rawValue: "test"), "test", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeAttributeFlag($0) })
    }
}
