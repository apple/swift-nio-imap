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
            Array("+000000000000000000000000000000000000000000000000000000000}\n".utf8),
            Array("eSequence468117eY SEARCH 4:1 000,0\n000059?000000600=)O".utf8),
            [0x41, 0x5D, 0x20, 0x55, 0x49, 0x44, 0x20, 0x43, 0x4F, 0x50, 0x59, 0x20, 0x35, 0x2C, 0x35, 0x3A, 0x34, 0x00, 0x3D, 0x0C, 0x0A, 0x43, 0x20, 0x22, 0xE8],
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
