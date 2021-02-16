//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2021 Apple Inc. and the SwiftNIO project authors
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

class InternetMessageDate_Tests: EncodeTestClass {}

extension InternetMessageDate_Tests {
    func testEncode() {
        self.iterateInputs(
            inputs: [(.init("test"), "test", #line)],
            encoder: { self.testBuffer.writeInternetMessageDate($0) }
        )
    }
}
