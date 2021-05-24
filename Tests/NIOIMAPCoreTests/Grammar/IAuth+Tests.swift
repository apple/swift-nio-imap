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

class IMAPURLAuthenticationMechanism_Tests: EncodeTestClass {}

// MARK: - IMAP

extension IMAPURLAuthenticationMechanism_Tests {
    func testEncode() {
        let inputs: [(IMAPURLAuthenticationMechanism, String, UInt)] = [
            (.any, ";AUTH=*", #line),
            (.type(.init(authenticationType: "data")), ";AUTH=data", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeIMAPURLAuthenticationMechanism($0) })
    }
}
