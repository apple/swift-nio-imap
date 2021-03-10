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

class Capability_Tests: EncodeTestClass {}

// MARK: - Name/Values

extension Capability_Tests {
    func testNameValues() {
        let inputs: [(Capability, String, String?, UInt)] = [
            (.acl, "ACL", nil, #line),
            (.status(.size), "STATUS", "SIZE", #line),
        ]
        for (capability, name, value, line) in inputs {
            XCTAssertEqual(capability.name, name, line: line)
            XCTAssertEqual(capability.value, value, line: line)
        }
    }
}

// MARK: - Encoding

extension Capability_Tests {
    func testEncode() {
        let tests: [(Capability, String, UInt)] = [
            (.acl, "ACL", #line),
            (.annotateExperiment1, "ANNOTATE-EXPERIMENT-1", #line),
            (.binary, "BINARY", #line),
            (.catenate, "CATENATE", #line),
            (.children, "CHILDREN", #line),
            (.condStore, "CONDSTORE", #line),
            (.createSpecialUse, "CREATE-SPECIAL-USE", #line),
            (.enable, "ENABLE", #line),
            (.extendedSearch, "ESEARCH", #line),
            (.esort, "ESORT", #line),
            (.filters, "FILTERS", #line),
            (.id, "ID", #line),
            (.idle, "IDLE", #line),
            (.language, "LANGUAGE", #line),
            (.listStatus, "LIST-STATUS", #line),
            (.loginReferrals, "LOGIN-REFERRALS", #line),
            (.metadata, "METADATA", #line),
            (.metadataServer, "METADATA-SERVER", #line),
            (.move, "MOVE", #line),
            (.multiSearch, "MULTISEARCH", #line),
            (.namespace, "NAMESPACE", #line),
            (.qresync, "QRESYNC", #line),
            (.quota, "QUOTA", #line),
            (.saslIR, "SASL-IR", #line),
            (.searchRes, "SEARCHRES", #line),
            (.specialUse, "SPECIAL-USE", #line),
            (.uidPlus, "UIDPLUS", #line),
            (.unselect, "UNSELECT", #line),
            (.authenticatedURL, "URLAUTH", #line),
            (.within, "WITHIN", #line),
            (.authenticate(.pToken), "AUTH=PTOKEN", #line),
            (.authenticate(.plain), "AUTH=PLAIN", #line),
            (.authenticate(.token), "AUTH=TOKEN", #line),
            (.authenticate(.weToken), "AUTH=WETOKEN", #line),
            (.authenticate(.wsToken), "AUTH=WSTOKEN", #line),
            (.context(.search), "CONTEXT=SEARCH", #line),
            (.context(.sort), "CONTEXT=SORT", #line),
            (.literalMinus, "LITERAL-", #line),
            (.literalPlus, "LITERAL+", #line),
            (.rights(.tekx), "RIGHTS=TEKX", #line),
            (.sort(nil), "SORT", #line),
            (.sort(.display), "SORT=DISPLAY", #line),
            (.status(.size), "STATUS=SIZE", #line),
            (.thread(.orderedSubject), "THREAD=ORDEREDSUBJECT", #line),
            (.thread(.references), "THREAD=REFERENCES", #line),
            (.utf8(.accept), "UTF8=ACCEPT", #line),
        ]

        for (capability, expectedString, line) in tests {
            self.testBuffer.clear()
            let size = self.testBuffer.writeCapability(capability)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }

    func testEncode_multiple() {
        let tests: [([Capability], String, UInt)] = [
            ([], "CAPABILITY IMAP4 IMAP4rev1", #line),
            ([.condStore], "CAPABILITY IMAP4 IMAP4rev1 CONDSTORE", #line),
            ([.condStore, .enable, .filters], "CAPABILITY IMAP4 IMAP4rev1 CONDSTORE ENABLE FILTERS", #line),
        ]

        for (data, expectedString, line) in tests {
            self.testBuffer.clear()
            let size = self.testBuffer.writeCapabilityData(data)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
