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
            (.authenticate(.pToken), "AUTH=PTOKEN", #line),
            (.authenticate(.plain), "AUTH=PLAIN", #line),
            (.authenticate(.token), "AUTH=TOKEN", #line),
            (.authenticate(.weToken), "AUTH=WETOKEN", #line),
            (.authenticate(.wsToken), "AUTH=WSTOKEN", #line),
            (.authenticatedURL, "URLAUTH", #line),
            (.binary, "BINARY", #line),
            (.catenate, "CATENATE", #line),
            (.children, "CHILDREN", #line),
            (.compression(.deflate), "COMPRESS=DEFLATE", #line),
            (.condStore, "CONDSTORE", #line),
            (.context(.search), "CONTEXT=SEARCH", #line),
            (.context(.sort), "CONTEXT=SORT", #line),
            (.createSpecialUse, "CREATE-SPECIAL-USE", #line),
            (.enable, "ENABLE", #line),
            (.esort, "ESORT", #line),
            (.extendedSearch, "ESEARCH", #line),
            (.filters, "FILTERS", #line),
            (.id, "ID", #line),
            (.idle, "IDLE", #line),
            (.language, "LANGUAGE", #line),
            (.listStatus, "LIST-STATUS", #line),
            (.literalMinus, "LITERAL-", #line),
            (.literalPlus, "LITERAL+", #line),
            (.loginReferrals, "LOGIN-REFERRALS", #line),
            (.metadata, "METADATA", #line),
            (.metadataServer, "METADATA-SERVER", #line),
            (.move, "MOVE", #line),
            (.multiSearch, "MULTISEARCH", #line),
            (.namespace, "NAMESPACE", #line),
            (.partial, "PARTIAL", #line),
            (.partialURL, "URL-PARTIAL", #line),
            (.qresync, "QRESYNC", #line),
            (.quota, "QUOTA", #line),
            (.rights(.tekx), "RIGHTS=TEKX", #line),
            (.saslIR, "SASL-IR", #line),
            (.searchRes, "SEARCHRES", #line),
            (.sort(.display), "SORT=DISPLAY", #line),
            (.sort(nil), "SORT", #line),
            (.specialUse, "SPECIAL-USE", #line),
            (.status(.size), "STATUS=SIZE", #line),
            (.thread(.orderedSubject), "THREAD=ORDEREDSUBJECT", #line),
            (.thread(.references), "THREAD=REFERENCES", #line),
            (.uidOnly, "UIDONLY", #line),
            (.uidPlus, "UIDPLUS", #line),
            (.unselect, "UNSELECT", #line),
            (.utf8(.accept), "UTF8=ACCEPT", #line),
            (.within, "WITHIN", #line),
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
            ([.condStore], "CAPABILITY CONDSTORE", #line),
            ([.condStore, .enable, .filters], "CAPABILITY CONDSTORE ENABLE FILTERS", #line),
        ]

        for (data, expectedString, line) in tests {
            self.testBuffer.clear()
            let size = self.testBuffer.writeCapabilityData(data)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
