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
        CommandEncodeFixture.command(
            .list(nil, reference: .inbox, .mailbox(""), [.children]),
            "LIST \"INBOX\" \"\" RETURN (CHILDREN)"
        ),

        CommandEncodeFixture.command(.namespace, "NAMESPACE"),

        CommandEncodeFixture.command(
            .login(username: "username", password: "password"),
            #"LOGIN "username" "password""#
        ),
        CommandEncodeFixture.command(
            .login(username: "david evans", password: "great password"),
            #"LOGIN "david evans" "great password""#
        ),
        CommandEncodeFixture.command(
            .login(username: #"foo\bar"#, password: #"pass"word"#),
            #"LOGIN "foo\\bar" "pass\"word""#
        ),
        CommandEncodeFixture.command(
            .login(username: "\r\n", password: "\n"),
            expectedStrings: ["LOGIN {2}\r\n", "\r\n {1}\r\n", "\n"]
        ),

        CommandEncodeFixture.command(.select(MailboxName("Events")), #"SELECT "Events""#),
        CommandEncodeFixture.command(
            .select(.inbox, [.basic(.init(key: "test", value: nil))]),
            #"SELECT "INBOX" (test)"#
        ),
        CommandEncodeFixture.command(
            .select(.inbox, [.basic(.init(key: "test1", value: nil)), .basic(.init(key: "test2", value: nil))]),
            #"SELECT "INBOX" (test1 test2)"#
        ),
        CommandEncodeFixture.command(.examine(MailboxName("Events")), #"EXAMINE "Events""#),
        CommandEncodeFixture.command(
            .examine(.inbox, [.basic(.init(key: "test", value: nil))]),
            #"EXAMINE "INBOX" (test)"#
        ),
        CommandEncodeFixture.command(.expunge, #"EXPUNGE"#),
        CommandEncodeFixture.command(.move(.set([1]), .inbox), "MOVE 1 \"INBOX\""),
        CommandEncodeFixture.command(.id([:]), "ID NIL"),
        CommandEncodeFixture.command(
            .getMetadata(options: [], mailbox: .inbox, entries: ["a"]),
            "GETMETADATA \"INBOX\" (\"a\")"
        ),
        CommandEncodeFixture.command(
            .getMetadata(options: [.maxSize(123)], mailbox: .inbox, entries: ["a"]),
            "GETMETADATA (MAXSIZE 123) \"INBOX\" (\"a\")"
        ),
        CommandEncodeFixture.command(
            .setMetadata(mailbox: .inbox, entries: ["a": nil]),
            "SETMETADATA \"INBOX\" (\"a\" NIL)"
        ),

        CommandEncodeFixture.command(
            .fetch(.set([1...40]), [.uid, .internalDate], []),
            "FETCH 1:40 (UID INTERNALDATE)"
        ),
        CommandEncodeFixture.command(
            .fetch(
                .set([77]),
                [.uid, .bodySection(peek: true, .header, nil)],
                [.changedSince(.init(modificationSequence: 707_484_939_116_871_680))]
            ),
            "FETCH 77 (UID BODY.PEEK[HEADER]) (CHANGEDSINCE 707484939116871680)"
        ),

        CommandEncodeFixture.command(.resetKey(mailbox: nil, mechanisms: []), "RESETKEY"),
        CommandEncodeFixture.command(.resetKey(mailbox: nil, mechanisms: [.internal]), "RESETKEY"),
        CommandEncodeFixture.command(
            .resetKey(mailbox: .inbox, mechanisms: [.internal]),
            "RESETKEY \"INBOX\" INTERNAL"
        ),
        CommandEncodeFixture.command(
            .resetKey(mailbox: .inbox, mechanisms: [.internal, .init("test")]),
            "RESETKEY \"INBOX\" INTERNAL test"
        ),

        CommandEncodeFixture.command(
            .generateAuthorizedURL([.init(urlRump: "rump1", mechanism: .internal)]),
            "GENURLAUTH \"rump1\" INTERNAL"
        ),
        CommandEncodeFixture.command(
            .generateAuthorizedURL([
                .init(urlRump: "rump2", mechanism: .internal), .init(urlRump: "rump3", mechanism: .init("test")),
            ]),
            "GENURLAUTH \"rump2\" INTERNAL \"rump3\" test"
        ),

        CommandEncodeFixture.command(.namespace, #"NAMESPACE"#),
        CommandEncodeFixture.command(
            .uidCopy(.set(.init(range: 363...1860)), MailboxName("Drafts")),
            #"UID COPY 363:1860 "Drafts""#
        ),
        CommandEncodeFixture.command(.uidMove(.set(.init(range: 1554...1554)), .inbox), #"UID MOVE 1554 "INBOX""#),
        CommandEncodeFixture.command(
            .uidFetch(.lastCommand, [.uid, .flags], [.changedSince(.init(modificationSequence: 66_306_787))]),
            #"UID FETCH $ (UID FLAGS) (CHANGEDSINCE 66306787)"#
        ),
        CommandEncodeFixture.command(
            .uidSearch(key: SearchKey.answered, charset: "UTF-8", returnOptions: [.count, .max]),
            #"UID SEARCH RETURN (COUNT MAX) ANSWERED"#
        ),
        CommandEncodeFixture.command(
            .uidStore(.set(.init(range: 4_306...6_866)), [], .flags(.add(silent: true, list: [.answered]))),
            #"UID STORE 4306:6866 +FLAGS.SILENT (\Answered)"#
        ),
        CommandEncodeFixture.command(.uidExpunge(.set(.init(range: 5...73))), #"UID EXPUNGE 5:73"#),
        CommandEncodeFixture.command(.uidExpunge(.lastCommand), #"UID EXPUNGE $"#),

        CommandEncodeFixture.command(.urlFetch(["test"]), "URLFETCH test"),
        CommandEncodeFixture.command(.urlFetch(["test1", "test2"]), "URLFETCH test1 test2"),

        CommandEncodeFixture.command(.create(.inbox, []), "CREATE \"INBOX\""),
        CommandEncodeFixture.command(
            .create(.inbox, [.attributes([.archive, .drafts, .flagged])]),
            "CREATE \"INBOX\" (USE (\\Archive \\Drafts \\Flagged))"
        ),
        CommandEncodeFixture.command(.compress(.deflate), "COMPRESS DEFLATE"),
        CommandEncodeFixture.command(.uidBatches(batchSize: 2_000), "UIDBATCHES 2000"),
        CommandEncodeFixture.command(.uidBatches(batchSize: 1_000, batchRange: 10...20), "UIDBATCHES 1000 10:20"),
        CommandEncodeFixture.command(.getJMAPAccess, "GETJMAPACCESS"),

        CommandEncodeFixture.command(.custom(name: "FOOBAR", payloads: []), "FOOBAR"),
        CommandEncodeFixture.command(
            .custom(name: "FOOBAR", payloads: [.verbatim(.init(string: "A B C"))]),
            "FOOBAR A B C"
        ),
        CommandEncodeFixture.command(
            .custom(name: "FOOBAR", payloads: [.verbatim(.init(string: "A")), .verbatim(.init(string: "B"))]),
            "FOOBAR AB"
        ),
        CommandEncodeFixture.command(.custom(name: "FOOBAR", payloads: [.literal(.init(string: "A"))]), #"FOOBAR "A""#),
        CommandEncodeFixture.command(
            .custom(name: "FOOBAR", payloads: [.literal(.init(string: "A B C"))]),
            #"FOOBAR "A B C""#
        ),
        CommandEncodeFixture.command(
            .custom(name: "FOOBAR", payloads: [.literal(.init(string: "A")), .literal(.init(string: "B"))]),
            #"FOOBAR "A""B""#
        ),
        CommandEncodeFixture.command(
            .custom(
                name: "FOOBAR",
                payloads: [.literal(.init(string: "A")), .verbatim(.init(string: " ")), .literal(.init(string: "B"))]
            ),
            #"FOOBAR "A" "B""#
        ),
        CommandEncodeFixture.command(
            .custom(name: "FOOBAR", payloads: [.literal(.init(string: "¶"))]),
            expectedStrings: ["FOOBAR {2}\r\n", "¶"]
        ),
        CommandEncodeFixture.command(
            .rename(from: .inbox, to: .init("other"), parameters: [:]),
            #"RENAME "INBOX" "other""#
        ),
        CommandEncodeFixture.command(
            .rename(from: .inbox, to: .init("other"), parameters: ["test": nil]),
            #"RENAME "INBOX" "other" (test)"#
        ),

        // listIndependent: select options and return options combinations
        CommandEncodeFixture.command(
            .listIndependent([.remote], reference: .inbox, .mailbox("*"), [.children]),
            #"LIST(REMOTE) "INBOX" "*" RETURN (CHILDREN)"#
        ),
        CommandEncodeFixture.command(
            .listIndependent([.specialUse], reference: .inbox, .mailbox("*"), []),
            #"LIST(SPECIAL-USE) "INBOX" "*""#
        ),
        CommandEncodeFixture.command(
            .listIndependent([.remote, .specialUse], reference: .inbox, .mailbox("*"), [.children]),
            #"LIST(REMOTE SPECIAL-USE) "INBOX" "*" RETURN (CHILDREN)"#
        ),
        CommandEncodeFixture.command(
            .listIndependent([], reference: .inbox, .mailbox("*"), [.children]),
            #"LIST "INBOX" "*" RETURN (CHILDREN)"#
        ),
        CommandEncodeFixture.command(
            .listIndependent([], reference: .inbox, .mailbox("*"), []),
            #"LIST "INBOX" "*""#
        ),

        // authenticate with initial response
        CommandEncodeFixture.command(
            .authenticate(mechanism: .gssAPI, initialResponse: .init(ByteBuffer(string: "hey"))),
            "AUTHENTICATE GSSAPI aGV5"
        ),
        CommandEncodeFixture.command(
            .authenticate(mechanism: .gssAPI, initialResponse: .empty),
            "AUTHENTICATE GSSAPI ="
        ),

        // enable
        CommandEncodeFixture.command(.enable([.binary]), "ENABLE BINARY"),
        CommandEncodeFixture.command(.enable([.binary, .acl]), "ENABLE BINARY ACL"),

        // setQuota
        CommandEncodeFixture.command(
            .setQuota(.init("ROOT"), [.init(resourceName: "STORAGE", limit: 512)]),
            #"SETQUOTA "ROOT" (STORAGE 512)"#
        ),
        CommandEncodeFixture.command(
            .setQuota(
                .init(""),
                [.init(resourceName: "STORAGE", limit: 0), .init(resourceName: "BANDWIDTH", limit: 99)]
            ),
            #"SETQUOTA "" (STORAGE 0 BANDWIDTH 99)"#
        ),

        // store with modifiers (covers write(if: modifiers.count >= 1) branch)
        CommandEncodeFixture.command(
            .store(
                .set([1]),
                [.unchangedSince(.init(modificationSequence: 5))],
                .flags(.add(silent: false, list: [.seen]))
            ),
            "STORE 1 (UNCHANGEDSINCE 5) +FLAGS (\\Seen)"
        ),
        CommandEncodeFixture.command(
            .uidStore(
                .set(.init(range: 1...5)),
                [.unchangedSince(.init(modificationSequence: 10))],
                .flags(.remove(silent: true, list: [.answered]))
            ),
            "UID STORE 1:5 (UNCHANGEDSINCE 10) -FLAGS.SILENT (\\Answered)"
        ),
    ])
    func encode(_ fixture: CommandEncodeFixture<Command>) {
        fixture.checkEncoding()
    }

    @Test("Command debugDescription")
    func commandDebugDescription() {
        #expect(Command.noop.debugDescription == "NOOP")
        #expect(Command.capability.debugDescription == "CAPABILITY")
        #expect(Command.select(.inbox, []).debugDescription == "SELECT \"INBOX\"")
    }

    @Test("authenticate with initialResponse in loggingMode")
    func authenticateWithInitialResponseLoggingMode() {
        var buffer = CommandEncodeBuffer(
            buffer: ByteBufferAllocator().buffer(capacity: 64),
            capabilities: [],
            loggingMode: true
        )
        _ = buffer.writeCommand(.authenticate(mechanism: .gssAPI, initialResponse: .init(ByteBuffer(string: "secret"))))
        #expect(String(buffer: buffer.buffer.nextChunk().bytes) == "AUTHENTICATE GSSAPI ∅")
    }

    @Test("UID convenience functions return nil for empty UIDSet")
    func uidConvenienceFunctionsReturnNilForEmpty() {
        #expect(Command.uidMove(messages: UIDSet(), mailbox: .inbox) == nil)
        #expect(Command.uidCopy(messages: UIDSet(), mailbox: .inbox) == nil)
        #expect(Command.uidFetch(messages: UIDSet(), attributes: [.flags], modifiers: []) == nil)
        #expect(
            Command.uidStore(messages: UIDSet(), modifiers: [], data: .flags(.add(silent: false, list: [.seen]))) == nil
        )
        #expect(Command.uidExpunge(messages: UIDSet(), mailbox: .inbox) == nil)
    }

    @Test("UID convenience functions return command for non-empty UIDSet")
    func uidConvenienceFunctionsReturnCommandForNonEmpty() {
        #expect(Command.uidMove(messages: [1...10], mailbox: .inbox) != nil)
        #expect(Command.uidCopy(messages: [1...10], mailbox: .inbox) != nil)
        #expect(Command.uidFetch(messages: [1...10], attributes: [.flags], modifiers: []) != nil)
        #expect(
            Command.uidStore(messages: [1...10], modifiers: [], data: .flags(.add(silent: false, list: [.seen]))) != nil
        )
        #expect(Command.uidExpunge(messages: [1...10], mailbox: .inbox) != nil)
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
        ParseFixture.command("nameSPACE", " ", expected: .success(.namespace)),
        ParseFixture.command("namespace", " ", expected: .success(.namespace)),
        ParseFixture.command("ID NIL", expected: .success(.id(.init()))),
        ParseFixture.command("ENABLE BINARY", expected: .success(.enable([.binary]))),
        ParseFixture.command(
            "GETMETADATA INBOX (test)",
            expected: .success(.getMetadata(options: [], mailbox: .inbox, entries: ["test"]))
        ),
        ParseFixture.command(
            "SETMETADATA INBOX (test NIL)",
            expected: .success(.setMetadata(mailbox: .inbox, entries: ["test": nil]))
        ),
        ParseFixture.command(
            "RESETKEY INBOX INTERNAL",
            expected: .success(.resetKey(mailbox: .inbox, mechanisms: [.internal]))
        ),
        ParseFixture.command(
            "GENURLAUTH rump INTERNAL",
            expected: .success(.generateAuthorizedURL([.init(urlRump: "rump", mechanism: .internal)]))
        ),
        ParseFixture.command("URLFETCH test", expected: .success(.urlFetch(["test"]))),
        ParseFixture.command("COPY 1 INBOX", expected: .success(.copy(.set([1]), .inbox))),
        ParseFixture.command("COPY 1,2,3 inbox", " ", expected: .success(.copy(.set([1, 2, 3]), .inbox))),
        ParseFixture.command("DELETE INBOX", expected: .success(.delete(.inbox))),
        ParseFixture.command("DELete inbox", "\n", expected: .success(.delete(.inbox))),
        ParseFixture.command("MOVE $ INBOX", expected: .success(.move(.lastCommand, .inbox))),
        ParseFixture.command("SEARCH ALL", expected: .success(.search(key: .all, charset: nil, returnOptions: []))),
        ParseFixture.command("ESEARCH ALL", expected: .success(.extendedSearch(.init(key: .all)))),
        ParseFixture.command(
            "STORE $ +FLAGS \\Answered",
            expected: .success(.store(.lastCommand, [], .flags(.add(silent: false, list: [.answered]))))
        ),
        ParseFixture.command("EXAMINE INBOX", expected: .success(.examine(.inbox, .init()))),
        ParseFixture.command(
            "LIST INBOX test",
            expected: .success(.list(nil, reference: .inbox, .mailbox("test"), []))
        ),
        ParseFixture.command("LSUB INBOX test", expected: .success(.lsub(reference: .inbox, pattern: "test"))),
        ParseFixture.command(
            "RENAME INBOX inbox2",
            expected: .success(.rename(from: .inbox, to: .init("inbox2"), parameters: .init()))
        ),
        ParseFixture.command(
            "RENAME box1 box2",
            expected: .success(.rename(from: .init("box1"), to: .init("box2"), parameters: [:]))
        ),
        ParseFixture.command(
            "rename box3 box4",
            expected: .success(.rename(from: .init("box3"), to: .init("box4"), parameters: [:]))
        ),
        ParseFixture.command(
            "RENAME box5 box6 (test)",
            expected: .success(.rename(from: .init("box5"), to: .init("box6"), parameters: ["test": nil]))
        ),
        ParseFixture.command(
            "RENAME box5 box6 (test1 test2)",
            expected: .success(
                .rename(from: .init("box5"), to: .init("box6"), parameters: ["test1": nil, "test2": nil])
            )
        ),
        ParseFixture.command("SELECT INBOX", expected: .success(.select(.inbox, []))),
        ParseFixture.command("STATUS INBOX (SIZE)", expected: .success(.status(.inbox, [.size]))),
        ParseFixture.command("SUBSCRIBE INBOX", expected: .success(.subscribe(.inbox))),
        ParseFixture.command("SUBSCRIBE inbox", "\r\n", expected: .success(.subscribe(.inbox))),
        ParseFixture.command("SUBScribe INBOX", "\r\n", expected: .success(.subscribe(.inbox))),
        ParseFixture.command("UNSUBSCRIBE INBOX", expected: .success(.unsubscribe(.inbox))),
        ParseFixture.command("UNSUBSCRIBE inbox", "\r\n", expected: .success(.unsubscribe(.inbox))),
        ParseFixture.command("UNSUBScribe INBOX", "\r\n", expected: .success(.unsubscribe(.inbox))),
        ParseFixture.command("UID EXPUNGE 1:2", expected: .success(.uidExpunge(.set([1...2])))),
        ParseFixture.command("FETCH $ (FLAGS)", expected: .success(.fetch(.lastCommand, [.flags], .init()))),
        ParseFixture.command(
            "LOGIN \"user\" \"password\"",
            expected: .success(.login(username: "user", password: "password"))
        ),
        ParseFixture.command(
            "AUTHENTICATE GSSAPI",
            expected: .success(.authenticate(mechanism: AuthenticationMechanism("GSSAPI"), initialResponse: nil))
        ),
        ParseFixture.command("CREATE test", expected: .success(.create(.init("test"), []))),
        ParseFixture.command("GETQUOTA root", expected: .success(.getQuota(.init("root")))),
        ParseFixture.command("GETQUOTAROOT INBOX", expected: .success(.getQuotaRoot(.inbox))),
        ParseFixture.command(
            "SETQUOTA ROOT (resource 123)",
            expected: .success(.setQuota(.init("ROOT"), [.init(resourceName: "resource", limit: 123)]))
        ),
        ParseFixture.command("COMPRESS DEFLATE", expected: .success(.compress(.deflate))),
        ParseFixture.command("UIDBATCHES 2000", expected: .success(.uidBatches(batchSize: 2_000, batchRange: nil))),
        ParseFixture.command(
            "UIDBATCHES 1000 10:20",
            expected: .success(.uidBatches(batchSize: 1_000, batchRange: 10...20))
        ),
        ParseFixture.command(
            "UIDBATCHES 500 22:22",
            expected: .success(.uidBatches(batchSize: 500, batchRange: 22...22))
        ),
        ParseFixture.command("UIDBATCHES 1000 1", expected: .success(.uidBatches(batchSize: 1_000, batchRange: 1...1))),
        ParseFixture.command("GETJMAPACCESS", expected: .success(.getJMAPAccess)),
        ParseFixture.command("123", expected: .failure),
        ParseFixture.command("NOTHING", expected: .failure),
        ParseFixture.command("...", expected: .failure),
        ParseFixture.command("something", " ", expected: .failure),
        ParseFixture.command("SUBSCRIBE ", expected: .failure),
        ParseFixture.command("UNSUBSCRIBE \r", " ", expected: .failure),
        ParseFixture.command("RENAME box1 ", expected: .failure),
        ParseFixture.command("COPY 1,2,3,4 ", "", expected: .failureIgnoringBufferModifications),
        ParseFixture.command("COPY inbox ", "", expected: .failureIgnoringBufferModifications),
        ParseFixture.command("CAPABILITY", "", expected: .incompleteMessage),
        ParseFixture.command("CHECK", "", expected: .incompleteMessage),
        ParseFixture.command("", "", expected: .incompleteMessage),
        ParseFixture.command("name", "", expected: .incompleteMessage),
        ParseFixture.command("SUBSCRIBE ", "", expected: .incompleteMessage),
        ParseFixture.command("UNSUBSCRIBE", " ", expected: .incompleteMessage),
        ParseFixture.command("RENAME box1 ", "", expected: .incompleteMessage),
        ParseFixture.command("DELETE ", "", expected: .incompleteMessageIgnoringBufferModifications),
    ])
    func parse(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
    }

    @Test("parser literal length limit") func parserLiteralLengthLimit() throws {
        let parser = GrammarParser(literalSizeLimit: 5)
        var b1 = ParseBuffer("{5}\r\nabcde")
        #expect(try parser.parseLiteral(buffer: &b1, tracker: .makeNewDefault) == "abcde")

        var b2 = ParseBuffer("{6}\r\nabcdef")
        #expect(throws: ExceededLiteralSizeLimitError.self) {
            try parser.parseLiteral(buffer: &b2, tracker: .makeNewDefault)
        }
    }

    @Test("parse ID suffix", arguments: [
        ParseFixture.idSuffix(" ()", expected: .success(.id([:]))),
        ParseFixture.idSuffix(" nil", expected: .success(.id([:]))),
        ParseFixture.idSuffix(#" ("name" "some")"#, expected: .success(.id(["name": "some"]))),
        ParseFixture.idSuffix(#" ("k1" "v1" "k2" "v2")"#, expected: .success(.id(["k1": "v1", "k2": "v2"]))),
        ParseFixture.idSuffix(" ~", "", expected: .failure),
        ParseFixture.idSuffix(" []", "", expected: .failure),
        ParseFixture.idSuffix(" (\"name\"", "", expected: .incompleteMessage),
        ParseFixture.idSuffix(" (\"name\" \"some\"", "", expected: .incompleteMessage),
    ])
    func parseIdSuffix(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
    }

    @Test("parse ENABLE suffix", arguments: [
        ParseFixture.enableSuffix(" ACL", expected: .success(.enable([.acl]))),
        ParseFixture.enableSuffix(" ACL BINARY CHILDREN", expected: .success(.enable([.acl, .binary, .children]))),
        ParseFixture.enableSuffix(" (ACL)", expected: .failure),
        ParseFixture.enableSuffix(" ACL", "", expected: .incompleteMessage),
    ])
    func parseEnableSuffix(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
    }

    @Test("parse GETMETADATA suffix", arguments: [
        ParseFixture.getMetadataSuffix(
            " INBOX a",
            " ",
            expected: .success(.getMetadata(options: [], mailbox: .inbox, entries: ["a"]))
        ),
        ParseFixture.getMetadataSuffix(
            " (MAXSIZE 123) INBOX (a b)",
            " ",
            expected: .success(.getMetadata(options: [.maxSize(123)], mailbox: .inbox, entries: ["a", "b"]))
        ),
        ParseFixture.getMetadataSuffix(" (MAXSIZE 123 rogue) INBOX", expected: .failure),
        ParseFixture.getMetadataSuffix(" (key", "", expected: .incompleteMessage),
        ParseFixture.getMetadataSuffix(" (key value", "", expected: .incompleteMessage),
        ParseFixture.getMetadataSuffix(" (MAXSIZE 123) INBOX", "", expected: .incompleteMessage),
    ])
    func parseGetMetadataSuffix(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
    }

    @Test("parse SETMETADATA suffix", arguments: [
        ParseFixture.setMetadataSuffix(
            " INBOX (a NIL)",
            " ",
            expected: .success(.setMetadata(mailbox: .inbox, entries: ["a": .init(nil)]))
        ),
        ParseFixture.setMetadataSuffix(" (a NIL)", "", expected: .failure),
        ParseFixture.setMetadataSuffix(" INBOX", "", expected: .incompleteMessage),
        ParseFixture.setMetadataSuffix(" INBOX (", "", expected: .incompleteMessage),
        ParseFixture.setMetadataSuffix(" INBOX (a", "", expected: .incompleteMessage),
    ])
    func parseSetMetadataSuffix(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
    }

    @Test("parse RESETKEY suffix", arguments: [
        ParseFixture.resetKeySuffix("", expected: .success(.resetKey(mailbox: nil, mechanisms: []))),
        ParseFixture.resetKeySuffix(" INBOX", expected: .success(.resetKey(mailbox: .inbox, mechanisms: []))),
        ParseFixture.resetKeySuffix(
            " INBOX INTERNAL",
            expected: .success(.resetKey(mailbox: .inbox, mechanisms: [.internal]))
        ),
        ParseFixture.resetKeySuffix(
            " INBOX INTERNAL test",
            expected: .success(.resetKey(mailbox: .inbox, mechanisms: [.internal, .init("test")]))
        ),
        ParseFixture.resetKeySuffix(" INBOX", "", expected: .incompleteMessage),
        ParseFixture.resetKeySuffix(" INBOX INTERNAL", "", expected: .incompleteMessage),
        ParseFixture.resetKeySuffix(" INBOX INTERNAL test", "", expected: .incompleteMessage),
    ])
    func parseResetKeySuffix(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
    }

    @Test("parse GENURLAUTH suffix", arguments: [
        ParseFixture.genURLAuthSuffix(
            " test INTERNAL",
            expected: .success(.generateAuthorizedURL([.init(urlRump: "test", mechanism: .internal)]))
        ),
        ParseFixture.genURLAuthSuffix(
            " test INTERNAL test2 INTERNAL",
            expected: .success(
                .generateAuthorizedURL([
                    .init(urlRump: "test", mechanism: .internal), .init(urlRump: "test2", mechanism: .internal),
                ])
            )
        ),
        ParseFixture.genURLAuthSuffix(" \\", "", expected: .failure),
        ParseFixture.genURLAuthSuffix(" ", "", expected: .incompleteMessage),
        ParseFixture.genURLAuthSuffix(" test", "", expected: .incompleteMessage),
        ParseFixture.genURLAuthSuffix(" test internal", "", expected: .incompleteMessage),
    ])
    func parseGenURLAuthSuffix(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
    }

    @Test("parse URLFETCH suffix", arguments: [
        ParseFixture.urlFetchSuffix(" test", expected: .success(.urlFetch(["test"]))),
        ParseFixture.urlFetchSuffix(" test1 test2", expected: .success(.urlFetch(["test1", "test2"]))),
        ParseFixture.urlFetchSuffix(" \\ ", "", expected: .failure),
        ParseFixture.urlFetchSuffix(" test", "", expected: .incompleteMessage),
        ParseFixture.urlFetchSuffix(" test1 test2 test3", "", expected: .incompleteMessage),
    ])
    func parseUrlFetchSuffix(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
    }

    @Test("parse COPY suffix", arguments: [
        ParseFixture.copySuffix(" $ inbox", expected: .success(.copy(.lastCommand, .inbox))),
        ParseFixture.copySuffix(" 1 inbox", expected: .success(.copy(.set([1]), .inbox))),
        ParseFixture.copySuffix(" 1,5,7 inbox", expected: .success(.copy(.set([1, 5, 7]), .inbox))),
        ParseFixture.copySuffix(" 1:100 inbox", expected: .success(.copy(.set([1...100]), .inbox))),
        ParseFixture.copySuffix(" a inbox", expected: .failure),
        ParseFixture.copySuffix(" 1: inbox", expected: .failure),
        ParseFixture.copySuffix(" 1", "", expected: .incompleteMessage),
        ParseFixture.copySuffix(" 1 inbox", "", expected: .incompleteMessage),
    ])
    func parseCopySuffix(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
    }

    @Test("parse DELETE suffix", arguments: [
        ParseFixture.deleteSuffix(" INBOX", "\r\n", expected: .success(.delete(.inbox))),
        ParseFixture.deleteSuffix(" {5}12345", " ", expected: .failure),
        ParseFixture.deleteSuffix(" INBOX", "", expected: .incompleteMessage),
    ])
    func parseDeleteSuffix(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
    }

    @Test("parse MOVE suffix", arguments: [
        ParseFixture.moveSuffix(" $ inbox", expected: .success(.move(.lastCommand, .inbox))),
        ParseFixture.moveSuffix(" 1 inbox", expected: .success(.move(.set([1]), .inbox))),
        ParseFixture.moveSuffix(" 1,5,7 inbox", expected: .success(.move(.set([1, 5, 7]), .inbox))),
        ParseFixture.moveSuffix(" 1:100 inbox", expected: .success(.move(.set([1...100]), .inbox))),
        ParseFixture.moveSuffix(" a inbox", expected: .failure),
        ParseFixture.moveSuffix(" 1: inbox", expected: .failure),
        ParseFixture.moveSuffix(" 1", "", expected: .incompleteMessage),
        ParseFixture.moveSuffix(" 1 inbox", "", expected: .incompleteMessage),
    ])
    func parseMoveSuffix(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
    }

    @Test("parse SEARCH suffix", arguments: [
        ParseFixture.searchSuffix(" ALL", expected: .success(.search(key: .all))),
        ParseFixture.searchSuffix(
            " ALL DELETED FLAGGED",
            expected: .success(.search(key: .and([.all, .deleted, .flagged])))
        ),
        ParseFixture.searchSuffix(" CHARSET UTF-8 ALL", expected: .success(.search(key: .all, charset: "UTF-8"))),
        ParseFixture.searchSuffix(" DELETED", expected: .success(.search(key: .deleted, returnOptions: []))),
        ParseFixture.searchSuffix(
            " RETURN () DELETED",
            expected: .success(.search(key: .deleted, returnOptions: [.all]))
        ),
        ParseFixture.searchSuffix(
            " RETURN (ALL) DELETED",
            expected: .success(.search(key: .deleted, returnOptions: [.all]))
        ),
        ParseFixture.searchSuffix(
            " RETURN (ALL COUNT) ANSWERED",
            expected: .success(.search(key: .answered, returnOptions: [.all, .count]))
        ),
        ParseFixture.searchSuffix(" RETURN (MIN) ALL", expected: .success(.search(key: .all, returnOptions: [.min]))),
        ParseFixture.searchSuffix(
            #" CHARSET UTF-8 (OR FROM "me" FROM "you") (OR NEW UNSEEN)"#,
            expected: .success(
                .search(key: .and([.or(.from("me"), .from("you")), .or(.new, .unseen)]), charset: "UTF-8")
            )
        ),
        ParseFixture.searchSuffix(
            #" RETURN (MIN MAX) CHARSET UTF-8 OR (FROM "me" FROM "you") (NEW UNSEEN)"#,
            expected: .success(
                .search(
                    key: .or(.and([.from("me"), .from("you")]), .and([.new, .unseen])),
                    charset: "UTF-8",
                    returnOptions: [.min, .max]
                )
            )
        ),
        ParseFixture.searchSuffix(
            " (ALL SEEN)",
            expected: .success(.search(key: .and([.all, .seen])))
        ),
    ])
    func parseSearchSuffix(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
    }

    @Test("parse ESEARCH suffix", arguments: [
        ParseFixture.esearchSuffix(" ALL", expected: .success(.extendedSearch(.init(key: .all)))),
        ParseFixture.esearchSuffix(
            " IN (mailboxes \"folder1\" subtree \"folder2\") unseen",
            expected: .success(
                .extendedSearch(
                    ExtendedSearchOptions(
                        key: .unseen,
                        charset: nil,
                        returnOptions: [],
                        sourceOptions: ExtendedSearchSourceOptions(sourceMailbox: [
                            .mailboxes(Mailboxes([MailboxName("folder1")])!),
                            .subtree(Mailboxes([MailboxName("folder2")])!),
                        ])
                    )
                )
            )
        ),
        ParseFixture.esearchSuffix(" IN (mailboxes ", "", expected: .incompleteMessage),
    ])
    func parseEsearchSuffix(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
    }

    @Test("parse STORE suffix", arguments: [
        ParseFixture.storeSuffix(
            " 1 +FLAGS \\answered",
            expected: .success(.store(.set([1]), [], .flags(.add(silent: false, list: [.answered]))))
        ),
        ParseFixture.storeSuffix(
            " 1 (label) -FLAGS \\seen",
            expected: .success(
                .store(
                    .set([1]),
                    [.other(.init(key: "label", value: nil))],
                    .flags(.remove(silent: false, list: [.seen]))
                )
            )
        ),
        ParseFixture.storeSuffix(
            " 1 (label UNCHANGEDSINCE 5) -FLAGS \\seen",
            expected: .success(
                .store(
                    .set([1]),
                    [.other(.init(key: "label", value: nil)), .unchangedSince(.init(modificationSequence: 5))],
                    .flags(.remove(silent: false, list: [.seen]))
                )
            )
        ),
        ParseFixture.storeSuffix(" +FLAGS \\answered", expected: .failure),
        ParseFixture.storeSuffix(" ", "", expected: .incompleteMessage),
        ParseFixture.storeSuffix(" 1 ", "", expected: .incompleteMessage),
    ])
    func parseStoreSuffix(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
    }

    @Test("parse EXAMINE suffix", arguments: [
        ParseFixture.examineSuffix("EXAMINE inbox", expected: .success(.examine(.inbox, []))),
        ParseFixture.examineSuffix("examine inbox", expected: .success(.examine(.inbox, []))),
        ParseFixture.examineSuffix(
            "EXAMINE inbox (number)",
            expected: .success(.examine(.inbox, [.basic(.init(key: "number", value: nil))]))
        ),
    ])
    func parseExamineSuffix(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
    }

    @Test("parse LIST suffix", arguments: [
        ParseFixture.listSuffix(
            #" "" """#,
            expected: .success(.list(nil, reference: MailboxName(""), .mailbox(""), []))
        ),
        // with return options only
        ParseFixture.listSuffix(
            #" "" "" RETURN (CHILDREN)"#,
            expected: .success(.list(nil, reference: MailboxName(""), .mailbox(""), [.children]))
        ),
        ParseFixture.listSuffix(
            #" "" "" RETURN (CHILDREN SUBSCRIBED)"#,
            expected: .success(.list(nil, reference: MailboxName(""), .mailbox(""), [.children, .subscribed]))
        ),
        // with select options (triggers parseListSelectOptions)
        ParseFixture.listSuffix(
            " (SUBSCRIBED) \"\" \"\"",
            expected: .success(
                .list(.init(baseOption: .subscribed, options: []), reference: MailboxName(""), .mailbox(""), [])
            )
        ),
        ParseFixture.listSuffix(
            " (REMOTE SUBSCRIBED) \"\" \"\"",
            expected: .success(
                .list(.init(baseOption: .subscribed, options: [.remote]), reference: MailboxName(""), .mailbox(""), [])
            )
        ),
        ParseFixture.listSuffix(
            " (SPECIAL-USE SUBSCRIBED) INBOX * RETURN (CHILDREN)",
            expected: .success(
                .list(
                    .init(baseOption: .subscribed, options: [.specialUse]),
                    reference: .inbox,
                    .mailbox("*"),
                    [.children]
                )
            )
        ),
        ParseFixture.listSuffix(
            " (RECURSIVEMATCH SUBSCRIBED) \"\" \"\"",
            expected: .success(
                .list(
                    .init(baseOption: .subscribed, options: [.recursiveMatch]),
                    reference: MailboxName(""),
                    .mailbox(""),
                    []
                )
            )
        ),
    ])
    func parseListSuffix(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
    }

    @Test("parse LSUB suffix", arguments: [
        ParseFixture.LSUBSuffix(
            " inbox someList",
            " ",
            expected: .success(.lsub(reference: .inbox, pattern: "someList"))
        ),
        ParseFixture.LSUBSuffix(
            " \"inbox\" \"someList\"",
            " ",
            expected: .success(.lsub(reference: .inbox, pattern: "someList"))
        ),
        ParseFixture.LSUBSuffix(" {5}inbox", "", expected: .failure),
        ParseFixture.LSUBSuffix(" inbox", "", expected: .incompleteMessage),
        ParseFixture.LSUBSuffix(" inbox list", "", expected: .incompleteMessage),
    ])
    func parseLSUBSuffix(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
    }

    @Test("parse RENAME suffix", arguments: [
        ParseFixture.renameSuffix(
            " box1 box2",
            expected: .success(
                .rename(from: .init(.init(string: "box1")), to: .init(.init(string: "box2")), parameters: [:])
            )
        ),
        ParseFixture.renameSuffix(" {2}b1 {2}b2", "", expected: .failure),
        ParseFixture.renameSuffix(" {2}\r\nb1 {2}b2", "", expected: .failure),
        ParseFixture.renameSuffix(" box1", "", expected: .incompleteMessage),
        ParseFixture.renameSuffix(" box1 box2", "", expected: .incompleteMessage),
    ])
    func parseRenameSuffix(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
    }

    @Test("parse SELECT suffix", arguments: [
        ParseFixture.selectSuffix(" inbox", expected: .success(.select(.inbox, []))),
        ParseFixture.selectSuffix(
            " inbox (some1)",
            expected: .success(.select(.inbox, [.basic(.init(key: "some1", value: nil))]))
        ),
        ParseFixture.selectSuffix(" ", expected: .failure),
        ParseFixture.selectSuffix(" ", "", expected: .incompleteMessage),
    ])
    func parseSelectSuffix(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
    }

    @Test("parse STATUS suffix", arguments: [
        ParseFixture.statusSuffix(
            " inbox (messages unseen)",
            "\r\n",
            expected: .success(.status(.inbox, [.messageCount, .unseenCount]))
        ),
        ParseFixture.statusSuffix(
            " Deleted (messages unseen HIGHESTMODSEQ)",
            "\r\n",
            expected: .success(
                .status(MailboxName("Deleted"), [.messageCount, .unseenCount, .highestModificationSequence])
            )
        ),
        ParseFixture.statusSuffix(" inbox (messages unseen", "\r\n", expected: .failure),
        ParseFixture.statusSuffix("", "", expected: .incompleteMessage),
        ParseFixture.statusSuffix(" Deleted (messages ", "", expected: .incompleteMessage),
    ])
    func parseStatusSuffix(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
    }

    @Test("parse SUBSCRIBE suffix", arguments: [
        ParseFixture.subscribeSuffix(" INBOX", expected: .success(.subscribe(.inbox))),
        ParseFixture.subscribeSuffix("inbox", "", expected: .failure),
        ParseFixture.subscribeSuffix(" inbox", "", expected: .incompleteMessage),
    ])
    func parseSubscribeSuffix(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
    }

    @Test("parse UNSUBSCRIBE suffix", arguments: [
        ParseFixture.unsubscribeSuffix(" inbox", expected: .success(.unsubscribe(.inbox))),
        ParseFixture.unsubscribeSuffix("inbox", "", expected: .failure),
        ParseFixture.unsubscribeSuffix(" inbox", "", expected: .incompleteMessage),
    ])
    func parseUnsubscribeSuffix(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
    }

    @Test("parse UID suffix", arguments: [
        ParseFixture.uidSuffix(" EXPUNGE 1", "\r\n", expected: .success(.uidExpunge(.set([1])))),
        ParseFixture.uidSuffix(" COPY 1 Inbox", "\r\n", expected: .success(.uidCopy(.set([1]), .inbox))),
        ParseFixture.uidSuffix(" FETCH 1 FLAGS", "\r\n", expected: .success(.uidFetch(.set([1]), [.flags], []))),
        ParseFixture.uidSuffix(
            " SEARCH CHARSET UTF8 ALL",
            "\r\n",
            expected: .success(.uidSearch(key: .all, charset: "UTF8"))
        ),
        ParseFixture.uidSuffix(
            " STORE 1 +FLAGS (Test)",
            "\r\n",
            expected: .success(.uidStore(.set([1]), [], .flags(.add(silent: false, list: ["Test"]))))
        ),
        ParseFixture.uidSuffix(
            " STORE 1 (UNCHANGEDSINCE 5 test) +FLAGS (Test)",
            "\r\n",
            expected: .success(
                .uidStore(
                    .set([1]),
                    [.unchangedSince(.init(modificationSequence: 5)), .other(.init(key: "test", value: nil))],
                    .flags(.add(silent: false, list: ["Test"]))
                )
            )
        ),
        ParseFixture.uidSuffix(
            " COPY * Inbox",
            "\r\n",
            expected: .success(.uidCopy(.set([MessageIdentifierRange<UID>(.max)]), .inbox))
        ),
        ParseFixture.uidSuffix("UID RENAME inbox other", " ", expected: .failure),
    ])
    func parseUidSuffix(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
    }

    @Test("parse FETCH suffix", arguments: [
        ParseFixture.fetchSuffix(" 1:3 ALL", expected: .success(.fetch(.set([1...3]), .all, []))),
        ParseFixture.fetchSuffix(" 2:4 FULL", expected: .success(.fetch(.set([2...4]), .full, []))),
        ParseFixture.fetchSuffix(" 3:5 FAST", expected: .success(.fetch(.set([3...5]), .fast, []))),
        ParseFixture.fetchSuffix(" 4:6 ENVELOPE", expected: .success(.fetch(.set([4...6]), [.envelope], []))),
        ParseFixture.fetchSuffix(
            " 5:7 (ENVELOPE FLAGS)",
            expected: .success(.fetch(.set([5...7]), [.envelope, .flags], []))
        ),
        ParseFixture.fetchSuffix(
            " 3:5 FAST (name)",
            expected: .success(.fetch(.set([3...5]), .fast, [.other(.init(key: "name", value: nil))]))
        ),
        ParseFixture.fetchSuffix(
            " 1 BODY[TEXT]",
            expected: .success(.fetch(.set([1]), [.bodySection(peek: false, .init(kind: .text), nil)], []))
        ),
    ])
    func parseFetchSuffix(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
    }

    @Test("parse LOGIN suffix", arguments: [
        ParseFixture.loginSuffix(
            " email password",
            expected: .success(.login(username: "email", password: "password"))
        ),
        ParseFixture.loginSuffix(
            " \"email\" \"password\"",
            expected: .success(.login(username: "email", password: "password"))
        ),
        ParseFixture.loginSuffix(
            " {5}\r\nemail {8}\r\npassword",
            expected: .success(.login(username: "email", password: "password"))
        ),
        ParseFixture.loginSuffix("email password", "", expected: .failure),
        ParseFixture.loginSuffix(" email", "", expected: .incompleteMessage),
        ParseFixture.loginSuffix(" email password", "", expected: .incompleteMessage),
        ParseFixture.loginSuffix(" {5}\r\nemail {8}", "", expected: .incompleteMessage),
    ])
    func parseLoginSuffix(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
    }

    @Test("parse user ID", arguments: [
        ParseFixture.userId("test", " ", expected: .success("test")),
        ParseFixture.userId("{4}\r\ntest", " ", expected: .success("test")),
        ParseFixture.userId("{4+}\r\ntest", " ", expected: .success("test")),
        ParseFixture.userId("\"test\"", " ", expected: .success("test")),
        ParseFixture.userId("\\\\", "", expected: .failure),
        ParseFixture.userId("aaa", "", expected: .incompleteMessage),
        ParseFixture.userId("{1}\r\n", "", expected: .incompleteMessage),
    ])
    func parseUserId(_ fixture: ParseFixture<String>) {
        fixture.checkParsing()
    }

    @Test("parse AUTHENTICATE suffix", arguments: [
        ParseFixture.authenticateSuffix(
            " GSSAPI",
            expected: .success(.authenticate(mechanism: .gssAPI, initialResponse: nil))
        ),
        ParseFixture.authenticateSuffix(
            " GSSAPI aGV5",
            expected: .success(.authenticate(mechanism: .gssAPI, initialResponse: .init(.init(.init(string: "hey")))))
        ),
        ParseFixture.authenticateSuffix(" \"GSSAPI\"", "", expected: .failure),
        ParseFixture.authenticateSuffix(" gssapi", "", expected: .incompleteMessage),
    ])
    func parseAuthenticateSuffix(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
    }

    @Test("parse CREATE suffix", arguments: [
        ParseFixture.createSuffix(" inbox", expected: .success(.create(.inbox, []))),
        ParseFixture.createSuffix(
            " inbox (some)",
            expected: .success(.create(.inbox, [.labelled(.init(key: "some", value: nil))]))
        ),
        ParseFixture.createSuffix(" inbox (USE (\\All))", expected: .success(.create(.inbox, [.attributes([.all])]))),
        ParseFixture.createSuffix(
            " inbox (USE (\\All \\Flagged))",
            expected: .success(.create(.inbox, [.attributes([.all, .flagged])]))
        ),
        ParseFixture.createSuffix(
            " inbox (USE (\\All \\Flagged) some1 2 USE (\\Sent))",
            expected: .success(
                .create(
                    .inbox,
                    [
                        .attributes([.all, .flagged]), .labelled(.init(key: "some1", value: .sequence(.set([2])))),
                        .attributes([.sent]),
                    ]
                )
            )
        ),
        ParseFixture.createSuffix(" inbox", "", expected: .incompleteMessage),
        ParseFixture.createSuffix(" inbox (USE", "", expected: .incompleteMessage),
    ])
    func parseCreateSuffix(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
    }

    @Test("parse GETQUOTA suffix", arguments: [
        ParseFixture.getQuotaSuffix(" \"\"", expected: .success(.getQuota(.init("")))),
        ParseFixture.getQuotaSuffix(" \"quota\"", expected: .success(.getQuota(.init("quota")))),
        ParseFixture.getQuotaSuffix(" {5}quota", expected: .failure),
        ParseFixture.getQuotaSuffix(" \"root", "", expected: .incompleteMessage),
    ])
    func parseGetQuotaSuffix(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
    }

    @Test("parse SETQUOTA suffix", arguments: [
        ParseFixture.setQuotaSuffix(
            #" "" (STORAGE 512)"#,
            expected: .success(.setQuota(.init(""), [.init(resourceName: "STORAGE", limit: 512)]))
        ),
        ParseFixture.setQuotaSuffix(
            #" "" (STORAGE 512 BANDWIDTH 123)"#,
            expected: .success(
                .setQuota(
                    .init(""),
                    [.init(resourceName: "STORAGE", limit: 512), .init(resourceName: "BANDWIDTH", limit: 123)]
                )
            )
        ),
        ParseFixture.setQuotaSuffix(#" "" STORAGE 512"#, "", expected: .failure),
        ParseFixture.setQuotaSuffix(#" ""#, "", expected: .incompleteMessage),
        ParseFixture.setQuotaSuffix(#" "root"#, "", expected: .incompleteMessage),
        ParseFixture.setQuotaSuffix(#" "root" ("#, "", expected: .incompleteMessage),
        ParseFixture.setQuotaSuffix(#" "root" (STORAGE"#, "", expected: .incompleteMessage),
        ParseFixture.setQuotaSuffix(#" "root" (STORAGE 123"#, "", expected: .incompleteMessage),
    ])
    func parseSetQuotaSuffix(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
    }

    @Test("parse GETQUOTAROOT suffix", arguments: [
        ParseFixture.getQuotaRootSuffix(" INBOX", expected: .success(.getQuotaRoot(.inbox))),
        ParseFixture.getQuotaRootSuffix(" \"INBOX\"", expected: .success(.getQuotaRoot(.inbox))),
        ParseFixture.getQuotaRootSuffix(" {5}\r\nINBOX", expected: .success(.getQuotaRoot(.inbox))),
        ParseFixture.getQuotaRootSuffix(" {5}INBOX", "", expected: .failure),
        ParseFixture.getQuotaRootSuffix(" INBOX", "", expected: .incompleteMessage),
    ])
    func parseGetQuotaRootSuffix(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
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

    fileprivate static func idSuffix(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCommandSuffix_id
        )
    }

    fileprivate static func enableSuffix(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCommandSuffix_enable
        )
    }

    fileprivate static func getMetadataSuffix(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCommandSuffix_getMetadata
        )
    }

    fileprivate static func setMetadataSuffix(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCommandSuffix_setMetadata
        )
    }

    fileprivate static func resetKeySuffix(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCommandSuffix_resetKey
        )
    }

    fileprivate static func genURLAuthSuffix(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCommandSuffix_genURLAuth
        )
    }

    fileprivate static func urlFetchSuffix(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCommandSuffix_urlFetch
        )
    }

    fileprivate static func copySuffix(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCommandSuffix_copy
        )
    }

    fileprivate static func deleteSuffix(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCommandSuffix_delete
        )
    }

    fileprivate static func moveSuffix(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCommandSuffix_move
        )
    }

    fileprivate static func searchSuffix(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCommandSuffix_search
        )
    }

    fileprivate static func esearchSuffix(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCommandSuffix_esearch
        )
    }

    fileprivate static func storeSuffix(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCommandSuffix_store
        )
    }

    fileprivate static func examineSuffix(
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

    fileprivate static func listSuffix(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCommandSuffix_list
        )
    }

    fileprivate static func LSUBSuffix(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCommandSuffix_LSUB
        )
    }

    fileprivate static func renameSuffix(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCommandSuffix_rename
        )
    }

    fileprivate static func selectSuffix(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCommandSuffix_select
        )
    }

    fileprivate static func statusSuffix(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCommandSuffix_status
        )
    }

    fileprivate static func subscribeSuffix(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCommandSuffix_subscribe
        )
    }

    fileprivate static func unsubscribeSuffix(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCommandSuffix_unsubscribe
        )
    }

    fileprivate static func uidSuffix(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCommandSuffix_uid
        )
    }

    fileprivate static func fetchSuffix(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCommandSuffix_fetch
        )
    }

    fileprivate static func loginSuffix(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCommandSuffix_login
        )
    }

    fileprivate static func authenticateSuffix(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCommandSuffix_authenticate
        )
    }

    fileprivate static func createSuffix(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCommandSuffix_create
        )
    }

    fileprivate static func getQuotaSuffix(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCommandSuffix_getQuota
        )
    }

    fileprivate static func setQuotaSuffix(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCommandSuffix_setQuota
        )
    }

    fileprivate static func getQuotaRootSuffix(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCommandSuffix_getQuotaRoot
        )
    }
}

extension ParseFixture<String> {
    fileprivate static func userId(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseUserId
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

@Suite("AuthenticationMechanism")
struct AuthenticationMechanismTests {
    @Test("encode", arguments: [
        EncodeFixture.authenticationMechanism(.gssAPI, "GSSAPI"),
        EncodeFixture.authenticationMechanism(.plain, "PLAIN"),
        EncodeFixture.authenticationMechanism(.init("myAuth"), "MYAUTH"),
    ])
    func encode(_ fixture: EncodeFixture<AuthenticationMechanism>) {
        fixture.checkEncoding()
    }
}

extension EncodeFixture<AuthenticationMechanism> {
    fileprivate static func authenticationMechanism(
        _ input: AuthenticationMechanism,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeAuthenticationMechanism($1) }
        )
    }
}
