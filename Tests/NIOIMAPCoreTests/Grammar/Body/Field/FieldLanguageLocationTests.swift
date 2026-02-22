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

@Suite("BodyStructure.LanguageLocation")
struct FieldLanguageLocationTests {
    @Test(arguments: [
        EncodeFixture.languageLocation(
            .init(languages: ["language"], location: nil),
            " (\"language\")"
        ),
        EncodeFixture.languageLocation(
            .init(languages: ["language"], location: .init(location: "location", extensions: [])),
            " (\"language\") \"location\""
        )
    ])
    func encoding(_ fixture: EncodeFixture<BodyStructure.LanguageLocation>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<BodyStructure.LanguageLocation> {
    fileprivate static func languageLocation(_ input: T, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            expectedString: expectedString,
            encoder: { $0.writeBodyFieldLanguageLocation($1) }
        )
    }
}
