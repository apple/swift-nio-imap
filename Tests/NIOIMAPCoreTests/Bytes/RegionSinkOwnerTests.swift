//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import Testing

/// Boxes on every gather instead of storing the box: the misuse the sink must survive.
private struct TemporaryOwnerBuffer: StableRegionParserInputBuffer, ConsumableParserInputBuffer {
    var bytes: [UInt8]
    var byteRegions: CollectionOfOne<[UInt8]> { CollectionOfOne(bytes) }
    var count: Int { bytes.count }
    borrowing func withStableRegions(into sink: inout RegionSink) {
        let p = bytes.withUnsafeBufferPointer { $0 }
        sink.append(p, owner: IMAPByteStorage(bytes), offset: 0)
    }
    func withParseInput<R>(limit: Int, _ body: (inout ParseInput) throws -> R) rethrows -> R {
        try _stableWithParseInput(limit: limit, body)
    }
    mutating func discardFirst(_ k: Int) { bytes.removeFirst(k) }
}

@Test("A temporary owner survives zero-copy extraction")
func temporaryOwnerSurvivesExtraction() throws {
    let payload = Array(repeating: UInt8(ascii: "q"), count: 4096)
    var buffer = TemporaryOwnerBuffer(bytes: payload)
    let extracted = try buffer.parse { try $0.extractBuffer(upTo: payload.count) }
    #expect(Array(extracted.withUnsafeBytes { $0 }) == payload)
}
