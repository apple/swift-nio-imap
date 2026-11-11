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

@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import Testing

#if canImport(ObjectiveC)
import Foundation  // for a bridged `NSString`
#endif

/// The encoder writing into an ``EncoderOutputBuffer`` instead of into one contiguous buffer.
///
/// The cases here are the ones the change could get wrong without any existing test noticing: stop
/// points now being offsets into "bytes ever written" rather than positions in a buffer whose contents
/// are handed away, and the sink being reachable through an existential that copies.
@Suite("EncodeBuffer over a sink")
struct EncodeBufferSinkTests {
    private func clientBuffer(_ options: CommandEncodingOptions = .rfc3501) -> EncodeBuffer {
        EncodeBuffer.clientEncodeBuffer(options: options, loggingMode: false)
    }

    private func drain(_ buffer: inout EncodeBuffer) -> [String] {
        var chunks: [String] = []
        while true {
            let chunk = buffer.nextChunk()
            chunks.append(String(buffer: chunk.bytes))
            guard chunk.waitForContinuation else { return chunks }
        }
    }

    // MARK: - Stop points

    /// The case that deadlocks the protocol if stop points are measured against the sink's own byte
    /// count: after the first chunk is handed out, the sink is holding fewer bytes than were written,
    /// so a stop point recorded before the hand-out is meaningless as a position within it.
    @Test("a stop point is an offset into everything written, not into what is pending")
    func stopPointsAreAbsolute() {
        var buffer = clientBuffer()
        buffer.writeString("A1 LOGIN {1}\r\n")
        buffer.markStopPoint()
        buffer.writeString("x {1}\r\n")
        buffer.markStopPoint()
        buffer.writeString("y\r\n")

        #expect(drain(&buffer) == ["A1 LOGIN {1}\r\n", "x {1}\r\n", "y\r\n"])
    }

    /// A stop point at the very end means "everything has been written", so the last chunk must not
    /// ask for a continuation. One byte out either way is the deadlock.
    @Test("a trailing stop point does not ask for a continuation")
    func trailingStopPointDoesNotWait() {
        var buffer = clientBuffer()
        buffer.writeString("A1 LOGIN {1}\r\n")
        buffer.markStopPoint()
        buffer.writeString("x")
        buffer.markStopPoint()

        var first = buffer.nextChunk()
        #expect(String(buffer: first.bytes) == "A1 LOGIN {1}\r\n")
        #expect(first.waitForContinuation)

        first = buffer.nextChunk()
        #expect(String(buffer: first.bytes) == "x")
        #expect(!first.waitForContinuation)
    }

    @Test("hasChunks tracks the outstanding stop points")
    func hasChunks() {
        var buffer = clientBuffer()
        #expect(!buffer.hasChunks)
        buffer.writeString("A1 LOGIN {1}\r\n")
        buffer.markStopPoint()
        #expect(buffer.hasChunks)
        buffer.writeString("x\r\n")
        _ = buffer.nextChunk()
        #expect(!buffer.hasChunks)
    }

    @Test("a server-mode buffer ignores stop points and hands out everything at once")
    func serverModeTakesEverything() {
        var buffer = EncodeBuffer.serverEncodeBuffer(options: ResponseEncodingOptions(), loggingMode: false)
        buffer.writeString("* OK ")
        buffer.markStopPoint()
        buffer.writeString("hello\r\n")
        #expect(drain(&buffer) == ["* OK hello\r\n"])
    }

    @Test("clear resets the counters as well as the bytes")
    func clearResetsCounters() {
        var buffer = clientBuffer()
        buffer.writeString("A1 LOGIN {1}\r\n")
        buffer.markStopPoint()
        buffer.writeString("x\r\n")
        buffer.clear()

        #expect(buffer.pendingByteCount == 0)
        #expect(!buffer.hasChunks)

        // Writing again must start from zero: a stop point recorded now is at offset 2, and comparing
        // it against a counter that still remembers the cleared bytes would split in the wrong place.
        buffer.writeString("A2")
        buffer.markStopPoint()
        buffer.writeString(" NOOP\r\n")
        #expect(drain(&buffer) == ["A2", " NOOP\r\n"])
    }

