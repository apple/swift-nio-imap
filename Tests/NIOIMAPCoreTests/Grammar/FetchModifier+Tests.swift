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

class FetchModifier_Tests: EncodeTestClass {}

// MARK: - IMAP

extension FetchModifier_Tests {
    func testEncode() {
        let inputs: [(FetchModifier, String, UInt)] = [
            (.changedSince(.init(modificationSequence: 4)), "CHANGEDSINCE 4", #line),
            (.other(.init(key: "test", value: nil)), "test", #line),
            (.other(.init(key: "test", value: .sequence(.set([4])))), "test 4", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeFetchModifier($0) })
    }

    func testEncodeArray() {
        let inputs: [([FetchModifier], String, UInt)] = [
            ([.changedSince(.init(modificationSequence: 3665089505007763456))], " (CHANGEDSINCE 3665089505007763456)", #line),
            ([.other(.init(key: "test", value: nil)), .other(.init(key: "test", value: .sequence(.set([4]))))], " (test test 4)", #line),
            ([], "", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeFetchModifiers($0) })
    }
}
