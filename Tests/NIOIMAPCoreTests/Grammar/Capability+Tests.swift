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
import Testing
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore

@Suite("Capability")
struct CapabilityTests {
    @Test("name and value properties", arguments: [
        CapabilityFixture(name: "ACL", capability: .acl, expectedName: "ACL", expectedValue: nil),
        CapabilityFixture(name: "STATUS", capability: .status(.size), expectedName: "STATUS", expectedValue: "SIZE"),
    ])
    func nameAndValueProperties(_ fixture: CapabilityFixture) {
        #expect(fixture.capability.name == fixture.expectedName)
        #expect(fixture.capability.value == fixture.expectedValue)
    }

    @Test("encode single capability", arguments: [
        EncodeFixture.capability(.acl, "ACL"),
        EncodeFixture.capability(.annotateExperiment1, "ANNOTATE-EXPERIMENT-1"),
        EncodeFixture.capability(.appendLimit(11_206_521), "APPENDLIMIT=11206521"),
        EncodeFixture.capability(.authenticate(.pToken), "AUTH=PTOKEN"),
        EncodeFixture.capability(.authenticate(.plain), "AUTH=PLAIN"),
        EncodeFixture.capability(.authenticate(.token), "AUTH=TOKEN"),
        EncodeFixture.capability(.authenticate(.weToken), "AUTH=WETOKEN"),
        EncodeFixture.capability(.authenticate(.wsToken), "AUTH=WSTOKEN"),
        EncodeFixture.capability(.authenticatedURL, "URLAUTH"),
        EncodeFixture.capability(.binary, "BINARY"),
        EncodeFixture.capability(.catenate, "CATENATE"),
        EncodeFixture.capability(.children, "CHILDREN"),
        EncodeFixture.capability(.compression(.deflate), "COMPRESS=DEFLATE"),
        EncodeFixture.capability(.condStore, "CONDSTORE"),
        EncodeFixture.capability(.context(.search), "CONTEXT=SEARCH"),
        EncodeFixture.capability(.context(.sort), "CONTEXT=SORT"),
        EncodeFixture.capability(.createSpecialUse, "CREATE-SPECIAL-USE"),
        EncodeFixture.capability(.enable, "ENABLE"),
        EncodeFixture.capability(.esort, "ESORT"),
        EncodeFixture.capability(.extendedSearch, "ESEARCH"),
        EncodeFixture.capability(.filters, "FILTERS"),
        EncodeFixture.capability(.gmailExtensions, "X-GM-EXT-1"),
        EncodeFixture.capability(.id, "ID"),
        EncodeFixture.capability(.idle, "IDLE"),
        EncodeFixture.capability(.jmapAccess, "JMAPACCESS"),
        EncodeFixture.capability(.language, "LANGUAGE"),
        EncodeFixture.capability(.listStatus, "LIST-STATUS"),
        EncodeFixture.capability(.literalMinus, "LITERAL-"),
        EncodeFixture.capability(.literalPlus, "LITERAL+"),
        EncodeFixture.capability(.loginReferrals, "LOGIN-REFERRALS"),
        EncodeFixture.capability(.mailboxSpecificAppendLimit, "APPENDLIMIT"),
        EncodeFixture.capability(.messageLimit(1_234), "MESSAGELIMIT=1234"),
        EncodeFixture.capability(.metadata, "METADATA"),
        EncodeFixture.capability(.metadataServer, "METADATA-SERVER"),
        EncodeFixture.capability(.move, "MOVE"),
        EncodeFixture.capability(.multiSearch, "MULTISEARCH"),
        EncodeFixture.capability(.namespace, "NAMESPACE"),
        EncodeFixture.capability(.objectID, "OBJECTID"),
        EncodeFixture.capability(.partial, "PARTIAL"),
        EncodeFixture.capability(.partialURL, "URL-PARTIAL"),
        EncodeFixture.capability(.preview, "PREVIEW"),
        EncodeFixture.capability(.qresync, "QRESYNC"),
        EncodeFixture.capability(.quota, "QUOTA"),
        EncodeFixture.capability(.rights(.tekx), "RIGHTS=TEKX"),
        EncodeFixture.capability(.saslIR, "SASL-IR"),
        EncodeFixture.capability(.saveLimit(64_152), "SAVELIMIT=64152"),
        EncodeFixture.capability(.searchRes, "SEARCHRES"),
        EncodeFixture.capability(.sort(.display), "SORT=DISPLAY"),
        EncodeFixture.capability(.sort(nil), "SORT"),
        EncodeFixture.capability(.specialUse, "SPECIAL-USE"),
        EncodeFixture.capability(.status(.size), "STATUS=SIZE"),
        EncodeFixture.capability(.thread(.orderedSubject), "THREAD=ORDEREDSUBJECT"),
        EncodeFixture.capability(.thread(.references), "THREAD=REFERENCES"),
        EncodeFixture.capability(.uidOnly, "UIDONLY"),
        EncodeFixture.capability(.uidPlus, "UIDPLUS"),
        EncodeFixture.capability(.unselect, "UNSELECT"),
        EncodeFixture.capability(.utf8(.accept), "UTF8=ACCEPT"),
        EncodeFixture.capability(.within, "WITHIN"),
        EncodeFixture.capability(.yahooMailHighestModificationSequence, "XYMHIGHESTMODSEQ"),
    ])
    func encodeSingleCapability(_ fixture: EncodeFixture<Capability>) {
        fixture.checkEncoding()
    }

