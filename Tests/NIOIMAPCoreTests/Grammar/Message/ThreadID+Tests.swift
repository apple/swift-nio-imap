//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2024 Apple Inc. and the SwiftNIO project authors
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
import Testing

@Suite("ThreadID")
struct ThreadIDTests {
    @Test("valid string init")
    func validStringInit() {
        let valid: String = "abc123"
        #expect(ThreadID(valid) != nil)
    }

    @Test("invalid string init returns nil")
    func invalidStringInitReturnsNil() {
        let empty: String = ""
        #expect(ThreadID(empty) == nil)
        let withSpace: String = "has space"
        #expect(ThreadID(withSpace) == nil)
    }

    @Test("string conversion")
    func stringConversion() {
        let id: ThreadID = "abc123"
        #expect(String(id) == "abc123")
    }

    @Test("debug description")
    func debugDescription() {
        let id: ThreadID = "abc123"
        #expect(id.debugDescription == "(abc123)")
    }
}
