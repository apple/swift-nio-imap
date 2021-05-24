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
import XCTest

class SelectParameter_Tests: EncodeTestClass {}

// MARK: - Encoding

extension SelectParameter_Tests {
    func testEncoding() {
        let inputs: [(SelectParameter, String, UInt)] = [
            (.condstore, "CONDSTORE", #line),
            (.basic(.init(key: "test", value: nil)), "test", #line),
            (.basic(.init(key: "test", value: .sequence(.set([1])))), "test 1", #line),
            (
                .qresync(.init(uidValiditiy: 1, modificationSequenceValue: .zero, knownUids: nil, sequenceMatchData: nil)),
                "QRESYNC (1 0)",
                #line
            ),
            (
                .qresync(.init(uidValiditiy: 1, modificationSequenceValue: .zero, knownUids: .set([1]), sequenceMatchData: nil)),
                "QRESYNC (1 0 1)",
                #line
            ),
            (
                .qresync(.init(uidValiditiy: 1, modificationSequenceValue: .zero, knownUids: nil, sequenceMatchData: .init(knownSequenceSet: .set(.all), knownUidSet: .set(.all)))),
                "QRESYNC (1 0 (1:* 1:*))",
                #line
            ),
            (
                .qresync(.init(uidValiditiy: 1, modificationSequenceValue: .zero, knownUids: .set([1]), sequenceMatchData: .init(knownSequenceSet: .set(.all), knownUidSet: .set(.all)))),
                "QRESYNC (1 0 1 (1:* 1:*))",
                #line
            ),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeSelectParameter($0) })
    }
}
