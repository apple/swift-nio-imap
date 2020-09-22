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
            (.init(extensions: [], sequenceValue: .init(integerLiteral: 1)), "MODSEQ 1", #line),
            (
                .init(extensions: [
                    .init(name: .init(flag: .answered), request: .all),
                ], sequenceValue: .init(integerLiteral: 1)),
                "MODSEQ \"/flags/\\\\Answered\" all 1",
                #line
            ),
            (
                .init(extensions: [
                    .init(name: .init(flag: .answered), request: .all),
                    .init(name: .init(flag: .seen), request: .private),
                ], sequenceValue: .init(integerLiteral: 1)),
                "MODSEQ \"/flags/\\\\Answered\" all \"/flags/\\\\Seen\" priv 1",
                #line
            ),
            (.init(extensions: [], sequenceValue: .init(integerLiteral: 1)), "MODSEQ 1", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeSearchModificationSequence($0) })
    }

    func testEncode_extension() {
        let inputs: [(SearchModifiedSequenceExtension, String, UInt)] = [
            (.init(name: .init(flag: .answered), request: .all), " \"/flags/\\\\Answered\" all", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeSearchModifiedSequenceExtension($0) })
    }
}
