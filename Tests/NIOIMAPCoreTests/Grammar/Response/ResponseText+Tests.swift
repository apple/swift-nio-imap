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

@Suite("ResponseText")
struct ResponseTextTests {
    @Test(arguments: [
        EncodeFixture.responseText(.init(code: nil, text: "buffer"), "buffer"),
        EncodeFixture.responseText(.init(code: .alert, text: "buffer"), "[ALERT] buffer"),
        EncodeFixture.responseText(.init(code: nil, text: ""), " "),
        EncodeFixture.responseText(.init(code: .alert, text: ""), "[ALERT]  "),
    ])
    func encode(_ fixture: EncodeFixture<ResponseText>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.responseText("", expected: .success(.init(code: nil, text: ""))),
        ParseFixture.responseText(" ", expected: .success(.init(code: nil, text: ""))),
        ParseFixture.responseText("text", expected: .success(.init(code: nil, text: "text"))),
        ParseFixture.responseText(" text", expected: .success(.init(code: nil, text: "text"))),
        ParseFixture.responseText("[UNSEEN 1]", expected: .success(.init(code: .unseen(1), text: ""))),
        ParseFixture.responseText("[UNSEEN 2] ", expected: .success(.init(code: .unseen(2), text: ""))),
        ParseFixture.responseText("[UNSEEN 2] some text", expected: .success(.init(code: .unseen(2), text: "some text"))),
        ParseFixture.responseText("[UIDVALIDITY 1561789793]", expected: .success(.init(code: .uidValidity(1_561_789_793), text: ""))),
        ParseFixture.responseText("[UIDNEXT 171]", expected: .success(.init(code: .uidNext(171), text: ""))),
    ])
    func parse(_ fixture: ParseFixture<ResponseText>) {
        fixture.checkParsing()
    }

    @Test(arguments: [
        DebugStringFixture(sut: ResponseText(code: nil, text: "buffer"), expected: "buffer"),
        DebugStringFixture(sut: ResponseText(code: .alert, text: "buffer"), expected: "[ALERT] buffer"),
    ])
    func `custom debug string convertible`(_ fixture: DebugStringFixture<ResponseText>) {
        fixture.check()
    }
}

// MARK: -

extension EncodeFixture<ResponseText> {
    fileprivate static func responseText(
        _ input: ResponseText,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeResponseText($1) }
        )
    }
}

extension ParseFixture<ResponseText> {
    fileprivate static func responseText(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseResponseText
        )
    }
}
