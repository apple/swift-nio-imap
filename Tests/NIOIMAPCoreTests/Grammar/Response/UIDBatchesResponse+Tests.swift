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

@Suite("UIDBatchesResponse")
struct UIDBatchesResponseTests {
    @Test(arguments: [
        EncodeFixture.uidBatchesResponse(
            .init(correlator: .init(tag: "A143"), batches: []),
            #"UIDBATCHES (TAG "A143")"#
        ),
        EncodeFixture.uidBatchesResponse(
            .init(correlator: .init(tag: "A143"), batches: [99695...99695]),
            #"UIDBATCHES (TAG "A143") 99695"#
        ),
        EncodeFixture.uidBatchesResponse(
            .init(correlator: .init(tag: "A143"), batches: [3_298_065...8_548_912]),
            #"UIDBATCHES (TAG "A143") 8548912:3298065"#
        ),
        EncodeFixture.uidBatchesResponse(
            .init(
                correlator: .init(tag: "A143"),
                batches: [99695...215295, 20350...99696, 7829...20351, 1...7830]
            ),
            #"UIDBATCHES (TAG "A143") 215295:99695,99696:20350,20351:7829,7830:1"#
        ),
        EncodeFixture.uidBatchesResponse(
            .init(
                correlator: .init(tag: "A143", mailbox: MailboxName("Sent"), uidValidity: 8_389_223),
                batches: [3_298_065...8_548_912]
            ),
            #"UIDBATCHES (TAG "A143" MAILBOX "Sent" UIDVALIDITY 8389223) 8548912:3298065"#
        ),
    ])
    func encode(_ fixture: EncodeFixture<UIDBatchesResponse>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.uidBatchesResponse(
            #" (TAG "A143") 215295:99695,99696:20350,20351:7829,7830:1"#,
            expected: .success(
                .init(
                    correlator: .init(tag: "A143"),
                    batches: [99695...215295, 20350...99696, 7829...20351, 1...7830]
                )
            )
        ),
        ParseFixture.uidBatchesResponse(
            #" (TAG "A143")"#,
            expected: .success(.init(correlator: .init(tag: "A143"), batches: []))
        ),
        ParseFixture.uidBatchesResponse(
            #" (TAG "A143") 99695"#,
            expected: .success(.init(correlator: .init(tag: "A143"), batches: [99695...99695]))
        ),
        ParseFixture.uidBatchesResponse(
            #" (TAG "A143") 20350:20350"#,
            expected: .success(.init(correlator: .init(tag: "A143"), batches: [20350...20350]))
        ),
        ParseFixture.uidBatchesResponse(
            #" (UIDVALIDITY 8389223 MAILBOX Sent TAG "A143") 8548912:3298065"#,
            expected: .success(
                .init(
                    correlator: .init(tag: "A143", mailbox: MailboxName("Sent"), uidValidity: 8_389_223),
                    batches: [3_298_065...8_548_912]
                )
            )
        ),
    ])
    func parse(_ fixture: ParseFixture<UIDBatchesResponse>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<UIDBatchesResponse> {
    fileprivate static func uidBatchesResponse(
        _ input: UIDBatchesResponse,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeUIDBatchesResponse($1) }
        )
    }
}

extension ParseFixture<UIDBatchesResponse> {
    fileprivate static func uidBatchesResponse(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseUIDBatchesResponse
        )
    }
}
