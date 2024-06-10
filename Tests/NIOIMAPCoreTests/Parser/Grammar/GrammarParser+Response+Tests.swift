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
@testable import NIOIMAPCore
import XCTest

class GrammarParser_Response_Tests: XCTestCase, _ParserTestHelpers {}

// MARK: - parseResponseData

extension GrammarParser_Response_Tests {
    func testParseResponseData() {
        self.iterateTests(
            testFunction: GrammarParser().parseResponseData,
            validInputs: [
                ("* CAPABILITY ENABLE\r\n", " ", .capabilityData([.enable]), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseResponsePayload

extension GrammarParser_Response_Tests {
    func testParseResponsePayload() {
        self.iterateTests(
            testFunction: GrammarParser().parseResponsePayload,
            validInputs: [
                ("CAPABILITY ENABLE", "\r", .capabilityData([.enable]), #line),
                ("BYE test", "\r", .conditionalState(.bye(.init(code: nil, text: "test"))), #line),
                ("OK test", "\r", .conditionalState(.ok(.init(code: nil, text: "test"))), #line),
                ("1 EXISTS", "\r", .mailboxData(.exists(1)), #line),
                ("2 EXPUNGE", "\r", .messageData(.expunge(2)), #line),
                ("ENABLED ENABLE", "\r", .enableData([.enable]), #line),
                ("ID (\"key\" NIL)", "\r", .id(["key": nil]), #line),
                ("METADATA INBOX a", "\r", .metadata(.list(list: ["a"], mailbox: .inbox)), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseResponseTextCode

extension GrammarParser_Response_Tests {
    func testParseResponseTextCode() {
        self.iterateTests(
            testFunction: GrammarParser().parseResponseTextCode,
            validInputs: [
                ("ALERT", "\r", .alert, #line),
                ("ALREADYEXISTS", "\r", .alreadyExists, #line),
                ("ALREADYEXISTS", "\r", .alreadyExists, #line),
                ("APPENDUID 1234 4:5", "\r", .uidAppend(.init(uidValidity: 1234, uids: [4, 5])), #line),
                ("AUTHENTICATIONFAILED", "\r", .authenticationFailed, #line),
                ("AUTHORIZATIONFAILED", "\r", .authorizationFailed, #line),
                ("BADCHARSET (UTF8 UTF9 UTF10)", "\r", .badCharset(["UTF8", "UTF9", "UTF10"]), #line),
                ("BADCHARSET (UTF8)", "\r", .badCharset(["UTF8"]), #line),
                ("BADCHARSET", "\r", .badCharset([]), #line),
                ("CANNOT", "\r", .cannot, #line),
                ("CAPABILITY IMAP4 IMAP4rev1", "\r", .capability([.imap4, .imap4rev1]), #line),
                ("CLIENTBUG", "\r", .clientBug, #line),
                ("CLOSED", "\r", .closed, #line),
                ("COMPRESSIONACTIVE", "\r", .compressionActive, #line),
                ("CONTACTADMIN", "\r", .contactAdmin, #line),
                ("COPYUID 443 3:5 6:8", "\r", .uidCopy(.init(destinationUIDValidity: 443, sourceUIDs: [3 ... 5], destinationUIDs: [6 ... 8])), #line),
                ("CORRUPTION", "\r", .corruption, #line),
                ("EXPIRED", "\r", .expired, #line),
                ("EXPUNGEISSUED", "\r", .expungeIssued, #line),
                ("HIGHESTMODSEQ 1", "\r", .highestModificationSequence(.init(integerLiteral: 1)), #line),
                ("INUSE", "\r", .inUse, #line),
                ("LIMIT", "\r", .limit, #line),
                ("METADATA LONGENTRIES 456", "\r", .metadataLongEntries(456), #line),
                ("METADATA MAXSIZE 123", "\r", .metadataMaxsize(123), #line),
                ("METADATA NOPRIVATE", "\r", .metadataNoPrivate, #line),
                ("METADATA TOOMANY", "\r", .metadataTooMany, #line),
                ("MODIFIED 1", "\r", .modified(.set([1])), #line),
                ("NAMESPACE NIL NIL NIL", "\r", .namespace(.init(userNamespace: [], otherUserNamespace: [], sharedNamespace: [])), #line),
                (#"NAMESPACE (("Foo" NIL)) NIL (("Bar" NIL))"#, "\r", .namespace(.init(userNamespace: [.init(string: "Foo", responseExtensions: [:])], otherUserNamespace: [], sharedNamespace: [.init(string: "Bar", char: nil, responseExtensions: [:])])), #line),
                ("NOMODSEQ", "\r", .noModificationSequence, #line),
                ("NONEXISTENT", "\r", .nonExistent, #line),
                ("NOPERM", "\r", .noPermission, #line),
                ("NOTSAVED", "\r", .notSaved, #line),
                ("OVERQUOTA", "\r", .overQuota, #line),
                ("PARSE", "\r", .parse, #line),
                ("PERMANENTFLAGS ()", "\r", .permanentFlags([]), #line),
                ("PERMANENTFLAGS (\\Answered \\Seen \\*)", "\r", .permanentFlags([.flag(.answered), .flag(.seen), .wildcard]), #line),
                ("PERMANENTFLAGS (\\Answered)", "\r", .permanentFlags([.flag(.answered)]), #line),
                ("PRIVACYREQUIRED", "\r", .privacyRequired, #line),
                ("READ-ONLY", "\r", .readOnly, #line),
                ("READ-WRITE", "\r", .readWrite, #line),
                ("REFERRAL imap://localhost/", "\r", .referral(.init(server: .init(host: "localhost"), query: nil)), #line),
                ("SERVERBUG", "\r", .serverBug, #line),
                ("SOMETHING", "\r", .other("SOMETHING", nil), #line),
                ("TRYCREATE", "\r", .tryCreate, #line),
                ("UIDNEXT 12", "\r", .uidNext(12), #line),
                ("UIDNOTSTICKY", "\r", .uidNotSticky, #line),
                ("UIDREQUIRED", "\r", .uidRequired, #line),
                ("UIDVALIDITY 34", "\r", .uidValidity(34), #line),
                ("UNAVAILABLE", "\r", .unavailable, #line),
                ("UNSEEN 56", "\r", .unseen(56), #line),
                ("URLMECH INTERNAL INTERNAL", "\r", .urlMechanisms([.init(mechanism: .internal, base64: nil)]), #line),
                ("URLMECH INTERNAL INTERNAL=YQ==", "\r", .urlMechanisms([.init(mechanism: .internal, base64: "a")]), #line),
                ("URLMECH INTERNAL", "\r", .urlMechanisms([]), #line),
                ("USEATTR", "\r", .useAttribute, #line),
                ("some thing", "\r", .other("some", "thing"), #line),
                ("some", "\r", .other("some", nil), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseResponseText

extension GrammarParser_Response_Tests {
    func testParseResponseText() {
        self.iterateTests(
            testFunction: GrammarParser().parseResponseText,
            validInputs: [
                ("", "\r", .init(code: nil, text: ""), #line),
                (" ", "\r", .init(code: nil, text: ""), #line),
                ("text", "\r", .init(code: nil, text: "text"), #line),
                (" text", "\r", .init(code: nil, text: "text"), #line),
                ("[UNSEEN 1]", "\r", .init(code: .unseen(1), text: ""), #line),
                ("[UNSEEN 2] ", "\r", .init(code: .unseen(2), text: ""), #line),
                ("[UNSEEN 2] some text", "\r", .init(code: .unseen(2), text: "some text"), #line),
                ("[UIDVALIDITY 1561789793]", "\r", .init(code: .uidValidity(1561789793), text: ""), #line),
                ("[UIDNEXT 171]", "\r", .init(code: .uidNext(171), text: ""), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}
