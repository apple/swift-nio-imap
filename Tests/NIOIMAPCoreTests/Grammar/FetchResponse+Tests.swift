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

@Suite("FetchResponse")
struct FetchResponseTests {
    @Test(arguments: [
        ParseFixture.fetchResponse("UID 54", " ", expected: .success(.simpleAttribute(.uid(54)))),
        ParseFixture.fetchResponse("RFC822.SIZE 40639", " ", expected: .success(.simpleAttribute(.rfc822Size(40639)))),
        ParseFixture.fetchResponse("FLAGS ()", " ", expected: .success(.simpleAttribute(.flags([])))),
        ParseFixture.fetchResponse("FLAGS (\\seen)", " ", expected: .success(.simpleAttribute(.flags([.seen])))),
        ParseFixture.fetchResponse(
            "FLAGS (\\seen \\answered \\draft)",
            " ",
            expected: .success(.simpleAttribute(.flags([.seen, .answered, .draft])))
        ),
        ParseFixture.fetchResponse(")\r\n", " ", expected: .success(.finish)),
        ParseFixture.fetchResponse(
            #"PREVIEW "Lorem ipsum dolor sit amet""#,
            " ",
            expected: .success(.simpleAttribute(.preview(.init("Lorem ipsum dolor sit amet"))))
        ),
        ParseFixture.fetchResponse("PREVIEW NIL", " ", expected: .success(.simpleAttribute(.preview(nil)))),
    ])
    func parse(_ fixture: ParseFixture<GrammarParser._FetchResponse>) {
        fixture.checkParsing()
    }

    @Test(arguments: [
        ParseFixture.fetchResponseStart("* 1 FETCH (", " ", expected: .success(.start(1))),
        ParseFixture.fetchResponseStart("* 1 UIDFETCH (", " ", expected: .success(.startUID(1))),
    ])
    func `parse start`(_ fixture: ParseFixture<GrammarParser._FetchResponse>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension ParseFixture<GrammarParser._FetchResponse> {
    fileprivate static func fetchResponse(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseFetchResponse
        )
    }

    fileprivate static func fetchResponseStart(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseFetchResponseStart
        )
    }
}
