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
import Foundation
@testable import IMAPToolLib
import NIO
import NIOIMAP
import Testing

@Suite
enum IdentifyTests {
    @Test
    static func roundTrip() async throws {
        let connection = TestConnection(expectedCommands: [
            .init(
                command: .id([
                    "name": "imap-tool",
                    "os": Identity.operatingSystemName,
                    "os-version": Identity.operatingSystemVersion,
                ]),
                responses: [
                    .untagged(
                        .id([
                            "foo": nil,
                            "bar": "baz",
                        ])
                    )
                ],
                completion: .ok(.init(text: "Done"))
            )
        ])
        let r = try await identify(
            connection: connection,
            capabilities: [.imap4rev1, .condStore, .id]
        )
        #expect(await connection.expectedCommands.isEmpty)
        #expect(r.serverID["bar"] == "baz")
        #expect(r.serverID.count == 2)
        #expect(r.capabilities == [.imap4rev1, .condStore, .id])
    }

    @Test
    static func serverWithoutID() async throws {
        let connection = TestConnection(expectedCommands: [])
        let r = try await identify(
            connection: connection,
            capabilities: [.imap4rev1, .condStore]
        )
        #expect(await connection.expectedCommands.isEmpty)
        #expect(r.serverID == [:])
        #expect(r.capabilities == [.imap4rev1, .condStore])
    }
}
