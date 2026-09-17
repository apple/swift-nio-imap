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

@Suite("TextEncoder — Bool")
enum TextEncoderBoolTests {

    /// Bug #5 (fixed): None of the `TextEncoder` containers handled `Bool`, so a `Bool`
    /// fell into the `default` branch, which re-encoded it into a fresh `TextEncoder`;
    /// `Bool.encode(to:)` uses a single-value container, which hit `default` again,
    /// recursing forever until the stack overflowed and the process crashed. The
    /// containers now render `Bool` as `true`/`false`.
    @Test
    static func encodingBoolDoesNotRecurseInfinitely() throws {
        struct Foo: Encodable {
            var name: String
            var enabled: Bool
            var disabled: Bool
        }
        let output = try TextEncoder().encode(Foo(name: "x", enabled: true, disabled: false))
        #expect(
            output == """
                Name: x
                Enabled: true
                Disabled: false

                """
        )
    }
}
