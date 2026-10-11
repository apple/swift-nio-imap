//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import IMAPCommands
import NIOIMAP
import Testing

/// Tagged responses are routed to their command by converting the wire tag back.
@Suite("IMAPConnection.Tag")
struct TagTests {
    @Test("connection tags round-trip through wire tags")
    func roundTrip() {
        let tag = IMAPConnection.Tag.first.makeNext()
        #expect(Command.Tag(tag) == "A2")
        #expect(IMAPConnection.Tag(Command.Tag(tag)) == tag)
    }

    @Test("wire tags this connection didn't generate are not connection tags")
    func foreignTag() {
        let wireTag: Command.Tag = "B1"
        #expect(IMAPConnection.Tag(wireTag) == nil)
    }
}
