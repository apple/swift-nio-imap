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

@Suite("ConditionalStoreParameter")
struct ConditionalStoreTests {
    @Test("encodes to CONDSTORE")
    func encodesToCondstore() {
        let expected = "CONDSTORE"
        var buffer = EncodeBuffer.serverEncodeBuffer(
            buffer: ByteBufferAllocator().buffer(capacity: 128),
            options: ResponseEncodingOptions(),
            loggingMode: false
        )
        let size = buffer.writeConditionalStoreParameter()
        #expect(size == expected.utf8.count)
        let chunk = buffer.nextChunk()
        #expect(String(buffer: chunk.bytes) == expected)
    }

    @Test(arguments: [
        ParseFixture.conditionalStoreParameter("condstore", " ", expected: .success(Dummy())),
        ParseFixture.conditionalStoreParameter("CONDSTORE", " ", expected: .success(Dummy())),
        ParseFixture.conditionalStoreParameter("condSTORE", " ", expected: .success(Dummy())),
    ])
    fileprivate func parse(_ fixture: ParseFixture<Dummy>) {
        fixture.checkParsing()
    }
}

// MARK: -

/// `Void` / `nil` replacement that is `Equatable`.
private struct Dummy: Equatable {}

extension ParseFixture<Dummy> {
    fileprivate static func conditionalStoreParameter(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: {
                try GrammarParser().parseConditionalStoreParameter(buffer: &$0, tracker: $1)
                return Dummy()
            }
        )
    }
}
