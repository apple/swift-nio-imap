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
@testable import IMAPToolLib
import Foundation
import NIO
import NIOIMAP
import Testing

@Suite("Append", .timeLimit(.minutes(1)))
private struct AppendTests {
    let messageA = #"""
        From: foo@example.apple.com
        To: bar@example.apple.com
        Message-ID: <1@example.apple.com>
        Subject: Test A
        Date: Tue, 30 Apr 2024 14:31:07 +0000

        Hello!

        """#.replacingOccurrences(of: "\n", with: "\r\n")

    let dateA = ServerMessageDate(
        .init(year: 2024, month: 4, day: 30, hour: 14, minute: 31, second: 7, timeZoneMinutes: 0)!
    )

    func singleMessageExpectedCommand(
        message: String,
        internalDate: ServerMessageDate?,
        completion: TaggedResponse.State = .ok(.init(text: "Done"))
    ) -> TestServer.ExpectedCommand {
        .init(
            part: .append(
                MailboxName("Food"),
                [
                    .beginMessage(
                        message: AppendMessage(
                            options: AppendOptions(
                                internalDate: internalDate
                            ),
                            data: AppendData(byteCount: message.utf8.count)
                        )
                    ),
                    .messageBytes(ByteBuffer(string: message)),
                    .endMessage,
                    .finish,
                ]
            ),
            responses: [],
            completion: completion
        )
    }

    @Test
    func singleMessage_noInternalDate() async throws {
        let message: MessageToAppend = try {
            var m = try MessageToAppend(
                message: EmailMessage(
                    data: Data(messageA.utf8)
                ),
                id: "foobar"
            )
            m.serverMessageDate = nil
            return m
        }()

        await TestServer.runSingleConnectionServer(
            greeting: .ok(.init(text: "Hello")),
            expectedCommands: [
                singleMessageExpectedCommand(
                    message: messageA,
                    internalDate: nil
                )
            ]
        ) { path in
            try await IMAPConnection.withConnection(
                configuration: IMAPConnection.Configuration(path)
            ) { greeting, connection in
                let result = try await append(
                    connection: connection,
                    message: message,
                    into: MailboxName("Food")
                )
                #expect(result == nil)
            }
        }
    }

    @Test
    func singleMessage_withInternalDate() async throws {
        await TestServer.runSingleConnectionServer(
            greeting: .ok(.init(text: "Hello")),
            expectedCommands: [
                singleMessageExpectedCommand(
                    message: messageA,
                    internalDate: dateA
                )
            ]
        ) { path in
            try await IMAPConnection.withConnection(
                configuration: IMAPConnection.Configuration(path)
            ) { greeting, connection in
                let result = try await append(
                    connection: connection,
                    message: MessageToAppend(
                        message: EmailMessage(
                            data: Data(messageA.utf8)
                        ),
                        id: "foobar"
                    ),
                    into: MailboxName("Food")
                )
                #expect(result == nil)
            }
        }
    }

    @Test
    func singleMessage_literalPlus() async throws {
        await TestServer.runSingleConnectionServer(
            greeting: .ok(.init(text: "Hello")),
            expectedCommands: [
                singleMessageExpectedCommand(
                    message: messageA,
                    internalDate: dateA
                )
            ]
        ) { path in
            try await IMAPConnection.withConnection(
                configuration: IMAPConnection.Configuration(path)
            ) { greeting, connection in
                // Turn on LITERAL+ support:
                try await connection.setEncodingOptions(
                    .fixed(
                        CommandEncodingOptions(
                            useQuotedString: true,
                            useSynchronizingLiteral: false,
                            useNonSynchronizingLiteralPlus: true,
                            useNonSynchronizingLiteralMinus: false,
                            useBinaryLiteral: false
                        )
                    )
                )

                let result = try await append(
                    connection: connection,
                    message: MessageToAppend(
                        message: EmailMessage(
                            data: Data(messageA.utf8)
                        ),
                        id: "foobar"
                    ),
                    into: MailboxName("Food")
                )
                #expect(result == nil)
            }
        }
    }

    @Test
    func singleMessage_serverReturnsNo() async throws {
        await TestServer.runSingleConnectionServer(
            greeting: .ok(.init(text: "Hello")),
            expectedCommands: [
                singleMessageExpectedCommand(
                    message: messageA,
                    internalDate: dateA,
                    completion: .no(ResponseText(text: "Not allowed"))
                )
            ]
        ) { path in
            try await IMAPConnection.withConnection(
                configuration: IMAPConnection.Configuration(path)
            ) { greeting, connection -> Void in
                await #expect(
                    throws: FailedToAppendMessage(state: .no(ResponseText(text: "Not allowed")))
                ) {
                    _ = try await append(
                        connection: connection,
                        message: MessageToAppend(
                            message: EmailMessage(
                                data: Data(messageA.utf8)
                            ),
                            id: "foobar"
                        ),
                        into: MailboxName("Food")
                    )
                }
            }
        }
    }

    @Test
    func singleMessageWithUIDPLUS() async throws {
        await TestServer.runSingleConnectionServer(
            greeting: .ok(.init(text: "Hello")),
            expectedCommands: [
                singleMessageExpectedCommand(
                    message: messageA,
                    internalDate: dateA,
                    completion: .ok(
                        ResponseText(
                            code: .uidAppend(
                                ResponseCodeAppend(
                                    uidValidity: 0x123456,
                                    uids: [785_048]
                                )
                            ),
                            text: "Done appending"
                        )
                    )
                )
            ]
        ) { path in
            try await IMAPConnection.withConnection(
                configuration: IMAPConnection.Configuration(path)
            ) { greeting, connection in
                let result = try await append(
                    connection: connection,
                    message: MessageToAppend(
                        message: EmailMessage(
                            data: Data(messageA.utf8)
                        ),
                        id: "foobar"
                    ),
                    into: MailboxName("Food")
                )
                #expect(result?.uidValidity == 0x123456)
                #expect(result?.uids == [785_048])
            }
        }
    }

    // Helper function for creating expected commands with flags
    func singleMessageExpectedCommandWithFlags(
        message: String,
        flags: [NIOIMAP.Flag],
        internalDate: ServerMessageDate?,
        completion: TaggedResponse.State = .ok(.init(text: "Done"))
    ) -> TestServer.ExpectedCommand {
        .init(
            part: .append(
                MailboxName("Food"),
                [
                    .beginMessage(
                        message: AppendMessage(
                            options: AppendOptions(
                                flagList: flags,
                                internalDate: internalDate
                            ),
                            data: AppendData(byteCount: message.utf8.count)
                        )
                    ),
                    .messageBytes(ByteBuffer(string: message)),
                    .endMessage,
                    .finish,
                ]
            ),
            responses: [],
            completion: completion
        )
    }

    @Test
    func singleMessage_withFlags() async throws {
        let flags: [NIOIMAP.Flag] = [.seen, .flagged]

        await TestServer.runSingleConnectionServer(
            greeting: .ok(.init(text: "Hello")),
            expectedCommands: [
                singleMessageExpectedCommandWithFlags(
                    message: messageA,
                    flags: flags,
                    internalDate: dateA
                )
            ]
        ) { path in
            try await IMAPConnection.withConnection(
                configuration: IMAPConnection.Configuration(path)
            ) { greeting, connection in
                var message = try MessageToAppend(
                    message: EmailMessage(
                        data: Data(messageA.utf8)
                    ),
                    id: "foobar"
                )
                message.flags = flags

                let result = try await append(
                    connection: connection,
                    message: message,
                    into: MailboxName("Food")
                )
                #expect(result == nil)
            }
        }
    }

    @Test
    func singleMessage_withMultipleFlags() async throws {
        let flags: [NIOIMAP.Flag] = [.seen, .flagged, .answered, .draft]

        await TestServer.runSingleConnectionServer(
            greeting: .ok(.init(text: "Hello")),
            expectedCommands: [
                singleMessageExpectedCommandWithFlags(
                    message: messageA,
                    flags: flags,
                    internalDate: dateA
                )
            ]
        ) { path in
            try await IMAPConnection.withConnection(
                configuration: IMAPConnection.Configuration(path)
            ) { greeting, connection in
                var message = try MessageToAppend(
                    message: EmailMessage(
                        data: Data(messageA.utf8)
                    ),
                    id: "foobar"
                )
                message.flags = flags

                let result = try await append(
                    connection: connection,
                    message: message,
                    into: MailboxName("Food")
                )
                #expect(result == nil)
            }
        }
    }

    @Test
    func singleMessage_withCustomFlags() async throws {
        let customFlag = NIOIMAP.Flag("\\CustomFlag")
        let recentFlag = NIOIMAP.Flag("\\Recent")
        let flags: [NIOIMAP.Flag] = [.seen, customFlag, recentFlag]

        await TestServer.runSingleConnectionServer(
            greeting: .ok(.init(text: "Hello")),
            expectedCommands: [
                singleMessageExpectedCommandWithFlags(
                    message: messageA,
                    flags: flags,
                    internalDate: dateA
                )
            ]
        ) { path in
            try await IMAPConnection.withConnection(
                configuration: IMAPConnection.Configuration(path)
            ) { greeting, connection in
                var message = try MessageToAppend(
                    message: EmailMessage(
                        data: Data(messageA.utf8)
                    ),
                    id: "foobar"
                )
                message.flags = flags

                let result = try await append(
                    connection: connection,
                    message: message,
                    into: MailboxName("Food")
                )
                #expect(result == nil)
            }
        }
    }

    @Test
    func singleMessage_withEmptyFlags() async throws {
        let flags: [NIOIMAP.Flag] = []

        await TestServer.runSingleConnectionServer(
            greeting: .ok(.init(text: "Hello")),
            expectedCommands: [
                singleMessageExpectedCommandWithFlags(
                    message: messageA,
                    flags: flags,
                    internalDate: dateA
                )
            ]
        ) { path in
            try await IMAPConnection.withConnection(
                configuration: IMAPConnection.Configuration(path)
            ) { greeting, connection in
                var message = try MessageToAppend(
                    message: EmailMessage(
                        data: Data(messageA.utf8)
                    ),
                    id: "foobar"
                )
                message.flags = flags

                let result = try await append(
                    connection: connection,
                    message: message,
                    into: MailboxName("Food")
                )
                #expect(result == nil)
            }
        }
    }

    @Test
    func singleMessage_nilFlags() async throws {
        await TestServer.runSingleConnectionServer(
            greeting: .ok(.init(text: "Hello")),
            expectedCommands: [
                singleMessageExpectedCommand(
                    message: messageA,
                    internalDate: dateA
                )
            ]
        ) { path in
            try await IMAPConnection.withConnection(
                configuration: IMAPConnection.Configuration(path)
            ) { greeting, connection in
                var message = try MessageToAppend(
                    message: EmailMessage(
                        data: Data(messageA.utf8)
                    ),
                    id: "foobar"
                )
                message.flags = nil

                let result = try await append(
                    connection: connection,
                    message: message,
                    into: MailboxName("Food")
                )
                #expect(result == nil)
            }
        }
    }
}
