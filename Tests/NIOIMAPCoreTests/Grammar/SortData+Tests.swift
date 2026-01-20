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

@Suite("SortData")
struct SortDataTests {
    @Test(arguments: [
        EncodeFixture.sortData(
            nil,
            "SORT"
        ),
        EncodeFixture.sortData(
            .init(identifiers: [1], modificationSequence: 2),
            "SORT 1 (MODSEQ 2)"
        ),
    ])
    func encode(_ fixture: EncodeFixture<SortData?>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<SortData?> {
    fileprivate static func sortData(
        _ input: SortData?,
        _ expectedString: String
    ) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeSortData($1) }
        )
    }
}
