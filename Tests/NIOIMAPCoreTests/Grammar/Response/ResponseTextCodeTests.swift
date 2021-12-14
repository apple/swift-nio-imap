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
            (.parse, "PARSE", #line),
            (.readOnly, "READ-ONLY", #line),
            (.readWrite, "READ-WRITE", #line),
            (.tryCreate, "TRYCREATE", #line),
            (.uidNext(123), "UIDNEXT 123", #line),
            (.uidValidity(234), "UIDVALIDITY 234", #line),
            (.unseen(345), "UNSEEN 345", #line),
            (.badCharset(["some", "string"]), "BADCHARSET (some string)", #line),
            (.permanentFlags([.wildcard]), #"PERMANENTFLAGS (\*)"#, #line),
            (.permanentFlags([.wildcard, .wildcard]), #"PERMANENTFLAGS (\* \*)"#, #line),
            (.permanentFlags([.flag(.deleted), .flag(.draft)]), #"PERMANENTFLAGS (\Deleted \Draft)"#, #line),
            (.other("some", nil), "some", #line),
            (.other("some", "thing"), "some thing", #line),
            (.capability([.unselect]), "CAPABILITY UNSELECT", #line),
            (.capability([.unselect, .binary, .children]), "CAPABILITY UNSELECT BINARY CHILDREN", #line),
            (.namespace(.init(userNamespace: [], otherUserNamespace: [], sharedNamespace: [])), "NAMESPACE NIL NIL NIL", #line),
            (.useAttribute, "USEATTR", #line),
            (.notSaved, "NOTSAVED", #line),
            (.closed, "CLOSED", #line),
            (.noModificationSequence, "NOMODSEQ", #line),
            (.modified(.set(MessageIdentifierSet<UnknownMessageIdentifier>([1]))), "MODIFIED 1", #line),
            (.modified(.set(MessageIdentifierSet<UID>([45, 77]))), "MODIFIED 45,77", #line),
            (.modified(.set(MessageIdentifierSet<SequenceNumber>([23 ... 873]))), "MODIFIED 23:873", #line),
            (.highestModificationSequence(1), "HIGHESTMODSEQ 1", #line),
            (.metadataMaxsize(123), "METADATA MAXSIZE 123", #line),
            (.metadataLongEntries(456), "METADATA LONGENTRIES 456", #line),
            (.metadataTooMany, "METADATA TOOMANY", #line),
            (.metadataNoPrivate, "METADATA NOPRIVATE", #line),
            (.urlMechanisms([]), "URLMECH INTERNAL", #line),
            (.urlMechanisms([.init(mechanism: .internal, base64: nil)]), "URLMECH INTERNAL INTERNAL", #line),
            (.urlMechanisms([.init(mechanism: .internal, base64: "test")]), "URLMECH INTERNAL INTERNAL=test", #line),
            (
                .urlMechanisms([.init(mechanism: .init("m1"), base64: "b1"), .init(mechanism: .init("m2"), base64: "b2")]),
                "URLMECH INTERNAL m1=b1 m2=b2",
                #line
            ),
            (.referral(.init(server: .init(host: "localhost"), query: nil)), "REFERRAL imap://localhost/", #line),
            (.unavailable, "UNAVAILABLE", #line),
            (.authenticationFailed, "AUTHENTICATIONFAILED", #line),
            (.authorizationFailed, "AUTHORIZATIONFAILED", #line),
            (.expired, "EXPIRED", #line),
            (.privacyRequired, "PRIVACYREQUIRED", #line),
            (.contactAdmin, "CONTACTADMIN", #line),
            (.noPermission, "NOPERM", #line),
            (.inUse, "INUSE", #line),
            (.expungeIssued, "EXPUNGEISSUED", #line),
            (.corruption, "CORRUPTION", #line),
            (.serverBug, "SERVERBUG", #line),
            (.clientBug, "CLIENTBUG", #line),
            (.cannot, "CANNOT", #line),
            (.limit, "LIMIT", #line),
            (.overQuota, "OVERQUOTA", #line),
            (.alreadyExists, "ALREADYEXISTS", #line),
            (.nonExistent, "NONEXISTENT", #line),
            (.compressionActive, "COMPRESSIONACTIVE", #line),
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
