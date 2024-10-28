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

class ExtendedSearchResponse_Tests: EncodeTestClass {}

// MARK: - Convenience

extension ExtendedSearchResponse_Tests {
    func testMatchedUIDs() {
        XCTAssertEqual(
            ExtendedSearchResponse(kind: .uid, returnData: [.all(.set([44, 70...120]))]).matchedUIDs,
            [44, 70...120]
        )
        XCTAssertEqual(
            ExtendedSearchResponse(kind: .uid, returnData: []).matchedUIDs,
            []
        )
        XCTAssertEqual(
            ExtendedSearchResponse(kind: .uid, returnData: [.count(5), .all(.set([44, 70...120]))]).matchedUIDs,
            [44, 70...120]
        )
        XCTAssertEqual(
            ExtendedSearchResponse(kind: .uid, returnData: [.all(.set([44, 70...120])), .max(6)]).matchedUIDs,
            [44, 70...120]
        )
        XCTAssertEqual(
            ExtendedSearchResponse(kind: .uid, returnData: [.partial(.last(34...10_000), [99...107, 200])]).matchedUIDs,
            [99...107, 200]
        )
        XCTAssertEqual(
            ExtendedSearchResponse(
                kind: .uid,
                returnData: [.partial(.last(34...10_000), [99...107, 200]), .all(.set([44, 70...120]))]
            ).matchedUIDs,
            [44, 70...120]
        )
        XCTAssertNil(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: [.all(.set([44, 70...120]))]).matchedUIDs
        )
        XCTAssertNil(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: [.count(5), .all(.set([44, 70...120]))])
                .matchedUIDs
        )
        XCTAssertNil(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: [.partial(.last(34...10_000), [99...107, 200])])
                .matchedUIDs
        )
    }

    func testMatchedSequenceNumbers() {
        XCTAssertEqual(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: [.all(.set([44, 70...120]))])
                .matchedSequenceNumbers,
            [44, 70...120]
        )
        XCTAssertEqual(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: []).matchedSequenceNumbers,
            []
        )
        XCTAssertEqual(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: [.count(5), .all(.set([44, 70...120]))])
                .matchedSequenceNumbers,
            [44, 70...120]
        )
        XCTAssertEqual(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: [.all(.set([44, 70...120])), .max(6)])
                .matchedSequenceNumbers,
            [44, 70...120]
        )
        XCTAssertEqual(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: [.partial(.last(34...10_000), [99...107, 200])])
                .matchedSequenceNumbers,
            [99...107, 200]
        )
        XCTAssertEqual(
            ExtendedSearchResponse(
                kind: .sequenceNumber,
                returnData: [.partial(.last(34...10_000), [99...107, 200]), .all(.set([44, 70...120]))]
            ).matchedSequenceNumbers,
            [44, 70...120]
        )
        XCTAssertNil(
            ExtendedSearchResponse(kind: .uid, returnData: [.all(.set([44, 70...120]))]).matchedSequenceNumbers
        )
        XCTAssertNil(
            ExtendedSearchResponse(kind: .uid, returnData: [.count(5), .all(.set([44, 70...120]))])
                .matchedSequenceNumbers
        )
        XCTAssertNil(
            ExtendedSearchResponse(kind: .uid, returnData: [.partial(.last(34...10_000), [99...107, 200])])
                .matchedSequenceNumbers
        )
    }

    func testCount() {
        XCTAssertEqual(
            ExtendedSearchResponse(kind: .uid, returnData: [.count(5)]).count,
            5
        )
        XCTAssertEqual(
            ExtendedSearchResponse(kind: .uid, returnData: [.count(5), .all(.set([44, 70...120]))]).count,
            5
        )
        XCTAssertEqual(
            ExtendedSearchResponse(kind: .uid, returnData: [.all(.set([44, 70...120])), .count(5)]).count,
            5
        )
        XCTAssertNil(
            ExtendedSearchResponse(kind: .uid, returnData: [.all(.set([44, 70...120])), .max(5)]).count
        )
        XCTAssertNil(
            ExtendedSearchResponse(kind: .uid, returnData: []).count
        )
    }

    func testMinUID() {
        XCTAssertEqual(
            ExtendedSearchResponse(kind: .uid, returnData: [.min(73)]).minUID,
            73
        )
        XCTAssertEqual(
            ExtendedSearchResponse(kind: .uid, returnData: [.max(82), .min(73), .count(8)]).minUID,
            73
        )
        XCTAssertNil(
            ExtendedSearchResponse(kind: .uid, returnData: [.max(82), .count(8)]).minUID
        )
        XCTAssertNil(
            ExtendedSearchResponse(kind: .uid, returnData: []).minUID
        )
        XCTAssertNil(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: [.min(73)]).minUID
        )
    }

    func testMinSequenceNumber() {
        XCTAssertEqual(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: [.min(73)]).minSequenceNumber,
            73
        )
        XCTAssertEqual(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: [.max(82), .min(73), .count(8)])
                .minSequenceNumber,
            73
        )
        XCTAssertNil(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: [.max(82), .count(8)]).minSequenceNumber
        )
        XCTAssertNil(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: []).minSequenceNumber
        )
        XCTAssertNil(
            ExtendedSearchResponse(kind: .uid, returnData: [.min(73)]).minSequenceNumber
        )
    }

    func testMaxUID() {
        XCTAssertEqual(
            ExtendedSearchResponse(kind: .uid, returnData: [.max(103)]).maxUID,
            103
        )
        XCTAssertEqual(
            ExtendedSearchResponse(kind: .uid, returnData: [.min(82), .max(103), .count(8)]).maxUID,
            103
        )
        XCTAssertNil(
            ExtendedSearchResponse(kind: .uid, returnData: [.min(82), .count(8)]).maxUID
        )
        XCTAssertNil(
            ExtendedSearchResponse(kind: .uid, returnData: []).maxUID
        )
        XCTAssertNil(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: [.max(103)]).maxUID
        )
    }

    func testMaxSequenceNumber() {
        XCTAssertEqual(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: [.max(103)]).maxSequenceNumber,
            103
        )
        XCTAssertEqual(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: [.min(82), .max(103), .count(8)])
                .maxSequenceNumber,
            103
        )
        XCTAssertNil(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: [.min(82), .count(8)]).maxSequenceNumber
        )
        XCTAssertNil(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: []).maxSequenceNumber
        )
        XCTAssertNil(
            ExtendedSearchResponse(kind: .uid, returnData: [.max(103)]).maxSequenceNumber
        )
    }
}

// MARK: - Encoding

extension ExtendedSearchResponse_Tests {
    func testEncode() {
        let inputs: [(ExtendedSearchResponse, String, UInt)] = [
            (.init(correlator: nil, kind: .sequenceNumber, returnData: []), "ESEARCH", #line),
            (.init(correlator: nil, kind: .uid, returnData: []), "ESEARCH UID", #line),
            (.init(correlator: nil, kind: .sequenceNumber, returnData: [.count(2)]), "ESEARCH COUNT 2", #line),
            (
                .init(correlator: SearchCorrelator(tag: "some"), kind: .sequenceNumber, returnData: []),
                #"ESEARCH (TAG "some")"#, #line
            ),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeExtendedSearchResponse(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
