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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import NIO
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import Testing

@Suite("ResponsePayload")
struct ResponsePayloadTests {
    @Test(arguments: [
        EncodeFixture.responsePayload(.capabilityData([.enable]), "CAPABILITY ENABLE"),
        EncodeFixture.responsePayload(.conditionalState(.ok(.init(code: nil, text: "test"))), "OK test"),
        EncodeFixture.responsePayload(.conditionalState(.bye(.init(code: nil, text: "test"))), "BYE test"),
        EncodeFixture.responsePayload(.mailboxData(.exists(1)), "1 EXISTS"),
        EncodeFixture.responsePayload(.messageData(.expunge(2)), "2 EXPUNGE"),
        EncodeFixture.responsePayload(.enableData([.enable]), "ENABLED ENABLE"),
        EncodeFixture.responsePayload(.id(["key": nil]), "ID (\"key\" NIL)"),
        EncodeFixture.responsePayload(.quotaRoot(.init("INBOX"), .init("Root")), "QUOTAROOT \"INBOX\" \"Root\""),
        EncodeFixture.responsePayload(
            .quota(.init("Root"), [.init(resourceName: "STORAGE", usage: 10, limit: 512)]),
            "QUOTA \"Root\" (STORAGE 10 512)"
        ),
        EncodeFixture.responsePayload(.metadata(.list(list: ["a"], mailbox: .inbox)), "METADATA \"INBOX\" \"a\""),
        EncodeFixture.responsePayload(
            .jmapAccess(URL(string: "https://example.com/.well-known/jmap")!),
            #"JMAPACCESS "https://example.com/.well-known/jmap""#
        )
    ])
    func encode(_ fixture: EncodeFixture<ResponsePayload>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.responsePayload("CAPABILITY ENABLE", expected: .success(.capabilityData([.enable]))),
        ParseFixture.responsePayload(
            "BYE test",
            expected: .success(.conditionalState(.bye(.init(code: nil, text: "test"))))
        ),
        ParseFixture.responsePayload(
            "OK test",
            expected: .success(.conditionalState(.ok(.init(code: nil, text: "test"))))
        ),
        ParseFixture.responsePayload("1 EXISTS", expected: .success(.mailboxData(.exists(1)))),
        ParseFixture.responsePayload("2 EXPUNGE", expected: .success(.messageData(.expunge(2)))),
        ParseFixture.responsePayload("ENABLED ENABLE", expected: .success(.enableData([.enable]))),
        ParseFixture.responsePayload("ID (\"key\" NIL)", expected: .success(.id(["key": nil]))),
        ParseFixture.responsePayload(
            "METADATA INBOX a",
            expected: .success(.metadata(.list(list: ["a"], mailbox: .inbox)))
        ),
        ParseFixture.responsePayload(
            #"JMAPACCESS "https://example.com/.well-known/jmap""#,
            expected: .success(.jmapAccess(URL(string: "https://example.com/.well-known/jmap")!))
        ),
        ParseFixture.responsePayload(
            #"JMAPACCESS "http://example.com/.well-known/jmap""#,
            expected: .failureIgnoringBufferModifications
        ),
        ParseFixture.responsePayload(
            #"JMAPACCESS "example.com""#,
            expected: .failureIgnoringBufferModifications
        ),
        ParseFixture.responsePayload(
            "QUOTAROOT INBOX \"Root\"",
            expected: .success(.quotaRoot(.init("INBOX"), .init("Root")))
        ),
        ParseFixture.responsePayload("QUOTAROOT", expected: .failure),
        ParseFixture.responsePayload("QUOTAROOT INBOX", expected: .failure),
        ParseFixture.responsePayload(
            "QUOTA \"Root\" (STORAGE 10 512)",
            expected: .success(.quota(.init("Root"), [QuotaResource(resourceName: "STORAGE", usage: 10, limit: 512)]))
        ),
        ParseFixture.responsePayload(
            "QUOTA \"Root\" (STORAGE 10 512 BEANS 50 100)",
            expected: .success(
                .quota(
                    .init("Root"),
                    [
                        QuotaResource(resourceName: "STORAGE", usage: 10, limit: 512),
                        QuotaResource(resourceName: "BEANS", usage: 50, limit: 100)
                    ]
                )
            )
        ),
        ParseFixture.responsePayload("QUOTA \"Root\" ()", expected: .success(.quota(.init("Root"), []))),
        ParseFixture.responsePayload("QUOTA", expected: .failure),
        ParseFixture.responsePayload("QUOTA \"Root\"", expected: .failure),
        ParseFixture.responsePayload("QUOTA \"Root\" (", expected: .failure),
        ParseFixture.responsePayload("QUOTA \"Root\" (STORAGE", expected: .failure),
        ParseFixture.responsePayload("QUOTA \"Root\" (STORAGE)", expected: .failure),
        ParseFixture.responsePayload("QUOTA \"Root\" (STORAGE 10", expected: .failure),
        ParseFixture.responsePayload("QUOTA \"Root\" (STORAGE 10)", expected: .failure),
        ParseFixture.responsePayload("QUOTA \"Root\" (STORAGE 10 512 BEANS)", expected: .failure)
    ])
    func parse(_ fixture: ParseFixture<ResponsePayload>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<ResponsePayload> {
    fileprivate static func responsePayload(_ input: ResponsePayload, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeResponsePayload($1) }
        )
    }
}

extension ParseFixture<ResponsePayload> {
    fileprivate static func responsePayload(
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
