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

@Suite("CommandType")
struct CommandTypeTests {
    @Test(arguments: [
        CommandEncodeFixture.command(.list(nil, reference: .init(""), .mailbox(""), []), "LIST \"\" \"\""),
        CommandEncodeFixture.command(.list(nil, reference: .init(""), .mailbox("")), "LIST \"\" \"\""),
        CommandEncodeFixture.command(.list(nil, reference: .init(""), .mailbox("")), "LIST \"\" \"\""),
        CommandEncodeFixture.command(.list(nil, reference: .inbox, .mailbox(""), [.children]), "LIST \"INBOX\" \"\" RETURN (CHILDREN)"),

        CommandEncodeFixture.command(.namespace, "NAMESPACE"),

        CommandEncodeFixture.command(.login(username: "username", password: "password"), #"LOGIN "username" "password""#),
        CommandEncodeFixture.command(.login(username: "david evans", password: "great password"), #"LOGIN "david evans" "great password""#),
        CommandEncodeFixture.command(.login(username: #"foo\bar"#, password: #"pass"word"#), #"LOGIN "foo\\bar" "pass\"word""#),
        CommandEncodeFixture.command(.login(username: "\r\n", password: "\n"), expectedStrings: ["LOGIN {2}\r\n", "\r\n {1}\r\n", "\n"]),

        CommandEncodeFixture.command(.select(MailboxName("Events")), #"SELECT "Events""#),
        CommandEncodeFixture.command(.select(.inbox, [.basic(.init(key: "test", value: nil))]), #"SELECT "INBOX" (test)"#),
        CommandEncodeFixture.command(.select(.inbox, [.basic(.init(key: "test1", value: nil)), .basic(.init(key: "test2", value: nil))]), #"SELECT "INBOX" (test1 test2)"#),
        CommandEncodeFixture.command(.examine(MailboxName("Events")), #"EXAMINE "Events""#),
        CommandEncodeFixture.command(.examine(.inbox, [.basic(.init(key: "test", value: nil))]), #"EXAMINE "INBOX" (test)"#),
        CommandEncodeFixture.command(.expunge, #"EXPUNGE"#),
        CommandEncodeFixture.command(.move(.set([1]), .inbox), "MOVE 1 \"INBOX\""),
        CommandEncodeFixture.command(.id([:]), "ID NIL"),
        CommandEncodeFixture.command(.getMetadata(options: [], mailbox: .inbox, entries: ["a"]), "GETMETADATA \"INBOX\" (\"a\")"),
        CommandEncodeFixture.command(.getMetadata(options: [.maxSize(123)], mailbox: .inbox, entries: ["a"]), "GETMETADATA (MAXSIZE 123) \"INBOX\" (\"a\")"),
        CommandEncodeFixture.command(.setMetadata(mailbox: .inbox, entries: ["a": nil]), "SETMETADATA \"INBOX\" (\"a\" NIL)"),

        CommandEncodeFixture.command(.fetch(.set([1...40]), [.uid, .internalDate], []), "FETCH 1:40 (UID INTERNALDATE)"),
        CommandEncodeFixture.command(.fetch(.set([77]), [.uid, .bodySection(peek: true, .header, nil)], [.changedSince(.init(modificationSequence: 707_484_939_116_871_680))]), "FETCH 77 (UID BODY.PEEK[HEADER]) (CHANGEDSINCE 707484939116871680)"),

        CommandEncodeFixture.command(.resetKey(mailbox: nil, mechanisms: []), "RESETKEY"),
        CommandEncodeFixture.command(.resetKey(mailbox: nil, mechanisms: [.internal]), "RESETKEY"),
        CommandEncodeFixture.command(.resetKey(mailbox: .inbox, mechanisms: [.internal]), "RESETKEY \"INBOX\" INTERNAL"),
        CommandEncodeFixture.command(.resetKey(mailbox: .inbox, mechanisms: [.internal, .init("test")]), "RESETKEY \"INBOX\" INTERNAL test"),

        CommandEncodeFixture.command(.generateAuthorizedURL([.init(urlRump: "rump1", mechanism: .internal)]), "GENURLAUTH \"rump1\" INTERNAL"),
        CommandEncodeFixture.command(.generateAuthorizedURL([.init(urlRump: "rump2", mechanism: .internal), .init(urlRump: "rump3", mechanism: .init("test"))]), "GENURLAUTH \"rump2\" INTERNAL \"rump3\" test"),

        CommandEncodeFixture.command(.namespace, #"NAMESPACE"#),
        CommandEncodeFixture.command(.uidCopy(.set(.init(range: 363...1860)), MailboxName("Drafts")), #"UID COPY 363:1860 "Drafts""#),
        CommandEncodeFixture.command(.uidMove(.set(.init(range: 1554...1554)), .inbox), #"UID MOVE 1554 "INBOX""#),
        CommandEncodeFixture.command(.uidFetch(.lastCommand, [.uid, .flags], [.changedSince(.init(modificationSequence: 66_306_787))]), #"UID FETCH $ (UID FLAGS) (CHANGEDSINCE 66306787)"#),
        CommandEncodeFixture.command(.uidSearch(key: SearchKey.answered, charset: "UTF-8", returnOptions: [.count, .max]), #"UID SEARCH RETURN (COUNT MAX) ANSWERED"#),
        CommandEncodeFixture.command(.uidStore(.set(.init(range: 4_306...6_866)), [], .flags(.add(silent: true, list: [.answered]))), #"UID STORE 4306:6866 +FLAGS.SILENT (\Answered)"#),
        CommandEncodeFixture.command(.uidExpunge(.set(.init(range: 5...73))), #"UID EXPUNGE 5:73"#),
        CommandEncodeFixture.command(.uidExpunge(.lastCommand), #"UID EXPUNGE $"#),

        CommandEncodeFixture.command(.urlFetch(["test"]), "URLFETCH test"),
        CommandEncodeFixture.command(.urlFetch(["test1", "test2"]), "URLFETCH test1 test2"),

        CommandEncodeFixture.command(.create(.inbox, []), "CREATE \"INBOX\""),
        CommandEncodeFixture.command(.create(.inbox, [.attributes([.archive, .drafts, .flagged])]), "CREATE \"INBOX\" (USE (\\Archive \\Drafts \\Flagged))"),
        CommandEncodeFixture.command(.compress(.deflate), "COMPRESS DEFLATE"),
        CommandEncodeFixture.command(.uidBatches(batchSize: 2_000), "UIDBATCHES 2000"),
        CommandEncodeFixture.command(.uidBatches(batchSize: 1_000, batchRange: 10...20), "UIDBATCHES 1000 10:20"),
        CommandEncodeFixture.command(.getJMAPAccess, "GETJMAPACCESS"),

        CommandEncodeFixture.command(.custom(name: "FOOBAR", payloads: []), "FOOBAR"),
        CommandEncodeFixture.command(.custom(name: "FOOBAR", payloads: [.verbatim(.init(string: "A B C"))]), "FOOBAR A B C"),
        CommandEncodeFixture.command(.custom(name: "FOOBAR", payloads: [.verbatim(.init(string: "A")), .verbatim(.init(string: "B"))]), "FOOBAR AB"),
        CommandEncodeFixture.command(.custom(name: "FOOBAR", payloads: [.literal(.init(string: "A"))]), #"FOOBAR "A""#),
        CommandEncodeFixture.command(.custom(name: "FOOBAR", payloads: [.literal(.init(string: "A B C"))]), #"FOOBAR "A B C""#),
        CommandEncodeFixture.command(.custom(name: "FOOBAR", payloads: [.literal(.init(string: "A")), .literal(.init(string: "B"))]), #"FOOBAR "A""B""#),
        CommandEncodeFixture.command(.custom(name: "FOOBAR", payloads: [.literal(.init(string: "A")), .verbatim(.init(string: " ")), .literal(.init(string: "B"))]), #"FOOBAR "A" "B""#),
        CommandEncodeFixture.command(.custom(name: "FOOBAR", payloads: [.literal(.init(string: "¶"))]), expectedStrings: ["FOOBAR {2}\r\n", "¶"]),
    ])
    func encode(_ fixture: CommandEncodeFixture<Command>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension CommandEncodeFixture<Command> {
    fileprivate static func command(
        _ input: Command,
        _ expectedString: String,
        options: CommandEncodingOptions = CommandEncodingOptions()
    ) -> Self {
        CommandEncodeFixture(
            input: input,
            options: options,
            expectedString: expectedString,
            encoder: { $0.writeCommand($1) }
        )
    }

    fileprivate static func command(
        _ input: Command,
        expectedStrings: [String],
        options: CommandEncodingOptions = CommandEncodingOptions()
    ) -> Self {
        CommandEncodeFixture(
            input: input,
            options: options,
            expectedStrings: expectedStrings,
            encoder: { $0.writeCommand($1) }
        )
    }
}

