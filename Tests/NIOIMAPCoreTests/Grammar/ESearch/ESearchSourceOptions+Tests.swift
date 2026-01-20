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

@Suite("ExtendedSearchSourceOptions")
struct ExtendedSearchSourceOptionsTests {
    @Test(arguments: [
        EncodeFixture.extendedSearchSourceOptions(
            ExtendedSearchSourceOptions(sourceMailbox: [.inboxes])!,
            "IN (inboxes)"
        ),
        EncodeFixture.extendedSearchSourceOptions(
            ExtendedSearchSourceOptions(
                sourceMailbox: [.inboxes],
                scopeOptions: ExtendedSearchScopeOptions(["test": nil])
            )!,
            "IN (inboxes (test))"
        ),
        EncodeFixture.extendedSearchSourceOptions(
            ExtendedSearchSourceOptions(
                sourceMailbox: [.inboxes, .personal],
                scopeOptions: ExtendedSearchScopeOptions(["test": nil])
            )!,
            "IN (inboxes personal (test))"
        ),
    ])
    func encode(_ fixture: EncodeFixture<ExtendedSearchSourceOptions>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<ExtendedSearchSourceOptions> {
    fileprivate static func extendedSearchSourceOptions(
        _ input: ExtendedSearchSourceOptions,
        _ expectedString: String
    ) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeExtendedSearchSourceOptions($1) }
        )
    }
}
