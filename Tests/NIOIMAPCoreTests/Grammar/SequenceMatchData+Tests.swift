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

class SequenceMatchData_Tests: EncodeTestClass {}

// MARK: - IMAP

extension SequenceMatchData_Tests {
    func testEncode() {
        let inputs: [(SequenceMatchData, String, UInt)] = [
            (.init(knownSequenceSet: .set(.all), knownUidSet: .set(.all)), "(1:* 1:*)", #line),
            (.init(knownSequenceSet: .set([1, 2, 3]), knownUidSet: .set([4, 5, 6])), "(1:3 4:6)", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeSequenceMatchData($0) })
    }
}
