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

@Suite("SearchReturnData")
struct SearchReturnDataTests {
    @Test(arguments: [
        EncodeFixture.searchReturnData(.min(1), "MIN 1"),
        EncodeFixture.searchReturnData(.max(1), "MAX 1"),
        EncodeFixture.searchReturnData(.all(LastCommandSet.range(1...3)), "ALL 1:3"),
        EncodeFixture.searchReturnData(.count(1), "COUNT 1"),
        EncodeFixture.searchReturnData(.modificationSequence(1), "MODSEQ 1"),
        EncodeFixture.searchReturnData(.partial(.first(23_500...24_000), [67, 100...102]), "PARTIAL (23500:24000 67,100:102)"),
        EncodeFixture.searchReturnData(.partial(.last(55...700), []), "PARTIAL (-55:-700 NIL)"),
        EncodeFixture.searchReturnData(.dataExtension(.init(key: "modifier", value: .sequence(.set([3])))), "modifier 3"),
    ])
    func encode(_ fixture: EncodeFixture<SearchReturnData>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<SearchReturnData> {
    fileprivate static func searchReturnData(
        _ input: SearchReturnData,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeSearchReturnData($1) }
        )
    }
}
