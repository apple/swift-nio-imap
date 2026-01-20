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

@Suite("ExtendedSearchScopeOptions")
struct ExtendedSearchScopeOptionsTests {
    @Test(arguments: [
        EncodeFixture.extendedSearchScopeOptions(
            ExtendedSearchScopeOptions(["test": nil])!,
            "test"
        ),
        EncodeFixture.extendedSearchScopeOptions(
            ExtendedSearchScopeOptions(["test": .sequence(.lastCommand), "test2": nil])!,
            "test $ test2"
        ),
    ])
    func encode(_ fixture: EncodeFixture<ExtendedSearchScopeOptions>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<ExtendedSearchScopeOptions> {
    fileprivate static func extendedSearchScopeOptions(
        _ input: ExtendedSearchScopeOptions,
        _ expectedString: String
    ) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeExtendedSearchScopeOptions($1) }
        )
    }
}
