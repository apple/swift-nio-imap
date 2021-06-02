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

class MetadataValue_Tests: EncodeTestClass {}

// MARK: - IMAP

extension MetadataValue_Tests {
    func testEncode() {
        let inputs: [(MetadataValue, CommandEncodingOptions, [String], UInt)] = [
            (.init(nil), .rfc3501, ["NIL"], #line),
            (.init("test"), .rfc3501, ["~{4}\r\n", "test"], #line),
            (.init("\\"), .rfc3501, ["~{1}\r\n", "\\"], #line),
            (.init("\0"), .init(capabilities: [.binary]), ["~{1}\r\n", "\0"], #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeMetadataValue($0) })
    }
}
