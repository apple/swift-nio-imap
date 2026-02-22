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
            expected: .success(
                .id([
                    "name": "Imap", "version": "1.5", "os": "centos", "os-version": "5.5",
                    "support-url": "mailto:admin@xgen.in",
                ])
            )
        ),
        // datamail.in appends a `+` to the ID response:
        ParseFixture.idResponsePayload(
            #"ID ("name" "Imap" "version" "1.5" "os" "centos" "os-version" "5.5" "support-url" "mailto:admin@xgen.in")+"#,
            expected: .success(
                .id([
                    "name": "Imap", "version": "1.5", "os": "centos", "os-version": "5.5",
                    "support-url": "mailto:admin@xgen.in",
                ])
            )
        ),
    ])
    func parse(_ fixture: ParseFixture<ResponsePayload>) {
        fixture.checkParsing()
    }

    @Test("ID response does not get redacted for logging")
    func idResponseDoesNotGetRedactedForLogging() {
        let id = Response.untagged(ResponsePayload.id(["name": "A"]))
        #expect(
            "\(Response.descriptionWithoutPII([id]))" == #"""
                * ID ("name" "A")\#r

                """#
        )
    }

    @Test("ID command does not get redacted for logging")
    func idCommandDoesNotGetRedactedForLogging() {
        let part = CommandStreamPart.tagged(TaggedCommand(tag: "A1", command: .id(["name": "A"])))
        #expect(
            "\(CommandStreamPart.descriptionWithoutPII([part]))" == #"""
                A1 ID ("name" "A")\#r

                """#
        )
    }

    @Test(
        "parse ID params list",
        arguments: [
            ParseFixture.idParamsList("NIL", " ", expected: .success([:])),
            ParseFixture.idParamsList("()", " ", expected: .success([:])),
            ParseFixture.idParamsList("( )", " ", expected: .success([:])),
            ParseFixture.idParamsList(#"("key1" "value1")"#, "", expected: .success(["key1": "value1"])),
            ParseFixture.idParamsList(
                #"("key1" "value1" "key2" "value2" "key3" "value3")"#,
                "",
                expected: .success(["key1": "value1", "key2": "value2", "key3": "value3"])
            ),
            ParseFixture.idParamsList(
                #"("key1" "&AKM-" "flag" "&2Dzf9NtA3GfbQNxi20DcZdtA3G7bQNxn20Dcfw-")"#,
                "",
                expected: .success(["key1": "£", "flag": "🏴󠁧󠁢󠁥󠁮󠁧󠁿"])
            ),
            ParseFixture.idParamsList(
                #"("a" "1" "b" "2")"#,
                "",
                expected: .success(["a": "1", "b": "2"])
            ),
            ParseFixture.idParamsList(
                #"( "a" "1" "b" "2" )"#,
                "",
                expected: .success(["a": "1", "b": "2"])
            ),
            ParseFixture.idParamsList(
                #"("a"  "1"  "b"   "2")"#,
                "",
                expected: .success(["a": "1", "b": "2"])
            ),
        ]
    )
    func parseIDParamsList(_ fixture: ParseFixture<OrderedDictionary<String, String?>>) {
        fixture.checkParsing()
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

extension ParseFixture<OrderedDictionary<String, String?>> {
    fileprivate static func idParamsList(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseIDParamsList
        )
    }
}
