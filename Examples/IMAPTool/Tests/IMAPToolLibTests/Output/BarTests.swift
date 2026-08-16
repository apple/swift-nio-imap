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

@testable import IMAPToolLib
import Testing

@Suite
private enum BarTests {
    @Test
    static func barWithWidth4() {
        #expect(String.bar(fraction: -1.5, width: 4) == "    ")
        #expect(String.bar(fraction: 0.00, width: 4) == "    ")
        #expect(String.bar(fraction: 0.25, width: 4) == "█   ")
        #expect(String.bar(fraction: 0.50, width: 4) == "██  ")
        #expect(String.bar(fraction: 0.75, width: 4) == "███ ")
        #expect(String.bar(fraction: 1.00, width: 4) == "████")
        #expect(String.bar(fraction: 1.50, width: 4) == "████")

        #expect(String.bar(fraction: 0.11, width: 4) == "▌   ")
        #expect(String.bar(fraction: 0.19, width: 4) == "▊   ")
        #expect(String.bar(fraction: 0.23, width: 4) == "▉   ")
        #expect(String.bar(fraction: 0.33, width: 4) == "█▍  ")
        #expect(String.bar(fraction: 0.62, width: 4) == "██▌ ")
        #expect(String.bar(fraction: 0.91, width: 4) == "███▋")
        #expect(String.bar(fraction: 0.98, width: 4) == "███▉")
    }

    @Test
    static func barWithLabel() {
        #expect(String.barWithLabel(fraction: 0.110, width: 20) == "██▎              11%")
        #expect(String.barWithLabel(fraction: 0.190, width: 20) == "███▊             19%")
        #expect(String.barWithLabel(fraction: 0.207, width: 20) == "████▏          20.7%")
        #expect(String.barWithLabel(fraction: 0.230, width: 20) == "████▋            23%")
        #expect(String.barWithLabel(fraction: 0.330, width: 20) == "██████▋          33%")
        #expect(String.barWithLabel(fraction: 0.492, width: 20) == "█████████▉     49.2%")
        #expect(String.barWithLabel(fraction: 0.620, width: 20) == "█62%████████▍       ")
        #expect(String.barWithLabel(fraction: 0.910, width: 20) == "█91%██████████████▎ ")
        #expect(String.barWithLabel(fraction: 0.912, width: 20) == "█91.2%████████████▎ ")
        #expect(String.barWithLabel(fraction: 0.980, width: 20) == "█98%███████████████▋")
    }

    /// A zero or negative width must not trap (e.g. when a long label drives the
    /// available bar width non-positive).
    @Test
    static func barWithNonPositiveWidth() {
        #expect(String.bar(fraction: 0.5, width: 0) == "")
        #expect(String.bar(fraction: 0.5, width: -1) == "")
        #expect(String.bar(fraction: 0.5, width: -100) == "")
    }

    /// A width too small to hold a label falls back to the plain bar rather than
    /// trapping on out-of-range string indexing.
    @Test
    static func barWithLabelNarrowWidth() {
        // width < 11 -> plain bar, no label.
        #expect(String.barWithLabel(fraction: 0.5, width: 4) == "██  ")
        #expect(String.barWithLabel(fraction: 0.5, width: 0) == "")
        #expect(String.barWithLabel(fraction: 0.5, width: -5) == "")
    }
}
