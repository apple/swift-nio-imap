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

@Suite("SectionPart")
struct SectionPartTests {
    @Test(arguments: [
        EncodeFixture.sectionPart([], ""),
        EncodeFixture.sectionPart([715_472], "715472"),
        EncodeFixture.sectionPart([1, 2, 3, 5, 8, 11], "1.2.3.5.8.11"),
    ])
    func encode(_ fixture: EncodeFixture<SectionSpecifier.Part>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<SectionSpecifier.Part> {
    fileprivate static func sectionPart(
        _ input: SectionSpecifier.Part,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeSectionPart($1) }
        )
    }
}
