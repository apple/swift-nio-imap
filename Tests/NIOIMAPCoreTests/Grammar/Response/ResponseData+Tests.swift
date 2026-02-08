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

@Suite("ResponsePayload")
struct ResponseDataTests {
    @Test(arguments: [
        EncodeFixture.responsePayload(.messageData(.expunge(3)), "* 3 EXPUNGE\r\n"),
        EncodeFixture.responsePayload(.messageData(.vanished([42, 77])), "* VANISHED 42,77\r\n"),
    ])
    func encode(_ fixture: EncodeFixture<ResponsePayload>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.responseData(
            "* CAPABILITY ENABLE\r\n",
            expected: .success(.capabilityData([.enable]))
        ),
        ParseFixture.responseData(
            "* 3 EXPUNGE\r\n",
            expected: .success(.messageData(.expunge(3)))
        ),
    ])
    func parse(_ fixture: ParseFixture<ResponsePayload>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<ResponsePayload> {
    fileprivate static func responsePayload(
        _ input: ResponsePayload,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeResponseData($1) }
        )
    }
}

extension ParseFixture<ResponsePayload> {
    fileprivate static func responseData(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseResponseData
        )
    }
}
