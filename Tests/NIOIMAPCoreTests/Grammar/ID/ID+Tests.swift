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
import Testing

@Suite("ID")
struct IDTests {
    @Test(arguments: [
        EncodeFixture.idParameters([:], "NIL"),
        EncodeFixture.idParameters(["key": "value"], #"("key" "value")"#),
    ])
    func encode(_ fixture: EncodeFixture<OrderedDictionary<String, String?>>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.idResponsePayload(#"ID NIL"#, expected: .success(.id([:]))),
        ParseFixture.idResponsePayload(#"ID ("key" NIL)"#, expected: .success(.id(["key": nil]))),
        ParseFixture.idResponsePayload(
            #"ID ("name" "Imap" "version" "1.5")"#,
            expected: .success(.id(["name": "Imap", "version": "1.5"]))
        ),
        ParseFixture.idResponsePayload(
            #"ID ("name" "Imap" "version" "1.5" "os" "centos" "os-version" "5.5" "support-url" "mailto:admin@xgen.in")"#,
            expected: .success(.id([
                "name": "Imap", "version": "1.5", "os": "centos", "os-version": "5.5",
                "support-url": "mailto:admin@xgen.in",
            ]))
        ),
        // datamail.in appends a `+` to the ID response:
        ParseFixture.idResponsePayload(
            #"ID ("name" "Imap" "version" "1.5" "os" "centos" "os-version" "5.5" "support-url" "mailto:admin@xgen.in")+"#,
            expected: .success(.id([
                "name": "Imap", "version": "1.5", "os": "centos", "os-version": "5.5",
                "support-url": "mailto:admin@xgen.in",
            ]))
        ),
    ])
    func parse(_ fixture: ParseFixture<ResponsePayload>) {
        fixture.checkParsing()
    }

    @Test func `ID response does not get redacted for logging`() {
        let id = Response.untagged(ResponsePayload.id(["name": "A"]))
        #expect(
            "\(Response.descriptionWithoutPII([id]))" ==
            #"""
            * ID ("name" "A")\#r

            """#
        )
    }

    @Test func `ID command does not get redacted for logging`() {
        let part = CommandStreamPart.tagged(TaggedCommand(tag: "A1", command: .id(["name": "A"])))
        #expect(
            "\(CommandStreamPart.descriptionWithoutPII([part]))" ==
            #"""
            A1 ID ("name" "A")\#r

            """#
        )
    }
}

// MARK: -

extension EncodeFixture<OrderedDictionary<String, String?>> {
    fileprivate static func idParameters(
        _ input: OrderedDictionary<String, String?>,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeIDParameters($1) }
        )
    }
}

extension ParseFixture<ResponsePayload> {
    fileprivate static func idResponsePayload(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseResponsePayload
        )
    }
}
