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
        EncodeFixture.responseTextCode(
            .capability([.unselect, .binary, .children]),
            "CAPABILITY UNSELECT BINARY CHILDREN"
        ),
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
        EncodeFixture.responseTextCode(
            .mailboxID("F2212ea87-6097-4256-9d51-71338625"),
            "MAILBOXID (F2212ea87-6097-4256-9d51-71338625)"
        ),
        EncodeFixture.responseTextCode(.metadataLongEntries(456), "METADATA LONGENTRIES 456"),
        EncodeFixture.responseTextCode(.metadataMaxsize(123), "METADATA MAXSIZE 123"),
        EncodeFixture.responseTextCode(.metadataNoPrivate, "METADATA NOPRIVATE"),
        EncodeFixture.responseTextCode(.metadataTooMany, "METADATA TOOMANY"),
        EncodeFixture.responseTextCode(
            .modified(.range(MessageIdentifierRange<UnknownMessageIdentifier>(1))),
            "MODIFIED 1"
        ),
        EncodeFixture.responseTextCode(
            .modified(MessageIdentifierSetNonEmpty<SequenceNumber>(range: 23...873)),
            "MODIFIED 23:873"
        ),
        EncodeFixture.responseTextCode(.modified(MessageIdentifierSetNonEmpty<UID>(set: [45, 77])!), "MODIFIED 45,77"),
        EncodeFixture.responseTextCode(
            .namespace(.init(userNamespace: [], otherUserNamespace: [], sharedNamespace: [])),
            "NAMESPACE NIL NIL NIL"
        ),
        EncodeFixture.responseTextCode(.noModificationSequence, "NOMODSEQ"),
        EncodeFixture.responseTextCode(.noPermission, "NOPERM"),
        EncodeFixture.responseTextCode(.nonExistent, "NONEXISTENT"),
        EncodeFixture.responseTextCode(.notSaved, "NOTSAVED"),
        EncodeFixture.responseTextCode(.other("SOMETHING", nil), "SOMETHING"),
        EncodeFixture.responseTextCode(.other("some", "thing"), "some thing"),
        EncodeFixture.responseTextCode(.other("some", nil), "some"),
        EncodeFixture.responseTextCode(.overQuota, "OVERQUOTA"),
        EncodeFixture.responseTextCode(.parse, "PARSE"),
        EncodeFixture.responseTextCode(
            .permanentFlags([.flag(.deleted), .flag(.draft)]),
            #"PERMANENTFLAGS (\Deleted \Draft)"#
        ),
        EncodeFixture.responseTextCode(.permanentFlags([.wildcard, .wildcard]), #"PERMANENTFLAGS (\* \*)"#),
        EncodeFixture.responseTextCode(.permanentFlags([.wildcard]), #"PERMANENTFLAGS (\*)"#),
        EncodeFixture.responseTextCode(.privacyRequired, "PRIVACYREQUIRED"),
        EncodeFixture.responseTextCode(.readOnly, "READ-ONLY"),
        EncodeFixture.responseTextCode(.readWrite, "READ-WRITE"),
        EncodeFixture.responseTextCode(
            .referral(.init(server: .init(host: "localhost"), query: nil)),
            "REFERRAL imap://localhost/"
        ),
        EncodeFixture.responseTextCode(.serverBug, "SERVERBUG"),
        EncodeFixture.responseTextCode(.tryCreate, "TRYCREATE"),
        EncodeFixture.responseTextCode(.uidNext(123), "UIDNEXT 123"),
        EncodeFixture.responseTextCode(.uidRequired, "UIDREQUIRED"),
        EncodeFixture.responseTextCode(.uidValidity(234), "UIDVALIDITY 234"),
        EncodeFixture.responseTextCode(.unavailable, "UNAVAILABLE"),
        EncodeFixture.responseTextCode(.unseen(345), "UNSEEN 345"),
        EncodeFixture.responseTextCode(
            .urlMechanisms([.init(mechanism: .init("m1"), base64: "b1"), .init(mechanism: .init("m2"), base64: "b2")]),
            "URLMECH INTERNAL m1=b1 m2=b2"
        ),
        EncodeFixture.responseTextCode(
            .urlMechanisms([.init(mechanism: .internal, base64: "test")]),
            "URLMECH INTERNAL INTERNAL=test"
        ),
        EncodeFixture.responseTextCode(
            .urlMechanisms([.init(mechanism: .internal, base64: nil)]),
            "URLMECH INTERNAL INTERNAL"
        ),
        EncodeFixture.responseTextCode(.urlMechanisms([]), "URLMECH INTERNAL"),
        EncodeFixture.responseTextCode(.useAttribute, "USEATTR"),
    ])
    func encode(_ fixture: EncodeFixture<ResponseTextCode>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.responseTextCode("ALERT", expected: .success(.alert)),
        ParseFixture.responseTextCode("ALREADYEXISTS", expected: .success(.alreadyExists)),
        ParseFixture.responseTextCode(
            "APPENDUID 1234 4:5",
            expected: .success(.uidAppend(.init(uidValidity: 1234, uids: [4, 5])))
        ),
        ParseFixture.responseTextCode("AUTHENTICATIONFAILED", expected: .success(.authenticationFailed)),
        ParseFixture.responseTextCode("AUTHORIZATIONFAILED", expected: .success(.authorizationFailed)),
        ParseFixture.responseTextCode(
            "BADCHARSET (UTF8 UTF9 UTF10)",
            expected: .success(.badCharset(["UTF8", "UTF9", "UTF10"]))
        ),
        ParseFixture.responseTextCode("BADCHARSET (UTF8)", expected: .success(.badCharset(["UTF8"]))),
        ParseFixture.responseTextCode("BADCHARSET", expected: .success(.badCharset([]))),
        ParseFixture.responseTextCode("CANNOT", expected: .success(.cannot)),
        ParseFixture.responseTextCode(
            "CAPABILITY IMAP4 IMAP4rev1",
            expected: .success(.capability([.imap4, .imap4rev1]))
        ),
        ParseFixture.responseTextCode("CLIENTBUG", expected: .success(.clientBug)),
        ParseFixture.responseTextCode("CLOSED", expected: .success(.closed)),
        ParseFixture.responseTextCode("COMPRESSIONACTIVE", expected: .success(.compressionActive)),
        ParseFixture.responseTextCode("CONTACTADMIN", expected: .success(.contactAdmin)),
        ParseFixture.responseTextCode(
            "COPYUID 443 3:5 6:8",
            expected: .success(
                .uidCopy(.init(destinationUIDValidity: 443, sourceUIDs: [3...5], destinationUIDs: [6...8]))
            )
        ),
        ParseFixture.responseTextCode("CORRUPTION", expected: .success(.corruption)),
        ParseFixture.responseTextCode("EXPIRED", expected: .success(.expired)),
        ParseFixture.responseTextCode("EXPUNGEISSUED", expected: .success(.expungeIssued)),
        ParseFixture.responseTextCode(
            "HIGHESTMODSEQ 1",
            expected: .success(.highestModificationSequence(.init(integerLiteral: 1)))
        ),
        ParseFixture.responseTextCode("INUSE", expected: .success(.inUse)),
        ParseFixture.responseTextCode("LIMIT", expected: .success(.limit)),
        ParseFixture.responseTextCode(
            "MAILBOXID (F2212ea87-6097-4256-9d51-71338625)",
            expected: .success(.mailboxID("F2212ea87-6097-4256-9d51-71338625"))
        ),
        ParseFixture.responseTextCode("METADATA LONGENTRIES 456", expected: .success(.metadataLongEntries(456))),
        ParseFixture.responseTextCode("METADATA MAXSIZE 123", expected: .success(.metadataMaxsize(123))),
        ParseFixture.responseTextCode("METADATA NOPRIVATE", expected: .success(.metadataNoPrivate)),
        ParseFixture.responseTextCode("METADATA TOOMANY", expected: .success(.metadataTooMany)),
        ParseFixture.responseTextCode("MODIFIED 1", expected: .success(.modified(.set([1])))),
        ParseFixture.responseTextCode(
            "NAMESPACE NIL NIL NIL",
            expected: .success(.namespace(.init(userNamespace: [], otherUserNamespace: [], sharedNamespace: [])))
        ),
        ParseFixture.responseTextCode(
            #"NAMESPACE (("Foo" NIL)) NIL (("Bar" NIL))"#,
            expected: .success(
                .namespace(
                    .init(
                        userNamespace: [.init(string: "Foo", responseExtensions: [:])],
                        otherUserNamespace: [],
                        sharedNamespace: [.init(string: "Bar", char: nil, responseExtensions: [:])]
                    )
                )
            )
        ),
        ParseFixture.responseTextCode("NOMODSEQ", expected: .success(.noModificationSequence)),
        ParseFixture.responseTextCode("NONEXISTENT", expected: .success(.nonExistent)),
        ParseFixture.responseTextCode("NOPERM", expected: .success(.noPermission)),
        ParseFixture.responseTextCode("NOTSAVED", expected: .success(.notSaved)),
        ParseFixture.responseTextCode("OVERQUOTA", expected: .success(.overQuota)),
        ParseFixture.responseTextCode("PARSE", expected: .success(.parse)),
        ParseFixture.responseTextCode("PERMANENTFLAGS ()", expected: .success(.permanentFlags([]))),
        ParseFixture.responseTextCode(
            #"PERMANENTFLAGS (\Answered \Seen \*)"#,
            expected: .success(.permanentFlags([.flag(.answered), .flag(.seen), .wildcard]))
        ),
        ParseFixture.responseTextCode(
            #"PERMANENTFLAGS (\Answered)"#,
            expected: .success(.permanentFlags([.flag(.answered)]))
        ),
        ParseFixture.responseTextCode("PRIVACYREQUIRED", expected: .success(.privacyRequired)),
        ParseFixture.responseTextCode("READ-ONLY", expected: .success(.readOnly)),
        ParseFixture.responseTextCode("READ-WRITE", expected: .success(.readWrite)),
        ParseFixture.responseTextCode(
            "REFERRAL imap://localhost/",
            expected: .success(.referral(.init(server: .init(host: "localhost"), query: nil)))
        ),
        ParseFixture.responseTextCode("SERVERBUG", expected: .success(.serverBug)),
        ParseFixture.responseTextCode("SOMETHING", expected: .success(.other("SOMETHING", nil))),
        ParseFixture.responseTextCode("TRYCREATE", expected: .success(.tryCreate)),
        ParseFixture.responseTextCode("UIDNEXT 12", expected: .success(.uidNext(12))),
        ParseFixture.responseTextCode("UIDNOTSTICKY", expected: .success(.uidNotSticky)),
        ParseFixture.responseTextCode("UIDREQUIRED", expected: .success(.uidRequired)),
        ParseFixture.responseTextCode("UIDVALIDITY 34", expected: .success(.uidValidity(34))),
        ParseFixture.responseTextCode("UNAVAILABLE", expected: .success(.unavailable)),
        ParseFixture.responseTextCode("UNSEEN 56", expected: .success(.unseen(56))),
        ParseFixture.responseTextCode(
            "URLMECH INTERNAL INTERNAL",
            expected: .success(.urlMechanisms([.init(mechanism: .internal, base64: nil)]))
        ),
        ParseFixture.responseTextCode(
            "URLMECH INTERNAL INTERNAL=YQ==",
            expected: .success(.urlMechanisms([.init(mechanism: .internal, base64: "a")]))
        ),
        ParseFixture.responseTextCode("URLMECH INTERNAL", expected: .success(.urlMechanisms([]))),
        ParseFixture.responseTextCode("USEATTR", expected: .success(.useAttribute)),
        ParseFixture.responseTextCode("some thing", expected: .success(.other("some", "thing"))),
        ParseFixture.responseTextCode("some", expected: .success(.other("some", nil))),
    ])
    func parse(_ fixture: ParseFixture<ResponseTextCode>) {
        fixture.checkParsing()
    }

    @Test(
        "debug string description",
        arguments: [
            DebugStringFixture<ResponseTextCode>(sut: .noPermission, expected: "NOPERM"),
            DebugStringFixture<ResponseTextCode>(
                sut: .badCharset(["some", "string"]),
                expected: "BADCHARSET (some string)"
            ),
            DebugStringFixture<ResponseTextCode>(sut: .permanentFlags([.wildcard]), expected: #"PERMANENTFLAGS (\*)"#),
            DebugStringFixture<ResponseTextCode>(
                sut: .permanentFlags([.wildcard, .wildcard]),
                expected: #"PERMANENTFLAGS (\* \*)"#
            ),
        ]
    )
    func debugStringDescription(_ fixture: DebugStringFixture<ResponseTextCode>) {
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

extension ParseFixture<ResponseTextCode> {
    fileprivate static func responseTextCode(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseResponseTextCode
        )
    }
}
