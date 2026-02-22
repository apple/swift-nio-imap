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
import Testing

@Suite("Command Roundtrip")
private enum RoundtripTests {
    struct RoundtripFixture: Sendable, CustomTestStringConvertible, CustomTestArgumentEncodable {
        var name: String
        var command: Command

        var testDescription: String { name }

        func encodeTestArgument(to encoder: some Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(name)
        }
    }

    @Test(
        "command roundtrip",
        arguments: [
            RoundtripFixture(name: "NOOP command", command: .noop),
            RoundtripFixture(name: "CAPABILITY command", command: .capability),
            RoundtripFixture(name: "LOGOUT command", command: .logout),
            RoundtripFixture(name: "STARTTLS command", command: .startTLS),
            RoundtripFixture(name: "CHECK command", command: .check),
            RoundtripFixture(name: "CLOSE command", command: .close),
            RoundtripFixture(name: "EXPUNGE command", command: .expunge),
            RoundtripFixture(name: "LOGIN command", command: .login(username: "user", password: "password")),
            RoundtripFixture(
                name: "AUTHENTICATE command",
                command: .authenticate(mechanism: .init("some"), initialResponse: nil)
            ),
            RoundtripFixture(name: "CREATE command with INBOX", command: .create(.inbox, [])),
            RoundtripFixture(name: "CREATE command with mailbox name", command: .create(MailboxName("mailbox"), [])),
            RoundtripFixture(name: "DELETE command with INBOX", command: .delete(.inbox)),
            RoundtripFixture(name: "DELETE command with mailbox name", command: .delete(MailboxName("mailbox"))),
            RoundtripFixture(name: "EXAMINE command with INBOX and parameters", command: .examine(.inbox, [])),
            RoundtripFixture(
                name: "EXAMINE command with mailbox name and parameters",
                command: .examine(MailboxName("mailbox"), [])
            ),
            RoundtripFixture(name: "EXAMINE command with mailbox name", command: .examine(MailboxName("mailbox"))),
            RoundtripFixture(name: "SUBSCRIBE command with INBOX", command: .subscribe(.inbox)),
            RoundtripFixture(name: "SUBSCRIBE command with mailbox name", command: .subscribe(MailboxName("mailbox"))),
            RoundtripFixture(name: "UNSUBSCRIBE command with INBOX", command: .unsubscribe(.inbox)),
            RoundtripFixture(
                name: "UNSUBSCRIBE command with mailbox name",
                command: .unsubscribe(MailboxName("mailbox"))
            ),
            RoundtripFixture(name: "SELECT command with INBOX and parameters", command: .select(.inbox, [])),
            RoundtripFixture(
                name: "SELECT command with mailbox name and parameters",
                command: .select(MailboxName("mailbox"), [])
            ),
            RoundtripFixture(name: "SELECT command with mailbox name", command: .select(MailboxName("mailbox"))),
            RoundtripFixture(
                name: "RENAME command with INBOX",
                command: .rename(from: .inbox, to: .inbox, parameters: [:])
            ),
            RoundtripFixture(
                name: "RENAME command with mailbox names",
                command: .rename(from: MailboxName("test1"), to: MailboxName("test2"), parameters: [:])
            ),
            RoundtripFixture(
                name: "LIST command with INBOX reference and pattern",
                command: .list(nil, reference: .inbox, .pattern(["pattern"]), [])
            ),
            RoundtripFixture(
                name: "LIST command with mailbox reference and pattern",
                command: .list(nil, reference: MailboxName("bar"), .pattern(["pattern"]), [])
            ),
            RoundtripFixture(
                name: "LIST command with INBOX reference and mailbox",
                command: .list(nil, reference: .inbox, .mailbox("pattern"))
            ),
            RoundtripFixture(
                name: "LSUB command with INBOX reference",
                command: .lsub(reference: .inbox, pattern: "abcd")
            ),
            RoundtripFixture(
                name: "LSUB command with quoted pattern",
                command: .lsub(reference: .inbox, pattern: "\"something\"")
            ),
            RoundtripFixture(
                name: "LSUB command with literal pattern",
                command: .lsub(reference: MailboxName("bar"), pattern: "{3}\r\nfoo")
            ),
            RoundtripFixture(
                name: "STATUS command with INBOX and single item",
                command: .status(.inbox, [.messageCount])
            ),
            RoundtripFixture(
                name: "STATUS command with mailbox and multiple items",
                command: .status(MailboxName("foobar"), [.messageCount, .recentCount, .uidNext])
            ),
            RoundtripFixture(name: "COPY command with range", command: .copy(LastCommandSet.range(2...), .inbox)),
            RoundtripFixture(name: "FETCH command with ALL macro", command: .fetch(.set([.all]), .all, [])),
            RoundtripFixture(name: "FETCH command with FAST macro", command: .fetch(.set([.all]), .fast, [])),
            RoundtripFixture(name: "FETCH command with FULL macro", command: .fetch(.set([.all]), .full, [])),
            RoundtripFixture(
                name: "FETCH command with basic attributes",
                command: .fetch(.set([5678]), [.uid, .flags, .internalDate, .envelope], [])
            ),
            RoundtripFixture(
                name: "FETCH command with body structure",
                command: .fetch(.set([5678]), [.flags, .bodyStructure(extensions: true)], [])
            ),
            RoundtripFixture(
                name: "FETCH command with complete body section",
                command: .fetch(.set([5678]), [.flags, .bodySection(peek: false, .complete, 3...4)], [])
            ),
            RoundtripFixture(
                name: "FETCH command with header body section",
                command: .fetch(.set([5678]), [.flags, .bodySection(peek: false, .init(kind: .header), 3...4)], [])
            ),
            RoundtripFixture(
                name: "FETCH command with header fields body section",
                command: .fetch(
                    .set([5678]),
                    [
                        .bodySection(
                            peek: false,
                            .init(part: [12, 34], kind: .headerFields(["some", "header"])),
                            3...4
                        )
                    ],
                    []
                )
            ),
            RoundtripFixture(
                name: "STORE command with remove flags",
                command: .store(.set(.all), [], .flags(.remove(silent: true, list: [.answered, .deleted])))
            ),
            RoundtripFixture(
                name: "STORE command with add flags",
                command: .store(.set(.all), [], .flags(.add(silent: true, list: [.draft, .extension("\\some")])))
            ),
            RoundtripFixture(
                name: "STORE command with replace flags",
                command: .store(.set(.all), [], .flags(.replace(silent: true, list: [.keyword(.colorBit0)])))
            ),
            RoundtripFixture(name: "UID COPY command", command: .uidCopy(.set(.all), .inbox)),
            RoundtripFixture(
                name: "UID STORE command",
                command: .uidStore(.set(.all), [], .flags(.add(silent: true, list: [.draft, .deleted, .answered])))
            ),
            RoundtripFixture(name: "SEARCH command with simple key", command: .search(key: .all)),
            RoundtripFixture(
                name: "SEARCH command with OR key and charset",
                command: .search(key: .or(.deleted, .from("example")), charset: "UTF-7")
            ),
            RoundtripFixture(
                name: "SEARCH command with OR key and return options",
                command: .search(key: .or(.to("bar"), .unseen), charset: "UTF-8", returnOptions: [.min, .max])
            ),
            RoundtripFixture(
                name: "SEARCH command with AND key and return options",
                command: .search(key: .and([.new, .deleted, .unseen]), charset: nil, returnOptions: [.min, .max])
            ),
            RoundtripFixture(
                name: "Extended SEARCH command with source options",
                command: .extendedSearch(
                    ExtendedSearchOptions(
                        key: .all,
                        sourceOptions: ExtendedSearchSourceOptions(sourceMailbox: [.inboxes])
                    )
                )
            )
        ]
    )
    static func commandRoundtrip(_ fixture: RoundtripFixture) throws {
        var encodeBuffer = CommandEncodeBuffer(buffer: ByteBuffer(), options: .init(), loggingMode: false)
        let tag = "1"
        let taggedCommand = TaggedCommand(tag: tag, command: fixture.command)
        encodeBuffer.writeCommand(taggedCommand)
        // required for commands that might terminate with a literal (e.g. append)
        encodeBuffer.buffer.writeString("\r\n")

        var buffer = ByteBufferAllocator().buffer(capacity: 128)
        while true {
            let next = encodeBuffer.buffer.nextChunk()
            var toSend = next.bytes
            buffer.writeBuffer(&toSend)
            if !next.waitForContinuation {
                break
            }
        }

        var parseBuffer = ParseBuffer(buffer)
        let decoded = try GrammarParser().parseTaggedCommand(buffer: &parseBuffer, tracker: .testTracker)
        #expect(decoded == taggedCommand, "Decoded command should match original")
    }
}
