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

@Suite("ResponseTextCode")
struct ResponseTextCodeTests {
    @Test(arguments: [
        EncodeFixture.responseTextCode(.alert, "ALERT"),
        EncodeFixture.responseTextCode(.alreadyExists, "ALREADYEXISTS"),
        EncodeFixture.responseTextCode(.authenticationFailed, "AUTHENTICATIONFAILED"),
        EncodeFixture.responseTextCode(.authorizationFailed, "AUTHORIZATIONFAILED"),
        EncodeFixture.responseTextCode(.badCharset(["some", "string"]), "BADCHARSET (some string)"),
        EncodeFixture.responseTextCode(.cannot, "CANNOT"),
        EncodeFixture.responseTextCode(.capability([.unselect, .binary, .children]), "CAPABILITY UNSELECT BINARY CHILDREN"),
        EncodeFixture.responseTextCode(.capability([.unselect]), "CAPABILITY UNSELECT"),
        EncodeFixture.responseTextCode(.clientBug, "CLIENTBUG"),
        EncodeFixture.responseTextCode(.closed, "CLOSED"),
        EncodeFixture.responseTextCode(.compressionActive, "COMPRESSIONACTIVE"),
        EncodeFixture.responseTextCode(.contactAdmin, "CONTACTADMIN"),
        EncodeFixture.responseTextCode(.corruption, "CORRUPTION"),
        EncodeFixture.responseTextCode(.expired, "EXPIRED"),
        EncodeFixture.responseTextCode(.expungeIssued, "EXPUNGEISSUED"),
        EncodeFixture.responseTextCode(.highestModificationSequence(1), "HIGHESTMODSEQ 1"),
        EncodeFixture.responseTextCode(.inUse, "INUSE"),
        EncodeFixture.responseTextCode(.limit, "LIMIT"),
        EncodeFixture.responseTextCode(.mailboxID("F2212ea87-6097-4256-9d51-71338625"), "MAILBOXID (F2212ea87-6097-4256-9d51-71338625)"),
        EncodeFixture.responseTextCode(.metadataLongEntries(456), "METADATA LONGENTRIES 456"),
        EncodeFixture.responseTextCode(.metadataMaxsize(123), "METADATA MAXSIZE 123"),
        EncodeFixture.responseTextCode(.metadataNoPrivate, "METADATA NOPRIVATE"),
        EncodeFixture.responseTextCode(.metadataTooMany, "METADATA TOOMANY"),
        EncodeFixture.responseTextCode(.modified(.range(MessageIdentifierRange<UnknownMessageIdentifier>(1))), "MODIFIED 1"),
        EncodeFixture.responseTextCode(.modified(MessageIdentifierSetNonEmpty<SequenceNumber>(range: 23...873)), "MODIFIED 23:873"),
        EncodeFixture.responseTextCode(.modified(MessageIdentifierSetNonEmpty<UID>(set: [45, 77])!), "MODIFIED 45,77"),
        EncodeFixture.responseTextCode(.namespace(.init(userNamespace: [], otherUserNamespace: [], sharedNamespace: [])), "NAMESPACE NIL NIL NIL"),
        EncodeFixture.responseTextCode(.noModificationSequence, "NOMODSEQ"),
        EncodeFixture.responseTextCode(.noPermission, "NOPERM"),
        EncodeFixture.responseTextCode(.nonExistent, "NONEXISTENT"),
        EncodeFixture.responseTextCode(.notSaved, "NOTSAVED"),
        EncodeFixture.responseTextCode(.other("SOMETHING", nil), "SOMETHING"),
        EncodeFixture.responseTextCode(.other("some", "thing"), "some thing"),
        EncodeFixture.responseTextCode(.other("some", nil), "some"),
        EncodeFixture.responseTextCode(.overQuota, "OVERQUOTA"),
        EncodeFixture.responseTextCode(.parse, "PARSE"),
        EncodeFixture.responseTextCode(.permanentFlags([.flag(.deleted), .flag(.draft)]), #"PERMANENTFLAGS (\Deleted \Draft)"#),
        EncodeFixture.responseTextCode(.permanentFlags([.wildcard, .wildcard]), #"PERMANENTFLAGS (\* \*)"#),
        EncodeFixture.responseTextCode(.permanentFlags([.wildcard]), #"PERMANENTFLAGS (\*)"#),
        EncodeFixture.responseTextCode(.privacyRequired, "PRIVACYREQUIRED"),
        EncodeFixture.responseTextCode(.readOnly, "READ-ONLY"),
        EncodeFixture.responseTextCode(.readWrite, "READ-WRITE"),
        EncodeFixture.responseTextCode(.referral(.init(server: .init(host: "localhost"), query: nil)), "REFERRAL imap://localhost/"),
        EncodeFixture.responseTextCode(.serverBug, "SERVERBUG"),
        EncodeFixture.responseTextCode(.tryCreate, "TRYCREATE"),
        EncodeFixture.responseTextCode(.uidNext(123), "UIDNEXT 123"),
        EncodeFixture.responseTextCode(.uidRequired, "UIDREQUIRED"),
        EncodeFixture.responseTextCode(.uidValidity(234), "UIDVALIDITY 234"),
        EncodeFixture.responseTextCode(.unavailable, "UNAVAILABLE"),
        EncodeFixture.responseTextCode(.unseen(345), "UNSEEN 345"),
        EncodeFixture.responseTextCode(.urlMechanisms([.init(mechanism: .init("m1"), base64: "b1"), .init(mechanism: .init("m2"), base64: "b2")]), "URLMECH INTERNAL m1=b1 m2=b2"),
        EncodeFixture.responseTextCode(.urlMechanisms([.init(mechanism: .internal, base64: "test")]), "URLMECH INTERNAL INTERNAL=test"),
        EncodeFixture.responseTextCode(.urlMechanisms([.init(mechanism: .internal, base64: nil)]), "URLMECH INTERNAL INTERNAL"),
        EncodeFixture.responseTextCode(.urlMechanisms([]), "URLMECH INTERNAL"),
        EncodeFixture.responseTextCode(.useAttribute, "USEATTR"),
    ])
    func `encode`(_ fixture: EncodeFixture<ResponseTextCode>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        DebugStringFixture<ResponseTextCode>(sut: .noPermission, expected: "NOPERM"),
        DebugStringFixture<ResponseTextCode>(sut: .badCharset(["some", "string"]), expected: "BADCHARSET (some string)"),
        DebugStringFixture<ResponseTextCode>(sut: .permanentFlags([.wildcard]), expected: #"PERMANENTFLAGS (\*)"#),
        DebugStringFixture<ResponseTextCode>(sut: .permanentFlags([.wildcard, .wildcard]), expected: #"PERMANENTFLAGS (\* \*)"#),
    ])
    func `debug string description`(_ fixture: DebugStringFixture<ResponseTextCode>) {
        fixture.check()
    }
}

// MARK: -

extension EncodeFixture<ResponseTextCode> {
    fileprivate static func responseTextCode(_ input: ResponseTextCode, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeResponseTextCode($1) }
        )
    }
}
