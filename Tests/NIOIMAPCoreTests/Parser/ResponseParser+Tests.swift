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

class ResponseParser_Tests: XCTest {}

// MARK: - init

extension ResponseParser_Tests {
    func testInit_defaultBufferSize() {
        let parser = NIOIMAP.CommandParser()
        XCTAssertEqual(parser.bufferLimit, 1_000)
    }

    func testInit_customBufferSize() {
        let parser = NIOIMAP.CommandParser(bufferLimit: 80_000)
        XCTAssertEqual(parser.bufferLimit, 80_000)
    }
}
