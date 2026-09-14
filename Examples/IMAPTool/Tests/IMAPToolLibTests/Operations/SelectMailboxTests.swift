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

import ArgumentParser
@testable import IMAPCommands
import Foundation
@testable import IMAPToolLib
import NIO
import NIOIMAP
import Testing

@Suite("Select Mailbox")
struct SelectMailboxTests {
    @Test(.timeLimit(.minutes(1)))
    func test() async throws {
        let connection = TestConnection(expectedCommands: [
            .init(
                command: .select(.inbox, []),
                untagged: [
                    .mailboxData(.flags([.answered, .flagged, .deleted, .seen, .draft])),
                    .mailboxData(.exists(136_599)),
                    .conditionalState(
                        .ok(.init(code: .permanentFlags([.flag(.deleted), .flag(.seen), .wildcard]), text: ""))
                    ),
                    .conditionalState(.ok(.init(code: .uidNext(939_012), text: ""))),
                    .conditionalState(.ok(.init(code: .uidValidity(537_470), text: ""))),
                ]
            )
        ])

        let info = try await select(
            connection: connection,
            createMailbox: .fail,
            mailbox: .inbox
        )

        #expect(info.mailbox == .inbox)
        #expect(info.responseText == .init(text: "Done"))
        #expect(info.flags == [.answered, .flagged, .deleted, .seen, .draft])
        #expect(info.permanentFlags == [.flag(.deleted), .flag(.seen), .wildcard])
        #expect(info.messageCount == 136_599)
        #expect(info.uidNext == 939_012)
        #expect(info.uidValidity == 537_470)
    }

    @Test(.timeLimit(.minutes(1)))
    func testOtherMailbox() async throws {
        let connection = TestConnection(expectedCommands: [
            .init(
                command: .select("Food", []),
                untagged: [
                    .conditionalState(.ok(.init(code: .uidValidity(265_058), text: ""))),
                    .conditionalState(.ok(.init(code: .uidNext(287_187), text: ""))),
                    .conditionalState(.ok(.init(code: .permanentFlags([.flag(.flagged), .flag(.draft)]), text: ""))),
                    .mailboxData(.flags([.flagged, .draft, .answered])),
                    .mailboxData(.exists(93_97)),
                ]
            )
        ])

        let info = try await select(
            connection: connection,
            createMailbox: .fail,
            mailbox: "Food" as MailboxName
        )

        #expect(info.mailbox == "Food")
        #expect(info.responseText == .init(text: "Done"))
        #expect(info.flags == [.flagged, .draft, .answered])
        #expect(info.permanentFlags == [.flag(.flagged), .flag(.draft)])
        #expect(info.messageCount == 93_97)
        #expect(info.uidNext == 287_187)
        #expect(info.uidValidity == 265_058)
    }

    @Test(.timeLimit(.minutes(1)))
    func testFailure() async throws {
        let connection = TestConnection(expectedCommands: [
            .init(
                command: .select("Food", []),
                untagged: [],
                completion: .no(ResponseText(text: "Unknown mailbox"))
            )
        ])
        async #expect(
            performing: {
                _ = try await select(
                    connection: connection,
                    createMailbox: .fail,
                    mailbox: "Food" as MailboxName
                )
            },
            throws: { _ in true }
        )
    }

    @Test(.timeLimit(.minutes(1)))
    func testCreatingMailboxWhenSelectionFails() async throws {
        let connection = TestConnection(expectedCommands: [
            .init(
                command: .select("Food", []),
                untagged: [],
                completion: .no(ResponseText(text: "Unknown mailbox"))
            ),
            .init(
                command: .create("Food", [.attributes([.sent])]),
                untagged: [],
                completion: .ok(ResponseText(text: "Did create mailbox"))
            ),
            .init(
                command: .select("Food", []),
                untagged: [
                    .conditionalState(.ok(.init(code: .uidValidity(265_058), text: ""))),
                    .conditionalState(.ok(.init(code: .uidNext(287_187), text: ""))),
                    .conditionalState(.ok(.init(code: .permanentFlags([.flag(.flagged), .flag(.draft)]), text: ""))),
                    .mailboxData(.flags([.flagged, .draft, .answered])),
                    .mailboxData(.exists(93_97)),
                ],
                completion: .ok(ResponseText(text: "Did select mailbox"))
            ),
        ])

        let info = try await select(
            connection: connection,
            createMailbox: .create([.attributes([.sent])]),
            mailbox: "Food" as MailboxName
        )

        #expect(info.mailbox == "Food")
        #expect(info.responseText == .init(text: "Did select mailbox"))
        #expect(info.flags == [.flagged, .draft, .answered])
        #expect(info.permanentFlags == [.flag(.flagged), .flag(.draft)])
        #expect(info.messageCount == 93_97)
        #expect(info.uidNext == 287_187)
        #expect(info.uidValidity == 265_058)
    }

    @Test(.timeLimit(.minutes(1)))
    func testCreatingMailboxFailsWhenSelectionFails() async throws {
        let connection = TestConnection(expectedCommands: [
            .init(
                command: .select("Food", []),
                untagged: [],
                completion: .no(ResponseText(text: "Unknown mailbox"))
            ),
            .init(
                command: .create("Food", [.attributes([.sent])]),
                untagged: [],
                completion: .no(ResponseText(text: "Can not create mailbox"))
            ),
        ])
        async #expect(
            performing: {
                _ = try await select(
                    connection: connection,
                    createMailbox: .create([.attributes([.sent])]),
                    mailbox: "Food" as MailboxName
                )
            },
            throws: { _ in true }
        )
    }
}
