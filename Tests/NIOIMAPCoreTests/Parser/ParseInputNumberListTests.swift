//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import NIOIMAPCore
import Testing

// The fast path must consume exactly the elements the generic grammar would accept as well-formed, and
// stop before anything else, so the generic grammar resumes at the right byte.
extension ParseInputTests {
    @Test(
        "space-separated numbers: reads well-formed elements, stops before the rest",
        arguments: [
            (" 2 10 300\r\n", [2, 10, 300], 9),
            (" 4294967295 1\r\n", [4_294_967_295, 1], 13),
            // Two spaces, a leading zero, zero itself: left to the generic grammar.
            (" 2  10\r\n", [2], 2),
            (" 2 010\r\n", [2], 2),
            (" 2 0\r\n", [2], 2),
            // Too large for a UInt32, by value and by digit count.
            (" 4294967296\r\n", [], 0),
            (" 12345678901\r\n", [], 0),
            // No visible terminator: the number may continue.
            (" 2 10", [2], 2),
            // What may follow a SEARCH result.
            (" 2 (MODSEQ 5)\r\n", [2], 2),
            (" 2 \r\n", [2], 2),
            ("2 3\r\n", [], 0),
            ("", [], 0),
        ] as [(String, [UInt32], Int)]
    )
    func spaceSeparatedNumbers(_ input: String, _ expected: [UInt32], _ consumed: Int) {
        ParseInputHarness.withSpan(input) { buffer in
            var numbers: [UInt32] = []
            let count = buffer.parseSpaceSeparatedNZNumbers { numbers.append($0) }
            #expect(numbers == expected)
            #expect(count == expected.count)
            #expect(buffer.consumed == consumed)
        }
    }

    @Test("space-separated numbers: stops before a number that crosses a region boundary")
    func spaceSeparatedNumbersAcrossRegions() {
        ParseInputHarness.withInput([TestRegion(" 2 1"), TestRegion("0 300\r\n")]) { buffer in
            var numbers: [UInt32] = []
            buffer.parseSpaceSeparatedNZNumbers { numbers.append($0) }
            #expect(numbers == [2])
            #expect(buffer.consumed == 2)
        }
    }
}