    /// Chunking is where a `ByteBuffer`-backed encoder used to copy: handing out a slice left the
    /// storage shared, so every later write copied what remained. Segments have no such coupling, and
    /// what a caller can observe is that bytes handed out earlier are unaffected by writes afterwards.
    @Test("bytes already handed out are unchanged by later writes")
    func handedOutBytesAreStable() {
        var buffer = clientBuffer()
        buffer.writeString("A1 LOGIN {1}\r\n")
        buffer.markStopPoint()
        buffer.writeString("x")

        let first = buffer.nextChunk()
        #expect(first.waitForContinuation)

        // Enough to overflow the first segment and force new ones.
        for _ in 0..<4096 {
            buffer.writeString("0123456789abcdef")
        }
        #expect(String(buffer: first.bytes) == "A1 LOGIN {1}\r\n")
    }

    // MARK: - Chunk contents

    @Test("a chunk reports bytes and regions separately")
    func chunkCounts() {
        var buffer = clientBuffer()
        // Above `copyThreshold`, so the sink keeps this region by reference rather than copying it
        // into a segment — which is what makes the chunk multi-region.
        let payload = IMAPBuffer([UInt8](repeating: UInt8(ascii: "z"), count: 4096))
        buffer.writeString("A1 ")
        buffer.writeBytes(payload)
        buffer.writeString("\r\n")

        let chunk = buffer.nextChunk()
        #expect(chunk.bytes.byteCount == 3 + 4096 + 2)
        #expect(chunk.bytes.regionCount == 3)
        #expect(chunk.bytes.copiedBytes().count == 3 + 4096 + 2)
    }

    @Test("an empty buffer hands out an empty chunk rather than nothing")
    func emptyChunk() {
        var buffer = clientBuffer()
        let chunk = buffer.nextChunk()
        #expect(chunk.bytes.byteCount == 0)
        #expect(!chunk.waitForContinuation)
    }

    // MARK: - Equality

    @Test("two buffers holding the same bytes are equal however their sinks split them")
    func equalityIgnoresSegmentation() {
        // 64 bytes at a time into a sink with tiny segments, against one write into a default one:
        // the same bytes, but many regions versus one.
        var fragmented = EncodeBuffer.clientEncodeBuffer(
            sink: IMAPOutputBuffer(initialSegmentSize: 8, maximumSegmentSize: 8),
            options: .rfc3501,
            loggingMode: false
        )
        var contiguous = clientBuffer()
        let text = String(repeating: "abcdefgh", count: 8)
        for character in text {
            fragmented.writeString(String(character))
        }
        contiguous.writeString(text)

        #expect(fragmented.pendingByteCount == contiguous.pendingByteCount)
        #expect(fragmented == contiguous)
        #expect(fragmented.hashValue == contiguous.hashValue)
    }

    @Test("buffers holding different bytes are not equal")
    func inequality() {
        var a = clientBuffer()
        var b = clientBuffer()
        a.writeString("A1 NOOP\r\n")
        b.writeString("A2 NOOP\r\n")
        #expect(a != b)
    }

    @Test("buffers differing only in their stop points are not equal")
    func stopPointsParticipateInEquality() {
        var a = clientBuffer()
        var b = clientBuffer()
        a.writeString("A1 LOGIN {1}\r\n")
        a.markStopPoint()
        b.writeString("A1 LOGIN {1}\r\n")
        #expect(a != b)
    }

    // MARK: - Copying

    /// `ClientStateMachine` stores an encode buffer in its state *and* returns it, and the encode
    /// fixtures advance a copy while the original is live. Both copies have to keep working, and
    /// neither may see the other's bytes.
    @Test("a copy and the original write independently")
    func copiesAreIndependent() {
        var original = clientBuffer()
        original.writeString("A1 ")

        var copy = original
        copy.writeString("NOOP\r\n")
        original.writeString("EXPUNGE\r\n")

        #expect(drain(&copy) == ["A1 NOOP\r\n"])
        #expect(drain(&original) == ["A1 EXPUNGE\r\n"])
    }

    /// The failure this guards against is not wrong bytes but wrong *shape*: a spurious copy of the
    /// buffer makes the sink's state look shared, and a shared sink seals its open segment and starts
    /// a new one. That used to happen once per conditional write, so an array of *n* elements became
    /// *n* segments and *n* output regions with the segment size doubling each time.
    @Test("writing an array does not fragment the output")
    func writingAnArrayStaysInOneRegion() {
        var buffer = EncodeBuffer.serverEncodeBuffer(options: ResponseEncodingOptions(), loggingMode: false)
        buffer.writeMessageAttribute(.flags([.answered, .draft, .flagged, .seen]))
        let chunk = buffer.nextChunk()
        #expect(String(buffer: chunk.bytes) == #"FLAGS (\Answered \Draft \Flagged \Seen)"#)
        #expect(chunk.bytes.regionCount == 1)
    }

