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

import XCTest
import NIO
@testable import NIOIMAPCore

class Capability_Tests: EncodeTestClass {

}

// MARK: - Equatable
extension Capability_Tests {
    
    func testEquatable() {
        let capability1 = NIOIMAP.Capability("idle")
        let capability2 = NIOIMAP.Capability("IDLE")
        XCTAssertEqual(capability1, capability2)
    }
    
}

// MARK: - Encoding
extension Capability_Tests {
    
    func testEncode() {
        let tests: [(NIOIMAP.Capability, String, UInt)] = [
            (.acl, "ACL", #line),
            (.annotateExperiment1, "ANNOTATE-EXPERIMENT-1", #line),
            (.binary, "BINARY", #line),
            (.catenate, "CATENATE", #line),
            (.children, "CHILDREN", #line),
            (.condStore, "CONDSTORE", #line),
            (.createSpecialUse, "CREATE-SPECIAL-USE", #line),
            (.enable, "ENABLE", #line),
            (.esearch, "ESEARCH", #line),
            (.esort, "ESORT", #line),
            (.filters, "FILTERS", #line),
            (.id, "ID", #line),
            (.idle, "IDLE", #line),
            (.language, "LANGUAGE", #line),
            (.listStatus, "LIST-STATUS", #line),
            (.loginReferrals, "LOGIN-REFERRALS", #line),
            (.metadata, "METADATA", #line),
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
            (.urlAuth, "URLAUTH", #line),
            (.within, "WITHIN", #line),
            (.auth(.pToken), "AUTH=PTOKEN", #line),
            (.auth(.plain), "AUTH=PLAIN", #line),
            (.auth(.token), "AUTH=TOKEN", #line),
            (.auth(.weToken), "AUTH=WETOKEN", #line),
            (.auth(.wsToken), "AUTH=WSTOKEN", #line),
            (.context(.search), "CONTEXT=SEARCH", #line),
            (.context(.sort), "CONTEXT=SORT", #line),
            (.literal(.minus), "LITERAL-", #line),
            (.literal(.plus), "LITERAL+", #line),
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
        let tests: [([NIOIMAP.Capability], String, UInt)] = [
            ([], "CAPABILITY IMAP4 IMAP4rev1", #line),
            ([.condStore], "CAPABILITY IMAP4 IMAP4rev1 CONDSTORE", #line),
            ([.condStore, .enable, .filters], "CAPABILITY IMAP4 IMAP4rev1 CONDSTORE ENABLE FILTERS", #line)
        ]

        for (data, expectedString, line) in tests {
            self.testBuffer.clear()
            let size = self.testBuffer.writeCapabilityData(data)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }

}
