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

import Foundation
@testable import IMAPToolLib
import Testing

@Suite
private enum TextEncoderTests {
    @Test
    static func encodingSingleString() throws {
        let output = try TextEncoder().encode("Foo Bar")
        #expect(output == "Foo Bar\n")
    }

    @Test
    static func encodingIntegerArray() throws {
        let output = try TextEncoder().encode([1, 2, 3])
        #expect(output == "1\n2\n3\n")
    }

    @Test
    static func encodingSimpleStruct() throws {
        struct Foo: Encodable {
            var name: String
            var age: Int
        }
        let output = try TextEncoder().encode(Foo(name: "Bar", age: 42))
        #expect(
            output == """
                Name: Bar
                Age: 42

                """
        )
    }

    @Test
    static func encodingSingleElementArrayOfStruct() throws {
        struct Foo: Encodable {
            var a: String
            var b: Int
        }
        let output = try TextEncoder().encode([Foo(a: "Bar", b: 42)])
        #expect(
            output == """
                A: Bar
                B: 42

                """
        )
    }

    @Test
    static func encodingArrayOfStruct() throws {
        struct Foo: Encodable {
            var a: String
            var b: Int
        }
        let output = try TextEncoder().encode([Foo(a: "Bar", b: 42), Foo(a: "Baz", b: 7)])
        #expect(
            output == """
                A: Bar
                B: 42

                A: Baz
                B: 7

                """,
            "The structs should be separated by a newline."
        )
    }

    @Test
    static func encodingNestedStructs() throws {
        struct Foo: Encodable {
            var name: String
            var age: Int
        }
        struct Bar: Encodable {
            var a: Foo
            var b: String
        }
        let bar = Bar(a: Foo(name: "baz", age: 42), b: "BB")
        let output = try TextEncoder().encode(bar)
        #expect(
            output == """
                A:
                    Name: baz
                    Age: 42
                B: BB

                """
        )
    }

    @Test
    static func encodingArrayOfFloats() throws {
        struct Foo: Encodable {
            var a: String
            var b: [Double]
        }
        let bar = Foo(a: "Hello", b: [1, 2, 3])
        let output = try TextEncoder().encode(bar)
        #expect(
            output == """
                A: Hello
                B: [1.0, 2.0, 3.0]

                """
        )
    }

    @Test
    static func encodingArrayOfIntegers() throws {
        struct Foo: Encodable {
            var a: String
            var b: [Int]
        }
        let bar = Foo(a: "Hello", b: [1, 2, 3])
        let output = try TextEncoder().encode(bar)
        #expect(
            output == """
                A: Hello
                B: [1, 2, 3]

                """
        )
    }

    @Test
    static func keyMapping() throws {
        struct Foo: Encodable {
            var a: Int
            var b: Int
            var c: Int
            var d: Int

            enum CodingKeys: String, CodingKey {
                case a = "name"
                case b = "publicHeadersPath"
                case c = "c99name"
                case d = "a80Width"
            }
        }
        let output = try TextEncoder().encode(Foo(a: 1, b: 2, c: 3, d: 4))
        #expect(
            output == """
                Name: 1
                Public headers path: 2
                C99name: 3
                A80 width: 4

                """
        )
    }
}