    // MARK: - The region cap

    /// Payloads at the copy threshold: each is kept by reference, so each is a region of its own.
    private func payloads(_ count: Int) -> [IMAPBuffer] {
        (0..<count).map {
            IMAPBuffer([UInt8](repeating: UInt8(truncatingIfNeeded: $0), count: IMAPBuffer.copyThreshold))
        }
    }

    @Test("a chunk is capped at 64 regions, and the excess is coalesced rather than dropped")
    func regionCap() {
        var buffer = clientBuffer()
        let payloads = payloads(200)
        for payload in payloads {
            buffer.writeBytes(payload)
        }
        let chunk = buffer.nextChunk()
        #expect(chunk.bytes.regionCount == IMAPBufferList.maximumRegionsPerChunk)
        #expect(chunk.bytes.copiedBytes() == payloads.flatMap { $0.copiedBytes() }, "no bytes may be lost to the cap")
    }

    @Test("a chunk that ends at a stop point is capped too")
    func regionCapAtStopPoint() {
        var buffer = clientBuffer()
        for payload in payloads(200) {
            buffer.writeBytes(payload)
        }
        buffer.markStopPoint()
        buffer.writeString("x")
        let chunk = buffer.nextChunk()
        #expect(chunk.waitForContinuation)
        #expect(chunk.bytes.regionCount == IMAPBufferList.maximumRegionsPerChunk)
        #expect(chunk.bytes.byteCount == 200 * IMAPBuffer.copyThreshold)
    }

    @Test("a chunk exactly at the cap is not coalesced")
    func regionCapBoundary() {
        var buffer = clientBuffer()
        for payload in payloads(IMAPBufferList.maximumRegionsPerChunk) {
            buffer.writeBytes(payload)
        }
        #expect(buffer.nextChunk().bytes.regionCount == IMAPBufferList.maximumRegionsPerChunk)
    }

    // MARK: - A caller's own sink

    @Test("the encoder writes into a sink the caller supplies")
    func customSink() {
        var buffer = EncodeBuffer.clientEncodeBuffer(
            sink: CollectingOutputBuffer(),
            options: .rfc3501,
            loggingMode: false
        )
        buffer.writeString("A1 NOOP\r\n")
        #expect(buffer.pendingByteCount == 9)
        #expect(String(buffer: buffer.nextChunk().bytes) == "A1 NOOP\r\n")
    }

    // MARK: - Staging

    private func recordingBuffer() -> EncodeBuffer {
        EncodeBuffer.clientEncodeBuffer(sink: RecordingOutputBuffer(), options: .rfc3501, loggingMode: false)
    }

    /// The size of every `append` the sink has received so far.
    private func appendSizes(_ buffer: EncodeBuffer) throws -> [Int] {
        try #require(buffer.sink as? RecordingOutputBuffer).appendSizes
    }

    @Test("small writes reach the sink as one append, at hand-out")
    func smallWritesAreBatched() throws {
        var buffer = recordingBuffer()
        buffer.writeString("A1 ")
        buffer.writeString("NOOP")
        buffer.writeByte(UInt8(ascii: "\r"))
        buffer.writeByte(UInt8(ascii: "\n"))
        #expect(try appendSizes(buffer) == [])

        #expect(String(buffer: buffer.nextChunk().bytes) == "A1 NOOP\r\n")
        #expect(try appendSizes(buffer) == [9])
    }

    #if canImport(ObjectiveC)
    @Test("a string with no contiguous UTF-8 is written in full")
    func writeForeignString() throws {
        // A non-ASCII `NSString` bridges lazily, as UTF-16: its UTF-8 view isn't contiguous.
        let foreign = try #require(NSString(utf8String: "Ünïcødé Mailbox 📬")) as String
        try #require(foreign.utf8.withContiguousStorageIfAvailable { _ in } == nil)
        var buffer = recordingBuffer()
        #expect(buffer.writeString(foreign) == foreign.utf8.count)
        #expect(String(buffer: buffer.nextChunk().bytes) == foreign)
    }
    #endif

    @Test("staged bytes count as pending, though the sink has not seen them")
    func stagedBytesArePending() {
        var buffer = recordingBuffer()
        buffer.writeString("A1 NOOP\r\n")
        #expect(buffer.sink.byteCount == 0)
        #expect(buffer.pendingByteCount == 9)

        _ = buffer.nextChunk()
        #expect(buffer.pendingByteCount == 0)
    }

