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

private struct UpdateFlagsTests {
    @Test
    func setFlags() async throws {
        let connection = TestConnection(expectedCommands: [
            .init(
                command: .uidStore(
                    messages: [123, 456],
                    modifiers: [],
                    data: StoreData.flags(
                        .add(
                            silent: false,
                            list: [.seen, .flagged]
                        )
                    )
                )!,
                responses: [
                    .fetch(.start(123)),
                    .fetch(.simpleAttribute(.flags([.seen, .flagged]))),
                    .fetch(.finish),

                    .fetch(.start(456)),
                    .fetch(.simpleAttribute(.flags([.seen, .flagged, .answered]))),
                    .fetch(.finish),
                ],
                completion: .ok(.init(text: "STORE completed"))
            )
        ])

        try await updateFlags(
            connection: connection,
            uids: [123, 456],
            changes: .init(
                set: [.seen, .flagged],
                unset: []
            )
        )
    }

    @Test
    func unsetFlags() async throws {
        let connection = TestConnection(expectedCommands: [
            .init(
                command: .uidStore(
                    messages: [123, 456],
                    modifiers: [],
                    data: StoreData.flags(
                        .remove(
                            silent: false,
                            list: [.seen, .flagged]
                        )
                    )
                )!,
                responses: [
                    .fetch(.start(123)),
                    .fetch(.simpleAttribute(.flags([.seen, .flagged]))),
                    .fetch(.finish),

                    .fetch(.start(456)),
                    .fetch(.simpleAttribute(.flags([.seen, .flagged, .answered]))),
                    .fetch(.finish),
                ],
                completion: .ok(.init(text: "STORE completed"))
            )
        ])

        try await updateFlags(
            connection: connection,
            uids: [123, 456],
            changes: .init(
                set: [],
                unset: [.seen, .flagged]
            )
        )
    }

    @Test
    func setAndUnsetFlags() async throws {
        let connection = TestConnection(expectedCommands: [
            .init(
                command: .uidStore(
                    messages: [123, 456],
                    modifiers: [],
                    data: StoreData.flags(
                        .add(
                            silent: false,
                            list: [.flagged]
                        )
                    )
                )!,
                responses: [
                    .fetch(.start(123)),
                    .fetch(.simpleAttribute(.flags([.seen, .flagged]))),
                    .fetch(.finish),

                    .fetch(.start(456)),
                    .fetch(.simpleAttribute(.flags([.flagged, .answered]))),
                    .fetch(.finish),
                ],
                completion: .ok(.init(text: "STORE 1 completed"))
            ),
            .init(
                command: .uidStore(
                    messages: [123, 456],
                    modifiers: [],
                    data: StoreData.flags(
                        .remove(
                            silent: false,
                            list: [.seen]
                        )
                    )
                )!,
                responses: [
                    .fetch(.start(123)),
                    .fetch(.simpleAttribute(.flags([.flagged]))),
                    .fetch(.finish),

                    .fetch(.start(456)),
                    .fetch(.simpleAttribute(.flags([.flagged, .answered]))),
                    .fetch(.finish),
                ],
                completion: .ok(.init(text: "STORE 2 completed"))
            ),
        ])

        try await updateFlags(
            connection: connection,
            uids: [123, 456],
            changes: .init(
                set: [.flagged],
                unset: [.seen]
            )
        )
    }
}
