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
import Testing
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore

@Suite("InitialResponse")
struct InitialResponseTests {
    @Test(arguments: [
        EncodeFixture.initialResponse(.empty, "="),
        EncodeFixture.initialResponse(.init("base64"), "YmFzZTY0"),
        EncodeFixture.initialResponse(.init("response"), "cmVzcG9uc2U="),
    ])
    func encode(_ fixture: EncodeFixture<InitialResponse>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.initialResponse("=", expected: .success(.empty)),
        ParseFixture.initialResponse("YQ==", expected: .success(.init("a"))),
    ])
    func parse(_ fixture: ParseFixture<InitialResponse>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<InitialResponse> {
    fileprivate static func initialResponse(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeInitialResponse($1) }
        )
    }
}

extension ParseFixture<InitialResponse> {
    fileprivate static func initialResponse(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseInitialResponse
        )
    }
}
