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

class NetworkPath_Tests: EncodeTestClass {}

// MARK: - IMAP

extension NetworkPath_Tests {
    func testEncode() {
        let inputs: [(NetworkPath, String, UInt)] = [
            (
                .init(server: .init(host: "localhost"), query: .init(command: nil)),
                "//localhost/",
                #line
            ),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeNetworkPath($0) })
    }
}