    @Test("a write of at least the staging size goes to the sink directly, after what is staged")
    func stagingBoundary() throws {
        let capacity = EncodeBuffer.stagingCapacity
        var buffer = recordingBuffer()
        buffer.writeByte(UInt8(ascii: "a"))
        buffer.writeBytes([UInt8](repeating: UInt8(ascii: "b"), count: capacity))
        #expect(try appendSizes(buffer) == [1, capacity])

        // Exactly filling the staging area still stages; the next byte flushes it.
        buffer.writeBytes([UInt8](repeating: UInt8(ascii: "c"), count: capacity - 1))
        buffer.writeByte(UInt8(ascii: "d"))
        #expect(try appendSizes(buffer) == [1, capacity])
        buffer.writeByte(UInt8(ascii: "e"))
        #expect(try appendSizes(buffer) == [1, capacity, capacity])
        #expect(buffer.pendingByteCount == 1 + capacity + capacity + 1)

        let expected =
            "a" + String(repeating: "b", count: capacity) + String(repeating: "c", count: capacity - 1) + "de"
        #expect(String(buffer: buffer.nextChunk().bytes) == expected)
    }

    @Test("a synchronizing literal splits chunks at the right byte while the bytes are staged")
    func stopPointWithStagedBytes() {
        var encoder = CommandEncodeBuffer(sink: RecordingOutputBuffer(), options: .rfc3501, loggingMode: false)
        // An 8-bit username can't be quoted, so it is a literal.
        encoder.writeCommand(TaggedCommand(tag: "A1", command: .login(username: "å", password: "pass")))
        #expect(encoder.buffer.sink.byteCount == 0, "everything is still staged")

        let first = encoder.nextChunk()
        #expect(first.map { String(buffer: $0.bytes) } == "A1 LOGIN {2}\r\n")
        #expect(first?.nextStep == .awaitContinuationRequest)
        let second = encoder.nextChunk()
        #expect(second.map { String(buffer: $0.bytes) } == "å \"pass\"\r\n")
        #expect(second?.nextStep == .proceed)
        #expect(encoder.nextChunk() == nil)
    }

    @Test("a stop point at the last byte written splits there while the bytes are staged")
    func trailingStopPointWithStagedBytes() {
        var encoder = CommandEncodeBuffer(sink: RecordingOutputBuffer(), options: .rfc3501, loggingMode: false)
        encoder.writeCommandStream(.append(.beginMessage(message: .init(options: .none, data: .init(byteCount: 5)))))
        #expect(encoder.buffer.sink.byteCount == 0, "everything is still staged")

        let header = encoder.nextChunk()
        #expect(header.map { String(buffer: $0.bytes) } == " {5}\r\n")
        #expect(header?.nextStep == .awaitContinuationRequest)
        #expect(encoder.nextChunk() == nil)

        encoder.buffer.writeString("hello")
        let message = encoder.nextChunk()
        #expect(message.map { String(buffer: $0.bytes) } == "hello")
        #expect(message?.nextStep == .proceed)
    }

    @Test("staged bytes take part in equality and hashing")
    func equalityWithStagedBytes() {
        var staged = clientBuffer()
        staged.writeString("A1 NOOP\r\n")
        // Writing an `IMAPBuffer` flushes, so these bytes are in the sink rather than staged.
        var flushed = clientBuffer()
        flushed.writeString("A1 ")
        flushed.writeBytes(IMAPBuffer(Array("NOOP\r\n".utf8)))
        var different = clientBuffer()
        different.writeString("A1 NOOQ\r\n")

        #expect(staged == flushed)
        #expect(staged.hashValue == flushed.hashValue)
        #expect(staged != different)
    }

    /// ``equalityIgnoresSegmentation`` with more than ``EncodeBuffer/stagingCapacity`` bytes, so the
    /// one-byte writes reach the tiny segments in several flushes rather than as one staged region.
    @Test("equality ignores segmentation past the staging area too")
    func equalityIgnoresSegmentationPastStaging() {
        var fragmented = EncodeBuffer.clientEncodeBuffer(
            sink: IMAPOutputBuffer(initialSegmentSize: 8, maximumSegmentSize: 8),
            options: .rfc3501,
            loggingMode: false
        )
        var contiguous = clientBuffer()
        let text = String(repeating: "abcdefgh", count: 100)
        for character in text {
            fragmented.writeString(String(character))
        }
        contiguous.writeString(text)

        #expect(fragmented.makePendingBufferList().regionCount > contiguous.makePendingBufferList().regionCount)
        #expect(fragmented == contiguous)
        #expect(fragmented.hashValue == contiguous.hashValue)
    }

