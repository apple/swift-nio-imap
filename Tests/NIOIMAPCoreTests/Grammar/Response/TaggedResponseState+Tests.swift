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

@Suite("TaggedResponse.State")
struct TaggedResponseStateTests {
    @Test(arguments: [
        EncodeFixture.taggedResponseState(
            .bad(.init(code: .parse, text: "something")),
            "BAD [PARSE] something"
        ),
        EncodeFixture.taggedResponseState(
            .ok(.init(code: .alert, text: "error")),
            "OK [ALERT] error"
        ),
        EncodeFixture.taggedResponseState(
            .no(.init(code: .readOnly, text: "everything")),
            "NO [READ-ONLY] everything"
        ),
        EncodeFixture.taggedResponseState(
            .ok(.init(code: nil, text: "Completed")),
            "OK Completed"
        ),
        EncodeFixture.taggedResponseState(
            .ok(.init(code: nil, text: "")),
            "OK  "
        ),
    ])
    func encode(_ fixture: EncodeFixture<TaggedResponse.State>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<TaggedResponse.State> {
    fileprivate static func taggedResponseState(
        _ input: TaggedResponse.State,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeTaggedResponseState($1) }
        )
    }
}
