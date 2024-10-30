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
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import OrderedCollections
import XCTest

class ID_Tests: EncodeTestClass, _ParserTestHelpers {}

// MARK: - Encoding

extension ID_Tests {
    func testEncode() {
        let inputs: [(OrderedDictionary<String, String?>, String, UInt)] = [
            ([:], "NIL", #line),
            (["key": "value"], #"("key" "value")"#, #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeIDParameters($0) })
    }

    func testParse() {
        self.iterateTests(
            testFunction: GrammarParser().parseResponsePayload,
            validInputs: [
                (#"ID NIL"#, "\r", .id([:]), #line),
                (#"ID ("key" NIL)"#, "\r", .id(["key": nil]), #line),
                (#"ID ("name" "Imap" "version" "1.5")"#, "\r", .id(["name": "Imap", "version": "1.5"]), #line),
                (
                    #"ID ("name" "Imap" "version" "1.5" "os" "centos" "os-version" "5.5" "support-url" "mailto:admin@xgen.in")"#,
                    "\r",
                    .id([
                        "name": "Imap", "version": "1.5", "os": "centos", "os-version": "5.5",
                        "support-url": "mailto:admin@xgen.in",
                    ]), #line
                ),
                // datamail.in appends a `+` to the ID response:
                (
                    #"ID ("name" "Imap" "version" "1.5" "os" "centos" "os-version" "5.5" "support-url" "mailto:admin@xgen.in")+"#,
                    "\r",
                    .id([
                        "name": "Imap", "version": "1.5", "os": "centos", "os-version": "5.5",
                        "support-url": "mailto:admin@xgen.in",
                    ]), #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

extension ID_Tests {
    func testThatAnIDResponseDoesNotGetRedactedForLogging() {
        let id = Response.untagged(ResponsePayload.id(["name": "A"]))
        XCTAssertEqual(
            "\(Response.descriptionWithoutPII([id]))",
            #"""
            * ID ("name" "A")\#r

            """#
        )
    }

    func testThatAnIDCommandDoesNotGetRedactedForLogging() {
        let part = CommandStreamPart.tagged(TaggedCommand(tag: "A1", command: .id(["name": "A"])))
        XCTAssertEqual(
            "\(CommandStreamPart.descriptionWithoutPII([part]))",
            #"""
            A1 ID ("name" "A")\#r

            """#
        )
    }
}
