//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2023 Apple Inc. and the SwiftNIO project authors
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

@Suite("PartialRange")
struct PartialRangeTests {
    @Test(arguments: [
        EncodeFixture.partialRange(.first(1...1), "1:1"),
        EncodeFixture.partialRange(.first(100...200), "100:200"),
        EncodeFixture.partialRange(.last(1...1), "-1:-1"),
        EncodeFixture.partialRange(.last(100...200), "-100:-200"),
    ])
    func encode(_ fixture: EncodeFixture<PartialRange>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.partialRange("1:2", " ", expected: .success(.first(1...2))),
        ParseFixture.partialRange("1:1", " ", expected: .success(.first(1...1))),
        ParseFixture.partialRange("100:200", " ", expected: .success(.first(100...200))),
        ParseFixture.partialRange("200:100", " ", expected: .success(.first(100...200))),
        ParseFixture.partialRange("333:333", " ", expected: .success(.first(333...333))),
        ParseFixture.partialRange("1234567:2345678", " ", expected: .success(.first(1_234_567...2_345_678))),
        ParseFixture.partialRange("-1:-2", " ", expected: .success(.last(1...2))),
        ParseFixture.partialRange("-1:-1", " ", expected: .success(.last(1...1))),
        ParseFixture.partialRange("-100:-200", " ", expected: .success(.last(100...200))),
        ParseFixture.partialRange("-200:-100", " ", expected: .success(.last(100...200))),
        ParseFixture.partialRange("-333:-333", " ", expected: .success(.last(333...333))),
        ParseFixture.partialRange("-1234567:-2345678", " ", expected: .success(.last(1_234_567...2_345_678))),
        ParseFixture.partialRange("1", " ", expected: .failure),
        ParseFixture.partialRange("1:", " ", expected: .failure),
        ParseFixture.partialRange("10:-20", " ", expected: .failure),
        ParseFixture.partialRange("-10:20", " ", expected: .failure),
        ParseFixture.partialRange("1:*", " ", expected: .failure),
        ParseFixture.partialRange("*", " ", expected: .failure),
        ParseFixture.partialRange("a", " ", expected: .failure),
        ParseFixture.partialRange("1", "", expected: .incompleteMessage),
        ParseFixture.partialRange("1:", "", expected: .incompleteMessage),
        ParseFixture.partialRange("1:2", "", expected: .incompleteMessage),
    ])
    func parse(_ fixture: ParseFixture<PartialRange>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<PartialRange> {
    fileprivate static func partialRange(
        _ input: PartialRange,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writePartialRange($1) }
        )
    }
}

extension ParseFixture<PartialRange> {
    fileprivate static func partialRange(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parsePartialRange
        )
    }
}
