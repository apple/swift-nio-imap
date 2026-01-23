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

@Suite("URLMessageSection")
struct URLMessageSectionTests {
    @Test(arguments: [
        EncodeFixture.urlMessageSection(.init(encodedSection: .init(section: "test")), "/;SECTION=test")
    ])
    func `encode URL message section`(_ fixture: EncodeFixture<URLMessageSection>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        EncodeFixture.urlMessageSectionOnly(.init(encodedSection: .init(section: "test")), ";SECTION=test")
    ])
    func `encode URL message section only`(_ fixture: EncodeFixture<URLMessageSection>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<URLMessageSection> {
    fileprivate static func urlMessageSection(
        _ input: URLMessageSection,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeURLMessageSection($1) }
        )
    }

    fileprivate static func urlMessageSectionOnly(
        _ input: URLMessageSection,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeURLMessageSectionOnly($1) }
        )
    }
}
