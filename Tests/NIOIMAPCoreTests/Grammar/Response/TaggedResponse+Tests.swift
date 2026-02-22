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

@Suite("TaggedResponse")
struct TaggedResponseTests {
    @Test(arguments: [
        EncodeFixture.taggedResponse(
            TaggedResponse(tag: "tag", state: .bad(.init(code: .parse, text: "something"))),
            "tag BAD [PARSE] something\r\n"
        ),
        EncodeFixture.taggedResponse(
            TaggedResponse(tag: "A82", state: .ok(.init(code: nil, text: "LIST completed"))),
            "A82 OK LIST completed\r\n"
        )
    ])
    func encode(_ fixture: EncodeFixture<TaggedResponse>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.taggedResponse(
            "15.16 OK Fetch completed (0.001 + 0.000 secs).\r\n",
            "",
            expected: .success(.init(tag: "15.16", state: .ok(.init(text: "Fetch completed (0.001 + 0.000 secs)."))))
        ),
        ParseFixture.taggedResponse("1+5.16 OK Fetch completed (0.001 \r\n", "", expected: .failure),
        ParseFixture.taggedResponse("15.16 ", "", expected: .incompleteMessage),
        ParseFixture.taggedResponse("15.16 OK Fetch completed (0.001 + 0.000 secs).", "", expected: .incompleteMessage)
    ])
    func parse(_ fixture: ParseFixture<TaggedResponse>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<TaggedResponse> {
    fileprivate static func taggedResponse(
        _ input: TaggedResponse,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeTaggedResponse($1) }
        )
    }
}

extension ParseFixture<TaggedResponse> {
    fileprivate static func taggedResponse(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseTaggedResponse
        )
    }
}