    /// ``writingAnArrayStaysInOneRegion`` with more than ``EncodeBuffer/stagingCapacity`` bytes, so
    /// the array reaches the sink in several appends, which a spurious copy would split into segments.
    @Test("writing an array longer than the staging area does not fragment the output")
    func writingALongArrayStaysInOneRegion() {
        // Room for the whole output in one segment.
        let segmentSize = 4096
        var buffer = EncodeBuffer.serverEncodeBuffer(
            sink: IMAPOutputBuffer(initialSegmentSize: segmentSize, maximumSegmentSize: segmentSize),
            options: ResponseEncodingOptions(),
            loggingMode: false
        )
        let flags = (0..<100).compactMap { Flag("keyword\($0)") }
        buffer.writeMessageAttribute(.flags(flags))
        let chunk = buffer.nextChunk()
        #expect(chunk.bytes.byteCount > EncodeBuffer.stagingCapacity)
        #expect(chunk.bytes.regionCount == 1)
    }

    @Test("a large region written after staged bytes follows them, by reference")
    func largeRegionAfterStagedBytes() throws {
        var buffer = clientBuffer()
        let payload = IMAPBuffer([UInt8](repeating: UInt8(ascii: "z"), count: IMAPBuffer.copyThreshold))
        buffer.writeString("A1 ")
        buffer.writeBytes(payload)
        buffer.writeString("\r\n")

        let chunk = buffer.nextChunk()
        #expect(String(buffer: chunk.bytes) == "A1 " + String(repeating: "z", count: IMAPBuffer.copyThreshold) + "\r\n")
        let regions = Array(chunk.bytes.regions)
        try #require(regions.count == 3)
        let address = { (region: IMAPBuffer) in
            region.withUnsafeBytesAndOwner { bytes, _ in UnsafeRawPointer(bytes.baseAddress) }
        }
        #expect(address(regions[1]) == address(payload), "the payload is not copied")
    }
}

/// The simplest possible ``EncoderOutputBuffer``: a byte array.
///
/// It exists to check that the protocol is usable from outside the package — that a caller who wants
/// the bytes somewhere else does not need any of ``IMAPOutputBuffer``'s machinery, only the six
/// members below.
private struct CollectingOutputBuffer: EncoderOutputBuffer {
    private var bytes: [UInt8] = []

    var byteCount: Int { bytes.count }

    mutating func append(_ bytes: UnsafeRawBufferPointer) {
        self.bytes.append(contentsOf: bytes)
    }

    mutating func append(_ region: IMAPBuffer) {
        region.withUnsafeBytes { self.bytes.append(contentsOf: $0) }
    }

    mutating func takeFirst(_ byteCount: Int) -> IMAPBufferList {
        let taken = Array(bytes.prefix(byteCount))
        bytes.removeFirst(byteCount)
        return IMAPBufferList(IMAPBuffer(taken))
    }

    func withPendingRegions<R>(_ body: (Span<IMAPBuffer>) -> R) -> R {
        let regions: ContiguousArray<IMAPBuffer> = [IMAPBuffer(bytes)]
        return body(regions.span)
    }

    mutating func removeAll() {
        bytes = []
    }
}

/// A byte-array sink that records the size of every `append`, to observe what the encoder stages.
private struct RecordingOutputBuffer: EncoderOutputBuffer {
    private var bytes: [UInt8] = []
    private(set) var appendSizes: [Int] = []

    var byteCount: Int { bytes.count }

    mutating func append(_ bytes: UnsafeRawBufferPointer) {
        appendSizes.append(bytes.count)
        self.bytes.append(contentsOf: bytes)
    }

    mutating func append(_ region: IMAPBuffer) {
        appendSizes.append(region.count)
        region.withUnsafeBytes { self.bytes.append(contentsOf: $0) }
    }

    mutating func takeFirst(_ byteCount: Int) -> IMAPBufferList {
        let taken = Array(bytes.prefix(byteCount))
        bytes.removeFirst(byteCount)
        return IMAPBufferList(IMAPBuffer(taken))
    }

    func withPendingRegions<R>(_ body: (Span<IMAPBuffer>) -> R) -> R {
        let regions: ContiguousArray<IMAPBuffer> = [IMAPBuffer(bytes)]
        return body(regions.span)
    }

    mutating func removeAll() {
        bytes = []
    }
}
