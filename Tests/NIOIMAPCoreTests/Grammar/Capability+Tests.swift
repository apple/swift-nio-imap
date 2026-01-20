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
    @Test(arguments: [
        CapabilityFixture(name: "ACL", capability: .acl, expectedName: "ACL", expectedValue: nil),
        CapabilityFixture(name: "STATUS", capability: .status(.size), expectedName: "STATUS", expectedValue: "SIZE"),
    ])
    func `name and value properties`(_ fixture: CapabilityFixture) {
        #expect(fixture.capability.name == fixture.expectedName)
        #expect(fixture.capability.value == fixture.expectedValue)
    }

    @Test(arguments: [
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
    func `encode single capability`(_ fixture: EncodeFixture<Capability>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        EncodeFixture.capabilities([.condStore], "CAPABILITY CONDSTORE"),
        EncodeFixture.capabilities([.condStore, .enable, .filters], "CAPABILITY CONDSTORE ENABLE FILTERS"),
    ])
    func `encode multiple capabilities`(_ fixture: EncodeFixture<[Capability]>) {
        fixture.checkEncoding()
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

extension EncodeFixture where T == Capability {
    fileprivate static func capability(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeCapability($1) }
        )
    }
}

extension EncodeFixture where T == [Capability] {
    fileprivate static func capabilities(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeCapabilityData($1) }
        )
    }
}
