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

@Suite("SearchCriteria")
struct SearchCriteriaTests {
    @Test(arguments: [
        EncodeFixture.searchCriteria([.all], "ALL"),
        EncodeFixture.searchCriteria([.all, .answered, .deleted], "ALL ANSWERED DELETED"),
    ])
    func encode(_ fixture: EncodeFixture<[SearchKey]>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<[SearchKey]> {
    fileprivate static func searchCriteria(
        _ input: [SearchKey],
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeSearchCriteria($1) }
        )
    }
}
