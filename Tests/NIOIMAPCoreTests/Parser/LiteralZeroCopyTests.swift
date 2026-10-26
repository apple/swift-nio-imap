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

import Testing

@_spi(NIOIMAPInternal) @testable import NIOIMAPCore

/// Pins the property that raw message bytes reach a caller without being copied.
///
/// This is easy to lose silently. `IMAPBuffer` compares by bytes, so every other test in the suite
/// passes whether the bytes were referenced or copied — which means a change that quietly turns the
/// zero-copy path off is invisible everywhere except here.
///
/// The input has to be an ``IMAPInputBuffer`` for any of it to hold: it is the only input type that
/// keeps the bytes it was given, and therefore the only one that can vouch for them. The other half of
/// that claim — that an input which cannot vouch for its bytes copies, and is supposed to — is in
/// `NIOIMAPTests`, where there is a `ByteBuffer` to demonstrate it with.
@Suite("Literal zero copy")
struct LiteralZeroCopyTests {
    /// The address range a region's bytes live in.
    private func storageRange(of bytes: [UInt8]) -> Range<UInt> {
        bytes.withUnsafeBytes { bytes in
            let base = UInt(bitPattern: bytes.baseAddress)
            return base..<(base + UInt(bytes.count))
        }
    }

    /// Feeds the parser one response carrying a literal of `byteCount` bytes and returns the payload it
    /// produced, along with the address range of the storage the bytes were read from.
    private func streamedPayload(
        byteCount: Int
    ) throws -> (payload: IMAPBuffer, inputStorage: Range<UInt>) {
        let payload = String(repeating: "x", count: byteCount)
        let read = Array("* 1 FETCH (RFC822.TEXT {\(byteCount)}\r\n\(payload))\r\n".utf8)
        let inputStorage = storageRange(of: read)

        var buffer = IMAPInputBuffer()
        buffer.append(read)

        var parser = ResponseParser()
        var streamed: IMAPBuffer?
        while streamed == nil {
            guard case .response(.fetch(let fetch)) = try parser.parseResponseStream(buffer: &buffer) else {
                continue
            }
            if case .streamingBytes(let bytes) = fetch {
                streamed = bytes
            }
        }
        return (try #require(streamed), inputStorage)
    }

    @Test("a literal at or above the copy threshold refers to the input rather than copying it")
    func largeLiteralIsReferenced() throws {
        let (payload, inputStorage) = try streamedPayload(byteCount: IMAPBuffer.copyThreshold)

        #expect(payload.count == IMAPBuffer.copyThreshold)

        // Referenced, not owned…
        let retained = try #require(payload.retainedRegion)
        // …and specifically referencing the region the caller appended, so a caller gets its own bytes
        // back out without a copy either.
        #expect(retained.storage.wrappedRegion(as: [UInt8].self) != nil)

        // The strongest form of the claim: the bytes live inside the input's storage.
        let address = payload.withUnsafeBytes { UInt(bitPattern: $0.baseAddress) }
        #expect(inputStorage.contains(address))
    }

    @Test("a literal below the copy threshold is copied, so it pins nothing")
    func smallLiteralIsCopied() throws {
        let (payload, _) = try streamedPayload(byteCount: IMAPBuffer.copyThreshold - 1)

        #expect(payload.count == IMAPBuffer.copyThreshold - 1)
        #expect(payload.retainedRegion == nil)
    }

    @Test("a literal arriving in several reads is referenced for each read that is large enough")
    func multiChunkLiteralIsReferencedPerChunk() throws {
        // A 4 KB literal delivered as MTU-sized reads: each chunk is well above the threshold, so every
        // `.streamingBytes` event should refer to the read it came from — and no read is copied to be
        // parsed alongside its neighbours, which is what the input buffer is for.
        let byteCount = 4 * 1_024
        let readSize = 1_448
        let wire = Array(
            "* 1 FETCH (RFC822.TEXT {\(byteCount)}\r\n\(String(repeating: "x", count: byteCount)))\r\n".utf8
        )

        var parser = ResponseParser()
        var buffer = IMAPInputBuffer()
        var payloads: [IMAPBuffer] = []
        var reads: [Range<UInt>] = []
        var offset = 0
        while offset < wire.count {
            let end = min(offset + readSize, wire.count)
            let read = Array(wire[offset..<end])
            reads.append(storageRange(of: read))
            buffer.append(read)
            offset = end
            while let response = try parser.parseResponseStream(buffer: &buffer) {
                guard case .response(.fetch(.streamingBytes(let bytes))) = response else { continue }
                payloads.append(bytes)
            }
        }

        #expect(payloads.count > 1, "expected the literal to arrive in more than one piece")
        #expect(payloads.reduce(0) { $0 + $1.count } == byteCount)
        #expect(payloads.allSatisfy { $0.count < IMAPBuffer.copyThreshold || $0.retainedRegion != nil })
        // Non-vacuity: at least one piece was big enough to be worth referencing, and was.
        #expect(payloads.contains { $0.retainedRegion != nil })
        // Every referenced piece points into one of the reads, not into a buffer the library built.
        for payload in payloads where payload.retainedRegion != nil {
            let address = payload.withUnsafeBytes { UInt(bitPattern: $0.baseAddress) }
            #expect(reads.contains { $0.contains(address) })
        }
    }
}
