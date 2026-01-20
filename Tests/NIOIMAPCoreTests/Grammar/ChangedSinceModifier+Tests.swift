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
import Testing
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore

@Suite("ChangedSinceModifier")
struct ChangedSinceModifierTests {
    @Test(arguments: [
        EncodeFixture.changedSinceModifier(.init(modificationSequence: 3), "CHANGEDSINCE 3"),
        EncodeFixture.changedSinceModifier(.init(modificationSequence: 999999), "CHANGEDSINCE 999999"),
    ])
    func `encode changed since`(_ fixture: EncodeFixture<ChangedSinceModifier>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        EncodeFixture.unchangedSinceModifier(.init(modificationSequence: 3), "UNCHANGEDSINCE 3"),
        EncodeFixture.unchangedSinceModifier(.init(modificationSequence: 12345), "UNCHANGEDSINCE 12345"),
    ])
    func `encode unchanged since`(_ fixture: EncodeFixture<UnchangedSinceModifier>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<ChangedSinceModifier> {
    fileprivate static func changedSinceModifier(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeChangedSinceModifier($1) }
        )
    }
}

extension EncodeFixture<UnchangedSinceModifier> {
    fileprivate static func unchangedSinceModifier(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeUnchangedSinceModifier($1) }
        )
    }
}
