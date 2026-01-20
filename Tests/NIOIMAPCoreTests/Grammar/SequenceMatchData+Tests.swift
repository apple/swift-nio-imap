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

@Suite("SequenceMatchData")
struct SequenceMatchDataTests {
    @Test(arguments: [
        EncodeFixture.sequenceMatchData(.init(knownSequenceSet: .set(.all), knownUidSet: .set(.all)), "(1:* 1:*)"),
        EncodeFixture.sequenceMatchData(.init(knownSequenceSet: .set([1, 2, 3]), knownUidSet: .set([4, 5, 6])), "(1:3 4:6)"),
    ])
    func encode(_ fixture: EncodeFixture<SequenceMatchData>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture where T == SequenceMatchData {
    fileprivate static func sequenceMatchData(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeSequenceMatchData($1) }
        )
    }
}
