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

import NIOIMAPCore
import Testing

/// An input buffer written outside the library, with public API only and without the `Lifetimes`
/// feature: it keeps each read as a box and vouches for it, so a large literal reaches the caller
/// uncopied.
private struct ReadList: StableRegionParserInputBuffer, ConsumableParserInputBuffer {
    private var reads: [IMAPByteStorage] = []
    /// How much of the first read has been consumed.
    private var headOffset = 0

    mutating func append(_ bytes: [UInt8]) {
        reads.append(IMAPByteStorage(bytes))
    }

    var byteRegions: [IMAPBuffer] {
        reads.indices.map { index in
            let storage = reads[index]
            let start = index == reads.startIndex ? headOffset : 0
            return IMAPBuffer(storage, range: start..<storage.count)
        }
    }

    var count: Int {
        reads.reduce(0) { $0 + $1.count } - headOffset
    }

    var regionCount: Int { reads.count }

    borrowing func withStableRegions(into sink: inout RegionSink) {
        for index in reads.indices {
            let storage = reads[index]
            let offset = index == reads.startIndex ? headOffset : 0
            // `self` keeps the box, and the box keeps the array's bytes in place.
            let bytes = storage.withUnsafeBytes { $0 }
            let visible = UnsafeRawBufferPointer(rebasing: bytes[offset...])
            sink.append(visible.assumingMemoryBound(to: UInt8.self), owner: storage, offset: offset)
        }
    }

    func withParseInput<R>(limit: Int, _ body: (inout ParseInput) throws -> R) rethrows -> R {
        try _stableWithParseInput(limit: limit, body)
    }

    mutating func discardFirst(_ k: Int) {
        var remaining = k
        while remaining > 0 {
            let available = reads[0].count - headOffset
            guard remaining >= available else {
                headOffset += remaining
                return
            }
            remaining -= available
            reads.removeFirst()
            headOffset = 0
        }
    }
}

@Suite("Third-party input buffer")
struct ThirdPartyInputBufferTests {
    private static let payloadSize = 64 * 1_024

    @Test("a conformer outside the library parses, and delivers a large literal uncopied")
    func largeLiteralIsNotCopied() throws {
        let body = [UInt8](repeating: UInt8(ascii: "x"), count: Self.payloadSize)
        var input = ReadList()
        input.append(Array("* 1 FETCH (RFC822.TEXT {\(Self.payloadSize)}\r\n".utf8))
        input.append(body)
        input.append(Array(")\r\n".utf8))
        let bodyStart = body.withUnsafeBytes { UInt(bitPattern: $0.baseAddress) }
        let bodyAddresses = bodyStart..<(bodyStart + UInt(body.count))

        var parser = ResponseParser()
        var payloads: [IMAPBuffer] = []
        while let response = try parser.parseResponseStream(buffer: &input) {
            guard case .response(.fetch(.streamingBytes(let bytes))) = response else { continue }
            payloads.append(bytes)
        }

        #expect(input.count == 0)
        #expect(payloads.reduce(0) { $0 + $1.count } == Self.payloadSize)
        #expect(
            payloads.allSatisfy { payload in
                bodyAddresses.contains(payload.withUnsafeBytes { UInt(bitPattern: $0.baseAddress) })
            },
            "the literal should refer to the read it arrived in"
        )
    }
}
