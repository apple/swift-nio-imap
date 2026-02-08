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

    @Test(arguments: [
        ParseFixture.command("CAPABILITY", expected: .success(.capability)),
        ParseFixture.command("LOGOUT", expected: .success(.logout)),
        ParseFixture.command("NOOP", expected: .success(.noop)),
        ParseFixture.command("STARTTLS", expected: .success(.startTLS)),
        ParseFixture.command("CHECK", expected: .success(.check)),
        ParseFixture.command("CLOSE", expected: .success(.close)),
        ParseFixture.command("EXPUNGE", expected: .success(.expunge)),
        ParseFixture.command("UNSELECT", expected: .success(.unselect)),
        ParseFixture.command("IDLE", expected: .success(.idleStart)),
        ParseFixture.command("NAMESPACE", expected: .success(.namespace)),
        ParseFixture.command("ID NIL", expected: .success(.id(.init()))),
        ParseFixture.command("ENABLE BINARY", expected: .success(.enable([.binary]))),
        ParseFixture.command("GETMETADATA INBOX (test)", expected: .success(.getMetadata(options: [], mailbox: .inbox, entries: ["test"]))),
        ParseFixture.command("SETMETADATA INBOX (test NIL)", expected: .success(.setMetadata(mailbox: .inbox, entries: ["test": nil]))),
        ParseFixture.command("RESETKEY INBOX INTERNAL", expected: .success(.resetKey(mailbox: .inbox, mechanisms: [.internal]))),
        ParseFixture.command("GENURLAUTH rump INTERNAL", expected: .success(.generateAuthorizedURL([.init(urlRump: "rump", mechanism: .internal)]))),
        ParseFixture.command("URLFETCH test", expected: .success(.urlFetch(["test"]))),
        ParseFixture.command("COPY 1 INBOX", expected: .success(.copy(.set([1]), .inbox))),
        ParseFixture.command("DELETE INBOX", expected: .success(.delete(.inbox))),
        ParseFixture.command("MOVE $ INBOX", expected: .success(.move(.lastCommand, .inbox))),
        ParseFixture.command("SEARCH ALL", expected: .success(.search(key: .all, charset: nil, returnOptions: []))),
        ParseFixture.command("ESEARCH ALL", expected: .success(.extendedSearch(.init(key: .all)))),
        ParseFixture.command("STORE $ +FLAGS \\Answered", expected: .success(.store(.lastCommand, [], .flags(.add(silent: false, list: [.answered]))))),
        ParseFixture.command("EXAMINE INBOX", expected: .success(.examine(.inbox, .init()))),
        ParseFixture.command("LIST INBOX test", expected: .success(.list(nil, reference: .inbox, .mailbox("test"), []))),
        ParseFixture.command("LSUB INBOX test", expected: .success(.lsub(reference: .inbox, pattern: "test"))),
        ParseFixture.command("RENAME INBOX inbox2", expected: .success(.rename(from: .inbox, to: .init("inbox2"), parameters: .init()))),
        ParseFixture.command("SELECT INBOX", expected: .success(.select(.inbox, []))),
        ParseFixture.command("STATUS INBOX (SIZE)", expected: .success(.status(.inbox, [.size]))),
        ParseFixture.command("SUBSCRIBE INBOX", expected: .success(.subscribe(.inbox))),
        ParseFixture.command("UNSUBSCRIBE INBOX", expected: .success(.unsubscribe(.inbox))),
        ParseFixture.command("UID EXPUNGE 1:2", expected: .success(.uidExpunge(.set([1...2])))),
        ParseFixture.command("FETCH $ (FLAGS)", expected: .success(.fetch(.lastCommand, [.flags], .init()))),
        ParseFixture.command("LOGIN \"user\" \"password\"", expected: .success(.login(username: "user", password: "password"))),
        ParseFixture.command("AUTHENTICATE GSSAPI", expected: .success(.authenticate(mechanism: AuthenticationMechanism("GSSAPI"), initialResponse: nil))),
        ParseFixture.command("CREATE test", expected: .success(.create(.init("test"), []))),
        ParseFixture.command("GETQUOTA root", expected: .success(.getQuota(.init("root")))),
        ParseFixture.command("GETQUOTAROOT INBOX", expected: .success(.getQuotaRoot(.inbox))),
        ParseFixture.command("SETQUOTA ROOT (resource 123)", expected: .success(.setQuota(.init("ROOT"), [.init(resourceName: "resource", limit: 123)]))),
        ParseFixture.command("COMPRESS DEFLATE", expected: .success(.compress(.deflate))),
        ParseFixture.command("UIDBATCHES 2000", expected: .success(.uidBatches(batchSize: 2_000, batchRange: nil))),
        ParseFixture.command("UIDBATCHES 1000 10:20", expected: .success(.uidBatches(batchSize: 1_000, batchRange: 10...20))),
        ParseFixture.command("UIDBATCHES 500 22:22", expected: .success(.uidBatches(batchSize: 500, batchRange: 22...22))),
        ParseFixture.command("UIDBATCHES 1000 1", expected: .success(.uidBatches(batchSize: 1_000, batchRange: 1...1))),
        ParseFixture.command("GETJMAPACCESS", expected: .success(.getJMAPAccess)),
        ParseFixture.command("123", expected: .failure),
        ParseFixture.command("NOTHING", expected: .failure),
        ParseFixture.command("...", expected: .failure),
        ParseFixture.command("CAPABILITY", "", expected: .incompleteMessage),
        ParseFixture.command("CHECK", "", expected: .incompleteMessage),
    ])
    func parse(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
    }

    @Test func `parser literal length limit`() throws {
        let parser = GrammarParser(literalSizeLimit: 5)
        var b1 = ParseBuffer("{5}\r\nabcde")
        #expect(try parser.parseLiteral(buffer: &b1, tracker: .makeNewDefault) == "abcde")

        var b2 = ParseBuffer("{6}\r\nabcdef")
        #expect(throws: ExceededLiteralSizeLimitError.self) {
            try parser.parseLiteral(buffer: &b2, tracker: .makeNewDefault)
        }
    }
}

// MARK: -

extension ParseFixture<Command> {
    fileprivate static func command(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCommand
        )
    }
}

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