    @Test("encode multiple capabilities", arguments: [
        EncodeFixture.capabilities([.condStore], "CAPABILITY CONDSTORE"),
        EncodeFixture.capabilities([.condStore, .enable, .filters], "CAPABILITY CONDSTORE ENABLE FILTERS"),
    ])
    func encodeMultipleCapabilities(_ fixture: EncodeFixture<[Capability]>) {
        fixture.checkEncoding()
    }

    @Test("parse capability data", arguments: [
        ParseFixture.capability("ACL", expected: .success(.acl)),
        ParseFixture.capability("ANNOTATE-EXPERIMENT-1", expected: .success(.annotateExperiment1)),
        ParseFixture.capability("AUTH=PLAIN", expected: .success(.authenticate(.plain))),
        ParseFixture.capability("AUTH=PTOKEN", expected: .success(.authenticate(.pToken))),
        ParseFixture.capability("AUTH=TOKEN", expected: .success(.authenticate(.token))),
        ParseFixture.capability("AUTH=WETOKEN", expected: .success(.authenticate(.weToken))),
        ParseFixture.capability("AUTH=WSTOKEN", expected: .success(.authenticate(.wsToken))),
        ParseFixture.capability("BINARY", expected: .success(.binary)),
        ParseFixture.capability("CATENATE", expected: .success(.catenate)),
        ParseFixture.capability("CHILDREN", expected: .success(.children)),
        ParseFixture.capability("COMPRESS=DEFLATE", expected: .success(.compression(.deflate))),
        ParseFixture.capability("CONDSTORE", expected: .success(.condStore)),
        ParseFixture.capability("CONTEXT=SEARCH", expected: .success(.context(.search))),
        ParseFixture.capability("CONTEXT=SORT", expected: .success(.context(.sort))),
        ParseFixture.capability("CREATE-SPECIAL-USE", expected: .success(.createSpecialUse)),
        ParseFixture.capability("ENABLE", expected: .success(.enable)),
        ParseFixture.capability("ESEARCH", expected: .success(.extendedSearch)),
        ParseFixture.capability("ESORT", expected: .success(.esort)),
        ParseFixture.capability("FILTERS", expected: .success(.filters)),
        ParseFixture.capability("ID", expected: .success(.id)),
        ParseFixture.capability("IDLE", expected: .success(.idle)),
        ParseFixture.capability("JMAPACCESS", expected: .success(.jmapAccess)),
        ParseFixture.capability("LANGUAGE", expected: .success(.language)),
        ParseFixture.capability("LIST-STATUS", expected: .success(.listStatus)),
        ParseFixture.capability("LITERAL+", expected: .success(.literalPlus)),
        ParseFixture.capability("LITERAL-", expected: .success(.literalMinus)),
        ParseFixture.capability("LOGIN-REFERRALS", expected: .success(.loginReferrals)),
        ParseFixture.capability("MESSAGELIMIT=68901", expected: .success(.messageLimit(68_901))),
        ParseFixture.capability("METADATA", expected: .success(.metadata)),
        ParseFixture.capability("METADATA-SERVER", expected: .success(.metadataServer)),
        ParseFixture.capability("MOVE", expected: .success(.move)),
        ParseFixture.capability("MULTISEARCH", expected: .success(.multiSearch)),
        ParseFixture.capability("NAMESPACE", expected: .success(.namespace)),
        ParseFixture.capability("OBJECTID", expected: .success(.objectID)),
        ParseFixture.capability("PARTIAL", expected: .success(.partial)),
        ParseFixture.capability("PREVIEW", expected: .success(.preview)),
        ParseFixture.capability("QRESYNC", expected: .success(.qresync)),
        ParseFixture.capability("QUOTA", expected: .success(.quota)),
        ParseFixture.capability("RIGHTS=TEKX", expected: .success(.rights(.tekx))),
        ParseFixture.capability("SASL-IR", expected: .success(.saslIR)),
        ParseFixture.capability("SAVELIMIT=64406", expected: .success(.saveLimit(64_406))),
        ParseFixture.capability("SEARCHRES", expected: .success(.searchRes)),
        ParseFixture.capability("SORT", expected: .success(.sort(nil))),
        ParseFixture.capability("SORT=DISPLAY", expected: .success(.sort(.display))),
        ParseFixture.capability("SPECIAL-USE", expected: .success(.specialUse)),
        ParseFixture.capability("STATUS=SIZE", expected: .success(.status(.size))),
        ParseFixture.capability("THREAD=ORDEREDSUBJECT", expected: .success(.thread(.orderedSubject))),
        ParseFixture.capability("THREAD=REFERENCES", expected: .success(.thread(.references))),
        ParseFixture.capability("UIDONLY", expected: .success(.uidOnly)),
        ParseFixture.capability("UIDPLUS", expected: .success(.uidPlus)),
        ParseFixture.capability("UNSELECT", expected: .success(.unselect)),
        ParseFixture.capability("URL-PARTIAL", expected: .success(.partialURL)),
        ParseFixture.capability("URLAUTH", expected: .success(.authenticatedURL)),
        ParseFixture.capability("UTF8=ACCEPT", expected: .success(.utf8(.accept))),
        ParseFixture.capability("WITHIN", expected: .success(.within)),
        ParseFixture.capability("X-GM-EXT-1", expected: .success(.gmailExtensions)),
        ParseFixture.capability("XYMHIGHESTMODSEQ", expected: .success(.yahooMailHighestModificationSequence)),
        ParseFixture.capability("", "", expected: .incompleteMessage),
    ])
    func parse(_ fixture: ParseFixture<Capability>) {
        fixture.checkParsing()
    }

