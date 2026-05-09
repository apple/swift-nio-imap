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
enum DeleteMessagesTests {
    @Test
    static func test() async throws {
        let connection = TestConnection(expectedCommands: [
            .init(
                command: .uidStore(
                    .set([309_727, 967_986]),
                    [],
                    .flags(
                        StoreFlags.add(
                            silent: true,
                            list: [.deleted]
                        )
                    )
                ),
                responses: [],
                completion: .ok(.init(text: "Updated"))
            ),
            .init(
                command: .expunge,
                responses: [
                    .untagged(.messageData(.expunge(44))),
                    .untagged(.messageData(.expunge(55))),
                ],
                completion: .ok(.init(text: "Done"))
            ),
        ])
        try await deleteMessages(
            connection: connection,
            uids: [309_727, 967_986]
        )
    }

    @Test
    static func empty() async throws {
        let connection = TestConnection(
            expectedCommands: []
        )
        try await deleteMessages(
            connection: connection,
            uids: []
        )
    }
}
