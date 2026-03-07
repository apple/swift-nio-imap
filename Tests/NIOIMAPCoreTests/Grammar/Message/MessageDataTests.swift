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
import Testing

@Suite("MessageData")
struct MessageDataTests {
    @Test(arguments: [
        EncodeFixture.messageData(.expunge(123), "123 EXPUNGE"),
        EncodeFixture.messageData(.vanished(.all), "VANISHED 1:*"),
        EncodeFixture.messageData(.vanishedEarlier(.all), "VANISHED (EARLIER) 1:*"),
        EncodeFixture.messageData(.generateAuthorizedURL(["test"]), #"GENURLAUTH "test""#),
        EncodeFixture.messageData(.generateAuthorizedURL(["test1", "test2"]), #"GENURLAUTH "test1" "test2""#),
        EncodeFixture.messageData(.urlFetch([.init(url: "url", data: nil)]), #"URLFETCH("url" NIL)"#),
        EncodeFixture.messageData(
            .urlFetch([.init(url: "url1", data: nil), .init(url: "url2", data: "data")]),
            #"URLFETCH("url1" NIL "url2" "data")"#
        ),
    ])
    func encode(_ fixture: EncodeFixture<MessageData>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        EncodeFixture.messageDataEnd(.expunge(1), ")")
    ])
    func encodeEnd(_ fixture: EncodeFixture<MessageData>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.messageData("3 EXPUNGE", expected: .success(.expunge(3))),
        ParseFixture.messageData("VANISHED 1:3", expected: .success(.vanished([1...3]))),
        ParseFixture.messageData("VANISHED (EARLIER) 1:3", expected: .success(.vanishedEarlier([1...3]))),
        ParseFixture.messageData("GENURLAUTH test", expected: .success(.generateAuthorizedURL(["test"]))),
        ParseFixture.messageData(
            "GENURLAUTH test1 test2",
            expected: .success(.generateAuthorizedURL(["test1", "test2"]))
        ),
        ParseFixture.messageData("URLFETCH url NIL", expected: .success(.urlFetch([.init(url: "url", data: nil)]))),
        ParseFixture.messageData(
            "URLFETCH url1 NIL url2 NIL url3 \"data\"",
            expected: .success(
                .urlFetch([
                    .init(url: "url1", data: nil), .init(url: "url2", data: nil), .init(url: "url3", data: "data"),
                ])
            )
        ),
    ])
    func parse(_ fixture: ParseFixture<MessageData>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<MessageData> {
    fileprivate static func messageData(
        _ input: MessageData,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeMessageData($1) }
        )
    }

    fileprivate static func messageDataEnd(
        _ input: MessageData,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeMessageDataEnd($1) }
        )
    }
}

extension ParseFixture<MessageData> {
    fileprivate static func messageData(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseMessageData
        )
    }
}
