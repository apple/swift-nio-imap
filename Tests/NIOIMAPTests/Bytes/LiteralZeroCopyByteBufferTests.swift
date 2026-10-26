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
import NIOIMAP
import NIOIMAPCore
import Testing

/// The `ByteBuffer` half of `NIOIMAPCoreTests`' `LiteralZeroCopyTests`.
///
/// That suite pins the property that a large literal reaches the caller as a reference to the received
/// bytes; these tests say when a `ByteBuffer` accumulated into an ``IMAPInputBuffer`` qualifies, and that
/// a caller gets it back out as a slice of its own storage.
@Suite("Literal zero copy from a ByteBuffer")
struct LiteralZeroCopyByteBufferTests {
    /// The address range a `ByteBuffer`'s readable bytes live in.
    private func storageRange(of buffer: ByteBuffer) -> Range<UInt> {
        buffer.withUnsafeReadableBytes { bytes in
            let base = UInt(bitPattern: bytes.baseAddress)
            return base..<(base + UInt(bytes.count))
        }
    }

    /// Reads one FETCH response carrying a literal out of `input` and returns the payload.
    private func streamedPayload(from input: inout IMAPInputBuffer) throws -> IMAPBuffer {
        var parser = ResponseParser()
        while true {
            guard case .response(.fetch(let fetch)) = try parser.parseResponseStream(buffer: &input) else {
                continue
            }
            if case .streamingBytes(let bytes) = fetch {
                return bytes
            }
        }
    }

    @Test("a literal read out of an accumulated ByteBuffer refers to that buffer's storage")
    func accumulatedByteBufferIsReferenced() throws {
        let byteCount = 4 * IMAPBuffer.copyThreshold
        let payload = String(repeating: "x", count: byteCount)
        let read = ByteBuffer(string: "* 1 FETCH (RFC822.TEXT {\(byteCount)}\r\n\(payload))\r\n")
        let inputStorage = storageRange(of: read)

        var buffer = IMAPInputBuffer()
        buffer.append(read)
        let streamed = try streamedPayload(from: &buffer)

        // Referenced, and specifically referencing the `ByteBuffer` the caller appended — so
        // `IMAPBuffer.byteBuffer` hands it back as a slice rather than a copy.
        #expect(streamed.backingRegion(as: ByteBuffer.self) != nil)

        let address = streamed.withUnsafeBytes { UInt(bitPattern: $0.baseAddress) }
        #expect(inputStorage.contains(address))
        // The round trip back out is a slice of the same storage, not a copy of it.
        #expect(inputStorage.contains(storageRange(of: streamed.byteBuffer).lowerBound))
    }

    /// The 1 KiB literal parsed out of one `ByteBuffer` read allocated with room for `capacity` bytes.
    private func literal(inReadOfCapacity capacity: Int) throws -> (payload: IMAPBuffer, storageCapacity: Int) {
        let byteCount = IMAPBuffer.copyThreshold
        let payload = String(repeating: "x", count: byteCount)
        var read = ByteBufferAllocator().buffer(capacity: capacity)
        read.writeString("* 1 FETCH (RFC822.TEXT {\(byteCount)}\r\n\(payload))\r\n")

        var buffer = IMAPInputBuffer()
        buffer.append(read)
        return (try streamedPayload(from: &buffer), read.storageCapacity)
    }

    @Test("a 1 KiB literal is copied out of a 64 KiB ByteBuffer, which it would pin, and kept out of a 2 KiB one")
    func literalIsWeighedAgainstStorageCapacity() throws {
        let large = try literal(inReadOfCapacity: 64 * 1_024)
        #expect(large.storageCapacity >= 64 * 1_024)
        #expect(large.payload.backingRegion(as: ByteBuffer.self) == nil, "copied")

        let small = try literal(inReadOfCapacity: 2 * 1_024)
        #expect(small.storageCapacity <= 3 * IMAPBuffer.copyThreshold, "small enough for the literal to be kept")
        #expect(small.payload.backingRegion(as: ByteBuffer.self) != nil, "kept")
    }
}
