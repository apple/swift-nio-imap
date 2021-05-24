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

class UserAuthenticationMechanism_Tests: EncodeTestClass {}

// MARK: - IMAP

extension UserAuthenticationMechanism_Tests {
    func testEncode() {
        let inputs: [(UserAuthenticationMechanism, String, UInt)] = [
            (.init(encodedUser: .init(data: "test"), authenticationMechanism: .any), "test;AUTH=*", #line),
            (.init(encodedUser: .init(data: "test"), authenticationMechanism: nil), "test", #line),
            (.init(encodedUser: nil, authenticationMechanism: .any), ";AUTH=*", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeUserAuthenticationMechanism($0) })
    }
}
