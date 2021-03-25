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
            "+000000000000000000000000000000000000000000000000000000000}\n".map { $0.asciiValue! },
            "eSequence468117eY SEARCH 4:1 000,0\n000059?000000600=)O".map { $0.asciiValue! },
            [0x41, 0x5d, 0x20, 0x55, 0x49, 0x44, 0x20, 0x43, 0x4f, 0x50, 0x59, 0x20, 0x35, 0x2c, 0x35, 0x3a, 0x34, 0x00, 0x3d, 0x0c, 0x0a, 0x43, 0x20, 0x22, 0xe8]
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
