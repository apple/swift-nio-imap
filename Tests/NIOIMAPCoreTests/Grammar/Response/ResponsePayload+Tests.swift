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
        ),
    ])
    func encode(_ fixture: EncodeFixture<ResponsePayload>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<ResponsePayload> {
    fileprivate static func responsePayload(_ input: ResponsePayload, _ expectedString: String) -> Self {
        EncodeFixture(input: input, bufferKind: .defaultServer, expectedString: expectedString, encoder: { $0.writeResponsePayload($1) })
    }
}
