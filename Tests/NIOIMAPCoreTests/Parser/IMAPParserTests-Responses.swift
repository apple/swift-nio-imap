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
import NIOTestUtils
import XCTest

// MARK: - capability parseCapability

extension ParserUnitTests {
    func testParseCapability() {
        self.iterateTests(
            testFunction: GrammarParser().parseCapability,
            validInputs: [
                ("ACL", " ", .acl, #line),
                ("ANNOTATE-EXPERIMENT-1", " ", .annotateExperiment1, #line),
                ("AUTH=PLAIN", " ", .authenticate(.plain), #line),
                ("AUTH=PTOKEN", " ", .authenticate(.pToken), #line),
                ("AUTH=TOKEN", " ", .authenticate(.token), #line),
                ("AUTH=WETOKEN", " ", .authenticate(.weToken), #line),
                ("AUTH=WSTOKEN", " ", .authenticate(.wsToken), #line),
                ("BINARY", " ", .binary, #line),
                ("CATENATE", " ", .catenate, #line),
                ("CHILDREN", " ", .children, #line),
                ("COMPRESS=DEFLATE", " ", .compression(.deflate), #line),
                ("CONDSTORE", " ", .condStore, #line),
                ("CONTEXT=SEARCH", " ", .context(.search), #line),
                ("CONTEXT=SORT", " ", .context(.sort), #line),
                ("CREATE-SPECIAL-USE", " ", .createSpecialUse, #line),
                ("ENABLE", " ", .enable, #line),
                ("ESEARCH", " ", .extendedSearch, #line),
                ("ESORT", " ", .esort, #line),
                ("FILTERS", " ", .filters, #line),
                ("ID", " ", .id, #line),
                ("IDLE", " ", .idle, #line),
                ("JMAPACCESS", " ", .jmapAccess, #line),
                ("LANGUAGE", " ", .language, #line),
                ("LIST-STATUS", " ", .listStatus, #line),
                ("LITERAL+", " ", .literalPlus, #line),
                ("LITERAL-", " ", .literalMinus, #line),
                ("LOGIN-REFERRALS", " ", .loginReferrals, #line),
                ("MESSAGELIMIT=68901", " ", .messageLimit(68_901), #line),
                ("METADATA", " ", .metadata, #line),
                ("METADATA-SERVER", " ", .metadataServer, #line),
                ("MOVE", " ", .move, #line),
                ("MULTISEARCH", " ", .multiSearch, #line),
                ("NAMESPACE", " ", .namespace, #line),
                ("OBJECTID", " ", .objectID, #line),
                ("PARTIAL", " ", .partial, #line),
                ("PREVIEW", " ", .preview, #line),
                ("QRESYNC", " ", .qresync, #line),
                ("QUOTA", " ", .quota, #line),
                ("RIGHTS=TEKX", " ", .rights(.tekx), #line),
                ("SASL-IR", " ", .saslIR, #line),
                ("SAVELIMIT=64406", " ", .saveLimit(64_406), #line),
                ("SEARCHRES", " ", .searchRes, #line),
                ("SORT", " ", .sort(nil), #line),
                ("SORT=DISPLAY", " ", .sort(.display), #line),
                ("SPECIAL-USE", " ", .specialUse, #line),
                ("STATUS=SIZE", " ", .status(.size), #line),
                ("THREAD=ORDEREDSUBJECT", " ", .thread(.orderedSubject), #line),
                ("THREAD=REFERENCES", " ", .thread(.references), #line),
                ("UIDONLY", " ", .uidOnly, #line),
                ("UIDPLUS", " ", .uidPlus, #line),
                ("UNSELECT", " ", .unselect, #line),
                ("URL-PARTIAL", " ", .partialURL, #line),
                ("URLAUTH", " ", .authenticatedURL, #line),
                ("UTF8=ACCEPT", " ", .utf8(.accept), #line),
                ("WITHIN", " ", .within, #line),
                ("X-GM-EXT-1", " ", .gmailExtensions, #line),
                ("XYMHIGHESTMODSEQ", " ", .yahooMailHighestModificationSequence, #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }

    func testCapability_invalid_empty() {
        var buffer = TestUtilities.makeParseBuffer(for: "")
        XCTAssertThrowsError(try GrammarParser().parseCapability(buffer: &buffer, tracker: .testTracker)) { error in
            XCTAssertTrue(error is IncompleteMessage)
        }
    }
}

// MARK: - capability parseCapabilityData

extension ParserUnitTests {
    func testParseCapabilityData() {
        self.iterateTests(
            testFunction: GrammarParser().parseCapabilityData,
            validInputs: [
                ("CAPABILITY IMAP4rev1", "\r", [.imap4rev1], #line),
                ("CAPABILITY IMAP4 IMAP4rev1", "\r", [.imap4, .imap4rev1], #line),
                ("CAPABILITY FILTERS IMAP4", "\r", [.filters, .imap4], #line),
                ("CAPABILITY FILTERS IMAP4rev1 ENABLE", "\r", [.filters, .imap4rev1, .enable], #line),
                ("CAPABILITY FILTERS IMAP4rev1 ENABLE IMAP4", "\r", [.filters, .imap4rev1, .enable, .imap4], #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - testParseContinuationRequest

extension ParserUnitTests {
    func testParseContinuationRequest() {
        self.iterateTests(
            testFunction: GrammarParser().parseContinuationRequest,
            validInputs: [
                ("+ OK\r\n", " ", .responseText(.init(code: nil, text: "OK")), #line),
                ("+ YQ==\r\n", " ", .data("a"), #line),
                (
                    "+ IDLE accepted, awaiting DONE command.\r\n", " ",
                    .responseText(.init(code: nil, text: "IDLE accepted, awaiting DONE command.")), #line
                ),
                ("+ \r\n", " ", .responseText(.init(code: nil, text: "")), #line),
                ("+\r\n", " ", .responseText(.init(code: nil, text: "")), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - Parse Continuation Request

extension ParserUnitTests {
    func testContinuationRequest_valid() {
        let inputs: [(String, String, ContinuationRequest, UInt)] = [
            (
                "+ Ready for additional command text\r\n", "",
                .responseText(.init(text: "Ready for additional command text")), #line
            ),
            ("+ \r\n", "", .responseText(.init(text: "")), #line),
            // This is not standard conformant, but we're allowing this.
            ("+\r\n", "", .responseText(.init(text: "")), #line),
        ]
        self.iterateTests(
            testFunction: GrammarParser().parseContinuationRequest,
            validInputs: inputs,
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - enable-data parseEnableData

extension ParserUnitTests {
    func testParseEnableData() {
        self.iterateTests(
            testFunction: GrammarParser().parseEnableData,
            validInputs: [
                ("ENABLED", "\r", [], #line),
                ("ENABLED ENABLE", "\r", [.enable], #line),
                ("ENABLED UTF8=ACCEPT", "\r", [.utf8(.accept)], #line),
                ("ENABLED ENABLE CONDSTORE", "\r", [.enable, .condStore], #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseExtendedSearchResponse

extension ParserUnitTests {
    func testParseExtendedSearchResponse() {
        self.iterateTests(
            testFunction: GrammarParser().parseExtendedSearchResponse,
            validInputs: [
                ("", "\r", .init(correlator: nil, kind: .sequenceNumber, returnData: []), #line),
                (" UID", "\r", .init(correlator: nil, kind: .uid, returnData: []), #line),
                (
                    " (TAG \"col\") UID", "\r",
                    .init(correlator: SearchCorrelator(tag: "col"), kind: .uid, returnData: []), #line
                ),
                (
                    " (TAG \"col\") UID COUNT 2", "\r",
                    .init(correlator: SearchCorrelator(tag: "col"), kind: .uid, returnData: [.count(2)]), #line
                ),
                (
                    " (TAG \"col\") UID MIN 1 MAX 2", "\r",
                    .init(correlator: SearchCorrelator(tag: "col"), kind: .uid, returnData: [.min(1), .max(2)]), #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseUIDBatchesResponse

extension ParserUnitTests {
    func testParseUIDBatchesResponse() {
        self.iterateTests(
            testFunction: GrammarParser().parseUIDBatchesResponse,
            validInputs: [
                (
                    #" (TAG "A143") 215295:99695,99696:20350,20351:7829,7830:1"#, "\r",
                    .init(
                        correlator: .init(tag: "A143"),
                        batches: [
                            99695...215295, 20350...99696, 7829...20351, 1...7830,
                        ]
                    ), #line
                ),
                (#" (TAG "A143")"#, "\r", .init(correlator: .init(tag: "A143"), batches: []), #line),
                (#" (TAG "A143") 99695"#, "\r", .init(correlator: .init(tag: "A143"), batches: [99695...99695]), #line),
                (
                    #" (TAG "A143") 20350:20350"#, "\r",
                    .init(correlator: .init(tag: "A143"), batches: [20350...20350]), #line
                ),
                (
                    #" (UIDVALIDITY 8389223 MAILBOX Sent TAG "A143") 8548912:3298065"#, "\r",
                    .init(
                        correlator: .init(tag: "A143", mailbox: MailboxName("Sent"), uidValidity: 8_389_223),
                        batches: [3_298_065...8_548_912]
                    ), #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - status-att parseStatusAttribute

extension ParserUnitTests {
    func testStatusAttribute_valid_all() {
        for att in MailboxAttribute.AllCases() {
            do {
                var buffer = TestUtilities.makeParseBuffer(for: att.rawValue)
                let parsedAtt = try GrammarParser().parseStatusAttribute(buffer: &buffer, tracker: .testTracker)
                XCTAssertEqual(att, parsedAtt)
            } catch {
                XCTFail()
                return
            }
        }
    }

    func testStatusAttribute_invalid_incomplete() {
        var buffer = TestUtilities.makeParseBuffer(for: "a")
        XCTAssertThrowsError(try GrammarParser().parseStatusAttribute(buffer: &buffer, tracker: .testTracker)) { _ in
        }
    }

    func testStatusAttribute_invalid_noMatch() {
        var buffer = TestUtilities.makeParseBuffer(for: "a ")
        XCTAssertThrowsError(try GrammarParser().parseStatusAttribute(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError, "e has type \(e)")
        }
    }
}

// MARK: - status-att-list parseMailboxStatus

extension ParserUnitTests {
    func testStatusAttributeList_valid_single() {
        self.iterateTests(
            testFunction: GrammarParser().parseMailboxStatus,
            validInputs: [
                ("MESSAGES 1", ")", .init(messageCount: 1), #line),
                (
                    "MESSAGES 1 RECENT 2 UIDNEXT 3 UIDVALIDITY 4 UNSEEN 5 SIZE 6 HIGHESTMODSEQ 7", ")",
                    .init(
                        messageCount: 1,
                        recentCount: 2,
                        nextUID: 3,
                        uidValidity: 4,
                        unseenCount: 5,
                        size: 6,
                        highestModificationSequence: 7
                    ), #line
                ),
                ("APPENDLIMIT 257890", ")", .init(appendLimit: 257_890), #line),
                ("APPENDLIMIT NIL", ")", .init(appendLimit: nil), #line),
                ("SIZE 81630", ")", .init(size: 81_630), #line),
                (
                    "UIDNEXT 95604  HIGHESTMODSEQ 35227 APPENDLIMIT 81818  UIDVALIDITY 33682", ")",
                    .init(nextUID: 95604, uidValidity: 33682, highestModificationSequence: 35227, appendLimit: 81818),
                    #line
                ),
                (
                    "MAILBOXID (F2212ea87-6097-4256-9d51-71338625)", ")",
                    .init(mailboxID: "F2212ea87-6097-4256-9d51-71338625"), #line
                ),
            ],
            parserErrorInputs: [
                ("MESSAGES UNSEEN 3 RECENT 4", "\r", #line),
                ("2 UNSEEN 3 RECENT 4", "\r", #line),
            ],
            incompleteMessageInputs: [
                ("", "", #line),
                ("MESSAGES 2 UNSEEN ", "", #line),
            ]
        )
    }
}

// MARK: - parseTaggedResponse

extension ParserUnitTests {
    func testParseTaggedResponse() {
        self.iterateTests(
            testFunction: GrammarParser().parseTaggedResponse,
            validInputs: [
                (
                    "15.16 OK Fetch completed (0.001 + 0.000 secs).\r\n",
                    "",
                    .init(tag: "15.16", state: .ok(.init(text: "Fetch completed (0.001 + 0.000 secs)."))),
                    #line
                )
            ],
            parserErrorInputs: [
                ("1+5.16 OK Fetch completed (0.001 \r\n", "", #line)
            ],
            incompleteMessageInputs: [
                ("15.16 ", "", #line),
                ("15.16 OK Fetch completed (0.001 + 0.000 secs).", "", #line),
            ]
        )
    }
}

// MARK: - parseTaggedResponseState

// resp-cond-state = ("OK" / "NO" / "BAD") SP resp-text
extension ParserUnitTests {
    func testParseTaggedResponseState() {
        self.iterateTests(
            testFunction: GrammarParser().parseTaggedResponseState,
            validInputs: [
                ("OK [ALERT] hello1", "\n", .ok(.init(code: .alert, text: "hello1")), #line),
                ("NO [CLOSED] hello2", "\n", .no(.init(code: .closed, text: "hello2")), #line),
                ("BAD [PARSE] hello3", "\n", .bad(.init(code: .parse, text: "hello3")), #line),

                // strange cases
                ("OK ", "\n", .ok(.init(text: "")), #line),
                ("OK", "\n", .ok(.init(text: "")), #line),
            ],
            parserErrorInputs: [
                ("OOPS [ALERT] hello1", "\n", #line)
            ],
            incompleteMessageInputs: [
                ("OOPS", "", #line)
            ]
        )
    }
}

// MARK: - parseTaggedExtension

extension ParserUnitTests {
    func testParseTaggedExtension() {
        self.iterateTests(
            testFunction: GrammarParser().parseTaggedExtension,
            validInputs: [
                ("label 1", "\r\n", .init(key: "label", value: .sequence(.set([1]))), #line)
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - tagged-extension-comp parseTaggedExtensionComplex

extension ParserUnitTests {
    func testParseTaggedExtensionComplex() {
        self.iterateTests(
            testFunction: GrammarParser().parseTaggedExtensionComplex,
            validInputs: [
                ("test", "\r\n", ["test"], #line),
                ("(test)", "\r\n", ["test"], #line),
                ("(test1 test2)", "\r\n", ["test1", "test2"], #line),
                ("test1 test2", "\r\n", ["test1", "test2"], #line),
                ("test1 test2 (test3 test4) test5", "\r\n", ["test1", "test2", "test3", "test4", "test5"], #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseUntaggedResponseStatus

// resp-cond-state = ("OK" / "NO" / "BAD") SP resp-text
extension ParserUnitTests {
    func testParseUntaggedResponseStatus() {
        self.iterateTests(
            testFunction: GrammarParser().parseUntaggedResponseStatus,
            validInputs: [
                ("OK [ALERT] hello1", "\n", .ok(.init(code: .alert, text: "hello1")), #line),
                ("NO [CLOSED] hello2", "\n", .no(.init(code: .closed, text: "hello2")), #line),
                ("BAD [PARSE] hello3", "\n", .bad(.init(code: .parse, text: "hello3")), #line),
                ("PREAUTH [READ-ONLY] hello4", "\n", .preauth(.init(code: .readOnly, text: "hello4")), #line),
                ("BYE [READ-WRITE] hello5", "\n", .bye(.init(code: .readWrite, text: "hello5")), #line),

                // strange cases
                ("NO [ALERT] ", "\n", .no(.init(code: .alert, text: "")), #line),
                ("NO [ALERT]", "\n", .no(.init(code: .alert, text: "")), #line),
                ("NO ", "\n", .no(.init(code: nil, text: "")), #line),
                ("NO", "\n", .no(.init(code: nil, text: "")), #line),
            ],
            parserErrorInputs: [
                ("OOPS [ALERT] hello1", "\n", #line)
            ],
            incompleteMessageInputs: [
                ("OOPS", "", #line)
            ]
        )
    }
}