    @Test(arguments: [
        ParseFixture.capabilityData("CAPABILITY IMAP4rev1", expected: .success([.imap4rev1])),
        ParseFixture.capabilityData("CAPABILITY IMAP4 IMAP4rev1", expected: .success([.imap4, .imap4rev1])),
        ParseFixture.capabilityData("CAPABILITY FILTERS IMAP4", expected: .success([.filters, .imap4])),
        ParseFixture.capabilityData(
            "CAPABILITY FILTERS IMAP4rev1 ENABLE",
            expected: .success([.filters, .imap4rev1, .enable])
        ),
        ParseFixture.capabilityData(
            "CAPABILITY FILTERS IMAP4rev1 ENABLE IMAP4",
            expected: .success([.filters, .imap4rev1, .enable, .imap4])
        ),
    ])
    func parseCapabilityData(_ fixture: ParseFixture<[Capability]>) {
        fixture.checkParsing()
    }
}

// MARK: -

struct CapabilityFixture: Sendable, CustomTestStringConvertible {
    var name: String
    var capability: Capability
    var expectedName: String
    var expectedValue: String?

    var testDescription: String { name }
}

extension EncodeFixture<Capability> {
    fileprivate static func capability(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeCapability($1) }
        )
    }
}

extension EncodeFixture<[Capability]> {
    fileprivate static func capabilities(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeCapabilityData($1) }
        )
    }
}

extension ParseFixture<Capability> {
    fileprivate static func capability(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCapability
        )
    }
}

extension ParseFixture<[Capability]> {
    fileprivate static func capabilityData(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCapabilityData
        )
    }
}
