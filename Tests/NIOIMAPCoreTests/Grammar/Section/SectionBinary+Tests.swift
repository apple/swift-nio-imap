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

@Suite("SectionBinary")
struct SectionBinaryTests {
    @Test(arguments: [
        EncodeFixture.sectionBinary([], "[]"),
        EncodeFixture.sectionBinary([123], "[123]"),
        EncodeFixture.sectionBinary([1, 2, 3], "[1.2.3]"),
    ])
    func encode(_ fixture: EncodeFixture<SectionSpecifier.Part>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<SectionSpecifier.Part> {
    fileprivate static func sectionBinary(
        _ input: SectionSpecifier.Part,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeSectionBinary($1) }
        )
    }
}
