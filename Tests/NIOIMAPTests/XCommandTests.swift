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

import XCTest
import NIO
@testable import NIOIMAP

class XCommandTests: XCTestCase {
    
}

// MARK: Equatable
extension XCommandTests {
    
    func testEquatable_matched_case() {
        let x1 = NIOIMAP.XCommand("HELLO")
        let x2 = NIOIMAP.XCommand("HELLO")
        XCTAssertEqual(x1, x2)
    }
    
    func testEquatable_invalid() {
        let x1 = NIOIMAP.XCommand("HELLO")
        let x2 = NIOIMAP.XCommand("google")
        XCTAssertNotEqual(x1, x2)
    }
    
}

// MARK: String literal
extension XCommandTests {

    func testInitStringLiteral() {
        let x1 = NIOIMAP.XCommand("apple")
        XCTAssertEqual(x1, "apple")
    }
    
}
