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

@Suite("QuotaResponse")
struct QuotaResponseTests {
    @Test(
        "encode quota response",
        arguments: [
            EncodeFixture.quota(
                (
                    QuotaRoot("Root"),
                    []
                ),
                #"QUOTA "Root" ()"#
            ),
            EncodeFixture.quota(
                (
                    QuotaRoot("!partition/sda4"),
                    [
                        QuotaResource(resourceName: "STORAGE", usage: 104, limit: 10_923_847)
                    ]
                ),
                #"QUOTA "!partition/sda4" (STORAGE 104 10923847)"#
            ),
            EncodeFixture.quota(
                (
                    QuotaRoot("#user/alice"),
                    [
                        QuotaResource(resourceName: "MESSAGE", usage: 42, limit: 1000)
                    ]
                ),
                ##"QUOTA "#user/alice" (MESSAGE 42 1000)"##
            ),
        ]
    )
    func encodeQuotaResponse(
        fixture: EncodeFixture<(QuotaRoot, [QuotaResource])>
    ) {
        fixture.checkEncoding()
    }

    @Test(
        "encode quota resources",
        arguments: [
            EncodeFixture.quotaResources(
                [QuotaResource(resourceName: "STORAGE", usage: 10, limit: 512)],
                "(STORAGE 10 512)"
            ),
            EncodeFixture.quotaResources([], "()"),
        ]
    )
    func encodeQuotaResources(_ fixture: EncodeFixture<[QuotaResource]>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<(QuotaRoot, [QuotaResource])> {
    fileprivate static func quota(_ input: (QuotaRoot, [QuotaResource]), _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeQuotaResponse(quotaRoot: $1.0, resources: $1.1) }
        )
    }
}

extension EncodeFixture<[QuotaResource]> {
    fileprivate static func quotaResources(_ input: [QuotaResource], _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeQuotaResources($1) }
        )
    }
}
