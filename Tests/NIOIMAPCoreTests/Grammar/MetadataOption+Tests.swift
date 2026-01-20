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

@Suite("MetadataOption")
struct MetadataOptionTests {
    @Test(arguments: [
        EncodeFixture.metadataOption(
            .maxSize(123),
            "MAXSIZE 123"
        ),
        EncodeFixture.metadataOption(
            .scope(.one),
            "DEPTH 1"
        ),
        EncodeFixture.metadataOption(
            .other(.init(key: "param", value: nil)),
            "param"
        ),
    ])
    func `encodes single metadata option`(_ fixture: EncodeFixture<MetadataOption>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        EncodeFixture.metadataOptions(
            [.maxSize(123)],
            "(MAXSIZE 123)"
        ),
        EncodeFixture.metadataOptions(
            [.maxSize(1), .scope(.one)],
            "(MAXSIZE 1 DEPTH 1)"
        ),
    ])
    func `encodes array of metadata options`(_ fixture: EncodeFixture<[MetadataOption]>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<MetadataOption> {
    fileprivate static func metadataOption(
        _ input: MetadataOption,
        _ expectedString: String
    ) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeMetadataOption($1) }
        )
    }
}

extension EncodeFixture<[MetadataOption]> {
    fileprivate static func metadataOptions(
        _ input: [MetadataOption],
        _ expectedString: String
    ) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeMetadataOptions($1) }
        )
    }
}
