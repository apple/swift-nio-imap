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

import IMAPCommands
import Foundation
import NIOIMAP
@testable import IMAPToolLib
import Testing

@Suite
private enum TextInterpolationTests {
    @Test
    static func interpolation() {
        #expect(output("foo") == "foo")
        #expect(output("foo \("A")") == "foo A")
        #expect(output("\(5938)") == "5,938")

        #expect(output("\(1.2 as TimeInterval)") == "1,200 ms")
        #expect(output("\(0.0224 as TimeInterval)") == "22 ms")
        #expect(output("\(0.0225 as TimeInterval)") == "23 ms")
        #expect(output("\(0.0226 as TimeInterval)") == "23 ms")

        #expect(output("\(572 as UID)") == "572")
        #expect(output("\(ResponseText(code: nil, text: "Foo Bar"))") == "Foo Bar")
        #expect(output("\(ResponseText(code: .alert, text: "Foo Bar"))") == "ALERT Foo Bar")

        #expect(output("\(IMAPConnection.Tag.first)") == "A1")
    }
}

private func output(_ o: Output) -> String {
    o.text
}
