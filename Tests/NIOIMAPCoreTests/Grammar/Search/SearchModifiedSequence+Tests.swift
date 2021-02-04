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
@testable import NIOIMAPCore
import XCTest

class SearchModifiedSequence_Tests: EncodeTestClass {}

// MARK: - Encoding

extension SearchModifiedSequence_Tests {
    func testEncode() {
        let inputs: [(SearchModificationSequence, String, UInt)] = [
            (.init(extensions: [:], sequenceValue: .init(integerLiteral: 1)), "MODSEQ 1", #line),
            (
                .init(extensions: [
                    .init(flag: .answered): .all,
                ], sequenceValue: .init(integerLiteral: 1)),
                "MODSEQ \"/flags/\\\\answered\" all 1",
                #line
            ),
            (
                .init(extensions: [
                    .init(flag: .answered): .all,
                    .init(flag: .seen): .private,
                ], sequenceValue: .init(integerLiteral: 1)),
                "MODSEQ \"/flags/\\\\answered\" all \"/flags/\\\\seen\" priv 1",
                #line
            ),
            (.init(extensions: [:], sequenceValue: .init(integerLiteral: 1)), "MODSEQ 1", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeSearchModificationSequence($0) })
    }
}
