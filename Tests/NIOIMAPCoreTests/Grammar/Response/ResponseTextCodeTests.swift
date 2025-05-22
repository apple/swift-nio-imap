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
import XCTest

class ResponseTextCodeTests: EncodeTestClass {}

// MARK: - Encoding

extension ResponseTextCodeTests {
    func testEncode() {
        let inputs: [(ResponseTextCode, String, UInt)] = [
            (.alert, "ALERT", #line),
            (.alreadyExists, "ALREADYEXISTS", #line),
            (.authenticationFailed, "AUTHENTICATIONFAILED", #line),
            (.authorizationFailed, "AUTHORIZATIONFAILED", #line),
            (.badCharset(["some", "string"]), "BADCHARSET (some string)", #line),
            (.cannot, "CANNOT", #line),
            (.capability([.unselect, .binary, .children]), "CAPABILITY UNSELECT BINARY CHILDREN", #line),
            (.capability([.unselect]), "CAPABILITY UNSELECT", #line),
            (.clientBug, "CLIENTBUG", #line),
            (.closed, "CLOSED", #line),
            (.compressionActive, "COMPRESSIONACTIVE", #line),
            (.contactAdmin, "CONTACTADMIN", #line),
            (.corruption, "CORRUPTION", #line),
            (.expired, "EXPIRED", #line),
            (.expungeIssued, "EXPUNGEISSUED", #line),
            (.highestModificationSequence(1), "HIGHESTMODSEQ 1", #line),
            (.inUse, "INUSE", #line),
            (.limit, "LIMIT", #line),
            (.mailboxID("F2212ea87-6097-4256-9d51-71338625"), "MAILBOXID (F2212ea87-6097-4256-9d51-71338625)", #line),
            (.metadataLongEntries(456), "METADATA LONGENTRIES 456", #line),
            (.metadataMaxsize(123), "METADATA MAXSIZE 123", #line),
            (.metadataNoPrivate, "METADATA NOPRIVATE", #line),
            (.metadataTooMany, "METADATA TOOMANY", #line),
            (.modified(.range(MessageIdentifierRange<UnknownMessageIdentifier>(1))), "MODIFIED 1", #line),
            (.modified(MessageIdentifierSetNonEmpty<SequenceNumber>(range: 23...873)), "MODIFIED 23:873", #line),
            (.modified(MessageIdentifierSetNonEmpty<UID>(set: [45, 77])!), "MODIFIED 45,77", #line),
            (
                .namespace(.init(userNamespace: [], otherUserNamespace: [], sharedNamespace: [])),
                "NAMESPACE NIL NIL NIL", #line
            ),
            (.noModificationSequence, "NOMODSEQ", #line),
            (.noPermission, "NOPERM", #line),
            (.nonExistent, "NONEXISTENT", #line),
            (.notSaved, "NOTSAVED", #line),
            (.other("SOMETHING", nil), "SOMETHING", #line),
            (.other("some", "thing"), "some thing", #line),
            (.other("some", nil), "some", #line),
            (.overQuota, "OVERQUOTA", #line),
            (.parse, "PARSE", #line),
            (.permanentFlags([.flag(.deleted), .flag(.draft)]), #"PERMANENTFLAGS (\Deleted \Draft)"#, #line),
            (.permanentFlags([.wildcard, .wildcard]), #"PERMANENTFLAGS (\* \*)"#, #line),
            (.permanentFlags([.wildcard]), #"PERMANENTFLAGS (\*)"#, #line),
            (.privacyRequired, "PRIVACYREQUIRED", #line),
            (.readOnly, "READ-ONLY", #line),
            (.readWrite, "READ-WRITE", #line),
            (.referral(.init(server: .init(host: "localhost"), query: nil)), "REFERRAL imap://localhost/", #line),
            (.serverBug, "SERVERBUG", #line),
            (.tryCreate, "TRYCREATE", #line),
            (.uidNext(123), "UIDNEXT 123", #line),
            (.uidRequired, "UIDREQUIRED", #line),
            (.uidValidity(234), "UIDVALIDITY 234", #line),
            (.unavailable, "UNAVAILABLE", #line),
            (.unseen(345), "UNSEEN 345", #line),
            (
                .urlMechanisms([
                    .init(mechanism: .init("m1"), base64: "b1"), .init(mechanism: .init("m2"), base64: "b2"),
                ]), "URLMECH INTERNAL m1=b1 m2=b2", #line
            ),
            (.urlMechanisms([.init(mechanism: .internal, base64: "test")]), "URLMECH INTERNAL INTERNAL=test", #line),
            (.urlMechanisms([.init(mechanism: .internal, base64: nil)]), "URLMECH INTERNAL INTERNAL", #line),
            (.urlMechanisms([]), "URLMECH INTERNAL", #line),
            (.useAttribute, "USEATTR", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeResponseTextCode($0) })
    }

    func testDebugDescription() {
        let inputs: [(ResponseTextCode, String, UInt)] = [
            (.noPermission, "NOPERM", #line),
            (.badCharset(["some", "string"]), "BADCHARSET (some string)", #line),
            (.permanentFlags([.wildcard]), #"PERMANENTFLAGS (\*)"#, #line),
            (.permanentFlags([.wildcard, .wildcard]), #"PERMANENTFLAGS (\* \*)"#, #line),
        ]
        for input in inputs {
            XCTAssertEqual(String(reflecting: input.0), input.1, line: input.2)
        }
    }
}
