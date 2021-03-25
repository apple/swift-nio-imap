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

import Foundation
import XCTest

import NIO
@testable import NIOIMAP
import NIOIMAPCore
import NIOTestUtils

final class FuzzerTests: XCTestCase {}

extension FuzzerTests {
    
    // all examples found by libfuzzer
    func testCommandParser() {
        let inputs: [[UInt8]] = [
            "+000000000000000000000000000000000000000000000000000000000}\n".utf8.map { $0 },
        ]
        
        for input in inputs {
            var parser = CommandParser()
            do {
                var buffer = ByteBuffer(bytes: input)
                _ = try parser.parseCommandStream(buffer: &buffer)
            } catch {
                // do nothing, we don't care
            }
        }
    }
    
}
