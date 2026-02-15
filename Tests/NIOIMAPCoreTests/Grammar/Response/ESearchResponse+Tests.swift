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

@Suite("ExtendedSearchResponse")
struct ExtendedSearchResponseTests {
    @Test func `matched UIDs`() {
        #expect(
            ExtendedSearchResponse(kind: .uid, returnData: [.all(.set([44, 70...120]))]).matchedUIDs
                == [44, 70...120]
        )
        #expect(
            ExtendedSearchResponse(kind: .uid, returnData: []).matchedUIDs
                == []
        )
        #expect(
            ExtendedSearchResponse(kind: .uid, returnData: [.count(5), .all(.set([44, 70...120]))]).matchedUIDs
                == [44, 70...120]
        )
        #expect(
            ExtendedSearchResponse(kind: .uid, returnData: [.all(.set([44, 70...120])), .max(6)]).matchedUIDs
                == [44, 70...120]
        )
        #expect(
            ExtendedSearchResponse(kind: .uid, returnData: [.partial(.last(34...10_000), [99...107, 200])]).matchedUIDs
                == [99...107, 200]
        )
        #expect(
            ExtendedSearchResponse(
                kind: .uid,
                returnData: [.partial(.last(34...10_000), [99...107, 200]), .all(.set([44, 70...120]))]
            ).matchedUIDs
                == [44, 70...120]
        )
        #expect(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: [.all(.set([44, 70...120]))]).matchedUIDs
                == nil
        )
        #expect(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: [.count(5), .all(.set([44, 70...120]))])
                .matchedUIDs
                == nil
        )
        #expect(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: [.partial(.last(34...10_000), [99...107, 200])])
                .matchedUIDs
                == nil
        )
    }

    @Test func `matched sequence numbers`() {
        #expect(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: [.all(.set([44, 70...120]))])
                .matchedSequenceNumbers
                == [44, 70...120]
        )
        #expect(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: []).matchedSequenceNumbers
                == []
        )
        #expect(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: [.count(5), .all(.set([44, 70...120]))])
                .matchedSequenceNumbers
                == [44, 70...120]
        )
        #expect(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: [.all(.set([44, 70...120])), .max(6)])
                .matchedSequenceNumbers
                == [44, 70...120]
        )
        #expect(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: [.partial(.last(34...10_000), [99...107, 200])])
                .matchedSequenceNumbers
                == [99...107, 200]
        )
        #expect(
            ExtendedSearchResponse(
                kind: .sequenceNumber,
                returnData: [.partial(.last(34...10_000), [99...107, 200]), .all(.set([44, 70...120]))]
            ).matchedSequenceNumbers
                == [44, 70...120]
        )
        #expect(
            ExtendedSearchResponse(kind: .uid, returnData: [.all(.set([44, 70...120]))]).matchedSequenceNumbers
                == nil
        )
        #expect(
            ExtendedSearchResponse(kind: .uid, returnData: [.count(5), .all(.set([44, 70...120]))])
                .matchedSequenceNumbers
                == nil
        )
        #expect(
            ExtendedSearchResponse(kind: .uid, returnData: [.partial(.last(34...10_000), [99...107, 200])])
                .matchedSequenceNumbers
                == nil
        )
    }

    @Test func count() {
        #expect(
            ExtendedSearchResponse(kind: .uid, returnData: [.count(5)]).count
                == 5
        )
        #expect(
            ExtendedSearchResponse(kind: .uid, returnData: [.count(5), .all(.set([44, 70...120]))]).count
                == 5
        )
        #expect(
            ExtendedSearchResponse(kind: .uid, returnData: [.all(.set([44, 70...120])), .count(5)]).count
                == 5
        )
        #expect(
            ExtendedSearchResponse(kind: .uid, returnData: [.all(.set([44, 70...120])), .max(5)]).count
                == nil
        )
        #expect(
            ExtendedSearchResponse(kind: .uid, returnData: []).count
                == nil
        )
    }

    @Test func `min UID`() {
        #expect(
            ExtendedSearchResponse(kind: .uid, returnData: [.min(73)]).minUID
                == 73
        )
        #expect(
            ExtendedSearchResponse(kind: .uid, returnData: [.max(82), .min(73), .count(8)]).minUID
                == 73
        )
        #expect(
            ExtendedSearchResponse(kind: .uid, returnData: [.max(82), .count(8)]).minUID
                == nil
        )
        #expect(
            ExtendedSearchResponse(kind: .uid, returnData: []).minUID
                == nil
        )
        #expect(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: [.min(73)]).minUID
                == nil
        )
    }

    @Test func `min sequence number`() {
        #expect(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: [.min(73)]).minSequenceNumber
                == 73
        )
        #expect(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: [.max(82), .min(73), .count(8)])
                .minSequenceNumber
                == 73
        )
        #expect(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: [.max(82), .count(8)]).minSequenceNumber
                == nil
        )
        #expect(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: []).minSequenceNumber
                == nil
        )
        #expect(
            ExtendedSearchResponse(kind: .uid, returnData: [.min(73)]).minSequenceNumber
                == nil
        )
    }

    @Test func `max UID`() {
        #expect(
            ExtendedSearchResponse(kind: .uid, returnData: [.max(103)]).maxUID
                == 103
        )
        #expect(
            ExtendedSearchResponse(kind: .uid, returnData: [.min(82), .max(103), .count(8)]).maxUID
                == 103
        )
        #expect(
            ExtendedSearchResponse(kind: .uid, returnData: [.min(82), .count(8)]).maxUID
                == nil
        )
        #expect(
            ExtendedSearchResponse(kind: .uid, returnData: []).maxUID
                == nil
        )
        #expect(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: [.max(103)]).maxUID
                == nil
        )
    }

    @Test func `max sequence number`() {
        #expect(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: [.max(103)]).maxSequenceNumber
                == 103
        )
        #expect(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: [.min(82), .max(103), .count(8)])
                .maxSequenceNumber
                == 103
        )
        #expect(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: [.min(82), .count(8)]).maxSequenceNumber
                == nil
        )
        #expect(
            ExtendedSearchResponse(kind: .sequenceNumber, returnData: []).maxSequenceNumber
                == nil
        )
        #expect(
            ExtendedSearchResponse(kind: .uid, returnData: [.max(103)]).maxSequenceNumber
                == nil
        )
    }

    @Test(arguments: [
        EncodeFixture.extendedSearchResponse(
            .init(correlator: nil, kind: .sequenceNumber, returnData: []),
            "ESEARCH"
        ),
        EncodeFixture.extendedSearchResponse(
            .init(correlator: nil, kind: .uid, returnData: []),
            "ESEARCH UID"
        ),
        EncodeFixture.extendedSearchResponse(
            .init(correlator: nil, kind: .sequenceNumber, returnData: [.count(2)]),
            "ESEARCH COUNT 2"
        ),
        EncodeFixture.extendedSearchResponse(
            .init(correlator: SearchCorrelator(tag: "some"), kind: .sequenceNumber, returnData: []),
            #"ESEARCH (TAG "some")"#
        ),
        // RFC 4731 examples
        EncodeFixture.extendedSearchResponse(
            .init(correlator: SearchCorrelator(tag: "A282"), kind: .sequenceNumber, returnData: [.min(2), .count(3)]),
            #"ESEARCH (TAG "A282") MIN 2 COUNT 3"#
        ),
        EncodeFixture.extendedSearchResponse(
            .init(correlator: SearchCorrelator(tag: "A283"), kind: .sequenceNumber, returnData: [.all(.set([2, 10...11]))]),
            #"ESEARCH (TAG "A283") ALL 2,10:11"#
        ),
        EncodeFixture.extendedSearchResponse(
            .init(correlator: SearchCorrelator(tag: "A284"), kind: .sequenceNumber, returnData: [.min(4)]),
            #"ESEARCH (TAG "A284") MIN 4"#
        ),
        EncodeFixture.extendedSearchResponse(
            .init(correlator: SearchCorrelator(tag: "A285"), kind: .uid, returnData: [.min(7), .max(3800)]),
            #"ESEARCH (TAG "A285") UID MIN 7 MAX 3800"#
        ),
        EncodeFixture.extendedSearchResponse(
            .init(correlator: SearchCorrelator(tag: "A286"), kind: .sequenceNumber, returnData: [.count(15)]),
            #"ESEARCH (TAG "A286") COUNT 15"#
        ),
    ])
    func encode(_ fixture: EncodeFixture<ExtendedSearchResponse>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.extendedSearchResponse(
            "",
            expected: .success(.init(correlator: nil, kind: .sequenceNumber, returnData: []))
        ),
        ParseFixture.extendedSearchResponse(
            " UID",
            expected: .success(.init(correlator: nil, kind: .uid, returnData: []))
        ),
        ParseFixture.extendedSearchResponse(
            " (TAG \"col\") UID",
            expected: .success(.init(correlator: SearchCorrelator(tag: "col"), kind: .uid, returnData: []))
        ),
        ParseFixture.extendedSearchResponse(
            " (TAG \"col\") UID COUNT 2",
            expected: .success(.init(correlator: SearchCorrelator(tag: "col"), kind: .uid, returnData: [.count(2)]))
        ),
        ParseFixture.extendedSearchResponse(
            " (TAG \"col\") UID MIN 1 MAX 2",
            expected: .success(.init(correlator: SearchCorrelator(tag: "col"), kind: .uid, returnData: [.min(1), .max(2)]))
        ),
    ])
    func parse(_ fixture: ParseFixture<ExtendedSearchResponse>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<ExtendedSearchResponse> {
    fileprivate static func extendedSearchResponse(
        _ input: ExtendedSearchResponse,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeExtendedSearchResponse($1) }
        )
    }
}

extension ParseFixture<ExtendedSearchResponse> {
    fileprivate static func extendedSearchResponse(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseExtendedSearchResponse
        )
    }
}
