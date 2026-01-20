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

@Suite("FetchModifier")
struct FetchModifierTests {
    @Test(arguments: [
        EncodeFixture.fetchModifier(.changedSince(.init(modificationSequence: 4)), "CHANGEDSINCE 4"),
        EncodeFixture.fetchModifier(.partial(.last(735...88_032)), "PARTIAL -735:-88032"),
        EncodeFixture.fetchModifier(.other(.init(key: "test", value: nil)), "test"),
        EncodeFixture.fetchModifier(.other(.init(key: "test", value: .sequence(.set([4])))), "test 4"),
    ])
    func `encode single modifier`(_ fixture: EncodeFixture<FetchModifier>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        EncodeFixture.fetchModifiers(
            [.partial(.last(1...30)), .changedSince(.init(modificationSequence: 3_665_089_505_007_763_456))],
            " (PARTIAL -1:-30 CHANGEDSINCE 3665089505007763456)"
        ),
        EncodeFixture.fetchModifiers(
            [.changedSince(.init(modificationSequence: 98305))],
            " (CHANGEDSINCE 98305)"
        ),
        EncodeFixture.fetchModifiers(
            [.other(.init(key: "test", value: nil)), .other(.init(key: "test", value: .sequence(.set([4]))))],
            " (test test 4)"
        ),
        EncodeFixture.fetchModifiers([], ""),
    ])
    func `encode multiple modifiers`(_ fixture: EncodeFixture<[FetchModifier]>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture where T == FetchModifier {
    fileprivate static func fetchModifier(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeFetchModifier($1) }
        )
    }
}

extension EncodeFixture where T == [FetchModifier] {
    fileprivate static func fetchModifiers(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeFetchModifiers($1) }
        )
    }
}
