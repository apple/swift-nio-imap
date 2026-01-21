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
        ),
    ])
    func encode(_ fixture: EncodeFixture<TaggedResponse>) {
        fixture.checkEncoding()
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
