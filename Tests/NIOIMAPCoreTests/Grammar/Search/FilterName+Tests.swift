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

@Suite("FilterName")
struct FilterNameTests {
    @Test(arguments: [
        ParseFixture.filterName("a", " ", expected: .success("a")),
        ParseFixture.filterName("abcdefg", " ", expected: .success("abcdefg"))
    ])
    func parse(_ fixture: ParseFixture<String>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension ParseFixture<String> {
    fileprivate static func filterName(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseFilterName
        )
    }
}
