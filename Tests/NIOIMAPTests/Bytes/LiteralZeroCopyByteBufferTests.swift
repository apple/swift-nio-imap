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
/// bytes; these two tests say which received bytes those can be. A `ByteBuffer` accumulated into an
/// ``IMAPInputBuffer`` qualifies, and a caller gets it back out as a slice of its own storage. A
/// `ByteBuffer` handed straight to the parser does not, and its payload is copied — which is what stops
/// "everything is zero-copy now" from being reachable by making everything retain.
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
    private func streamedPayload<Input: ConsumableParserInputBuffer>(
        from input: inout Input
    ) throws -> IMAPBuffer {
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

    @Test("a literal read out of a bare ByteBuffer is copied, because nobody vouched for it")
    func byteBufferInputCopies() throws {
        let byteCount = 4 * IMAPBuffer.copyThreshold
        let payload = String(repeating: "x", count: byteCount)
        var buffer = ByteBuffer(string: "* 1 FETCH (RFC822.TEXT {\(byteCount)}\r\n\(payload))\r\n")
        let inputStorage = storageRange(of: buffer)

        let streamed = try streamedPayload(from: &buffer)

        // Not a defect: a `ByteBuffer` handed straight to the parser is gone as soon as the caller
        // reassigns it, so the library cannot promise the payload's bytes will still be there.
        #expect(streamed.backingRegion(as: ByteBuffer.self) == nil)
        #expect(!inputStorage.contains(streamed.withUnsafeBytes { UInt(bitPattern: $0.baseAddress) }))
    }
}
