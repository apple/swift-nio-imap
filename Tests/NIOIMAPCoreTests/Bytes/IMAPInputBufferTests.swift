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

import Dispatch
import Foundation
import Testing

/// Coverage for the buffer a connection accumulates received bytes into.
///
/// Three properties are the reason this type exists rather than an array, and each one has a test here
/// that an array would fail: appending does not copy, discarding a prefix does not move the remainder,
/// and a payload handed to a caller stays valid after the buffer has moved past it.
@Suite("IMAPInputBuffer")
struct IMAPInputBufferTests {}

// MARK: - Helpers

/// Whether a deallocator has run. Touched only on the deallocator queue, so `@unchecked` is safe.
private final class Deallocation: @unchecked Sendable {
    var hasRun = false
}

extension IMAPInputBufferTests {
    private static func buffer(_ pieces: [String]) -> IMAPInputBuffer {
        var buffer = IMAPInputBuffer()
        for piece in pieces { buffer.append(Array(piece.utf8)) }
        return buffer
    }

    private static func text(_ buffer: IMAPInputBuffer) -> String {
        buffer.byteRegions.map { String(decoding: $0.copiedBytes(), as: UTF8.self) }.joined()
    }

    /// A read big enough to be kept as its own region rather than copied into a tail.
    private static func large(_ letter: Character) -> String {
        String(repeating: letter, count: IMAPBuffer.copyThreshold)
    }

    /// Where region `index` currently starts. The view is released before this returns, so it does not
    /// count as a reference to the region afterwards.
    private static func address(of index: Int, in buffer: IMAPInputBuffer) -> UInt {
        buffer.byteRegions[index].withUnsafeBytes { UInt(bitPattern: $0.baseAddress) }
    }
}

// MARK: - Appending

extension IMAPInputBufferTests {
    @Test("Appending adds bytes and regions")
    func appending() {
        var buffer = IMAPInputBuffer()
        #expect(buffer.isEmpty)
        #expect(buffer.count == 0)
        #expect(buffer.regionCount == 0)

        buffer.append(Array("A001 ".utf8))
        buffer.append(Array("NOOP\r\n".utf8))
        #expect(buffer.count == 11)
        #expect(buffer.regionCount == 1, "two small reads share a tail")
        #expect(buffer.isEmpty == false)
        #expect(buffer.description == "IMAPInputBuffer(11 bytes in 1 region)")

        buffer.append(Array(Self.large("x").utf8))
        #expect(buffer.description == "IMAPInputBuffer(1035 bytes in 2 regions)")
    }

    @Test("Appending nothing does nothing")
    func appendingEmpty() {
        // Worth pinning: an empty region in the queue would make `chunks.first` present with no bytes to
        // read, which is the state the cursor's head invariant exists to rule out.
        var buffer = IMAPInputBuffer()
        buffer.append([UInt8]())
        #expect(buffer.regionCount == 0)
        buffer.append(Array("x".utf8))
        buffer.append([UInt8]())
        #expect(buffer.regionCount == 1)
        #expect(buffer.count == 1)
    }

    @Test("Appended bytes are parsed where they lie, not copied")
    func appendingDoesNotCopy() throws {
        let payload = Array(repeating: UInt8(ascii: "p"), count: 2048)
        // The array's storage does not move while it is alive, and appending it retains that storage
        // rather than copying it — so this address must come back out of the parser.
        let appendedAt = payload.withUnsafeBytes { $0.baseAddress! }
        var buffer = IMAPInputBuffer()
        buffer.append(payload)
        let extracted = try buffer.parse { try $0.extractBuffer(upTo: payload.count) }
        #expect(extracted.withUnsafeBytes { $0.baseAddress! } == appendedAt)
    }
}

// MARK: - Discarding

extension IMAPInputBufferTests {
    @Test("Discarding part of the first region moves the read head")
    func discardWithinARegion() {
        var buffer = Self.buffer(["abcdef"])
        buffer.discardFirst(2)
        #expect(buffer.count == 4)
        #expect(buffer.regionCount == 1, "the region is sliced, not dropped")
        #expect(Self.text(buffer) == "cdef")
    }

    @Test("Discarding a whole region drops it")
    func discardWholeRegions() {
        let size = IMAPBuffer.copyThreshold
        var buffer = Self.buffer([Self.large("a"), Self.large("b"), Self.large("c")])
        buffer.discardFirst(size)
        #expect(buffer.regionCount == 2)
        #expect(Self.text(buffer) == Self.large("b") + Self.large("c"))

        buffer.discardFirst(2 * size - 2)
        #expect(buffer.count == 2)
        #expect(buffer.regionCount == 1)
        #expect(Self.text(buffer) == "cc")

        buffer.discardFirst(2)
        #expect(buffer.isEmpty)
        #expect(buffer.regionCount == 0)
    }

    @Test("Discarding nothing, and discarding everything")
    func discardEdges() {
        var buffer = Self.buffer(["abc", "def"])
        buffer.discardFirst(0)
        #expect(buffer.count == 6)
        buffer.discardFirst(6)
        #expect(buffer.isEmpty)
        #expect(Self.text(buffer) == "")

        buffer.append(Array("gh".utf8))
        #expect(Self.text(buffer) == "gh", "a buffer that has been drained is still usable")
    }

    @Test("Removing everything keeps the buffer usable")
    func removeAll() {
        var buffer = Self.buffer(["abc", "def"])
        buffer.removeAll()
        #expect(buffer.isEmpty)
        #expect(buffer.regionCount == 0)
        buffer.append(Array("xy".utf8))
        #expect(Self.text(buffer) == "xy")
    }

    @Test("The regions begin at the read head and add up to the count")
    func regionsBeginAtTheReadHead() {
        // The conformance requirement the gather asserts. A buffer that handed over the consumed prefix
        // as well would have the parser report consuming bytes it was shown twice, and the trim would
        // then skip past bytes nobody parsed.
        let first = "abcd" + Self.large("p")
        var buffer = Self.buffer([first, Self.large("q")])
        buffer.discardFirst(3)
        let regions = buffer.byteRegions
        #expect(regions.count == 2)
        #expect(regions[0].copiedBytes() == Array(first.utf8.dropFirst(3)))
        #expect(regions[1].copiedBytes() == Array(Self.large("q").utf8))
        #expect(regions.reduce(0) { $0 + $1.count } == buffer.count)
    }
}

// MARK: - Parsing

extension IMAPInputBufferTests {
    @Test("A message split across two reads is parsed across them")
    func straddlingMessage() throws {
        // No copy: two large reads stay where they are and the cursor walks from one into the other.
        let first = "A001 " + Self.large("x")
        let second = Self.large("y") + "\r\nA002 "
        var buffer = Self.buffer([first, second])
        let lineLength = first.utf8.count + IMAPBuffer.copyThreshold + 2
        let line = try buffer.parse { try $0.extractBytes(length: lineLength) }
        #expect(String(decoding: line, as: UTF8.self) == first + Self.large("y") + "\r\n")
        #expect(buffer.count == 5)
        #expect(buffer.regionCount == 1, "the used-up first region is gone")
        #expect(Self.text(buffer) == "A002 ")
    }

    @Test("A payload outlives the bytes' place in the queue")
    func payloadOutlivesTheBuffer() throws {
        // This is what "the buffer owns its runs" buys, and it is why `count` counts live bytes rather
        // than allocated ones: the run stays alive as long as somebody is holding a payload from it, even
        // though the buffer has moved on.
        let payload = Array(repeating: UInt8(ascii: "q"), count: 4096)
        var buffer = IMAPInputBuffer()
        buffer.append(payload)
        let extracted = try buffer.parse { try $0.extractBuffer(upTo: payload.count) }
        #expect(buffer.isEmpty)
        #expect(extracted.retainedRegion != nil, "a payload this size should not have been copied")

        buffer.removeAll()
        buffer.append(Array(repeating: UInt8(ascii: "z"), count: 4096))
        #expect(extracted.copiedBytes() == payload)
    }

    @Test("Many regions parse in one pass, at any count")
    func manyRegions() throws {
        // The one-pass gather has no recursion, so this costs no stack no matter how many regions there
        // are — the case the recursive gather has to cap and coalesce. Each read is large enough to stay
        // its own region.
        let regionCount = 2000
        let reads = (0..<regionCount).map { Array(repeating: UInt8($0 % 251), count: IMAPBuffer.copyThreshold) }
        let bytes = reads.flatMap { $0 }
        var buffer = IMAPInputBuffer()
        for read in reads { buffer.append(read) }
        #expect(buffer.regionCount == regionCount)
        let parsed = try buffer.parse { try $0.extractBytes(length: bytes.count) }
        #expect(parsed == bytes)
        #expect(buffer.isEmpty)
    }
}

// MARK: - Coalescing small reads

extension IMAPInputBufferTests {
    @Test("Small reads share a tail until it is full")
    func smallReadsShareATail() {
        // A peer sending a byte per read must not cost a region, an object and a whole receive buffer per
        // byte: one-byte reads fill 1 KiB tails instead.
        let byteCount = 3000
        var buffer = IMAPInputBuffer()
        for index in 0..<byteCount { buffer.append([UInt8(ascii: "a") + UInt8(index % 26)]) }
        let tailCapacity = IMAPInputBuffer.minimumTailCapacity
        #expect(buffer.count == byteCount)
        #expect(buffer.regionCount == (byteCount + tailCapacity - 1) / tailCapacity)
        let expected = (0..<byteCount).map { UInt8(ascii: "a") + UInt8($0 % 26) }
        #expect(Array(Self.text(buffer).utf8) == expected)
    }

    @Test("A small read that does not fit the tail starts a new one")
    func smallReadOverflowsTheTail() {
        let size = IMAPBuffer.copyThreshold
        var buffer = Self.buffer([String(repeating: "a", count: size - 10), String(repeating: "b", count: 20)])
        #expect(buffer.regionCount == 2, "a read is never split across tails")
        buffer.append(Array("c".utf8))
        #expect(buffer.regionCount == 2, "the new tail takes later reads")
        #expect(Self.text(buffer) == String(repeating: "a", count: size - 10) + String(repeating: "b", count: 20) + "c")
    }

    @Test("A read at the copy threshold is retained, not copied")
    func readAtThresholdIsRetained() {
        let read = Array(Self.large("r").utf8)
        let appendedAt = read.withUnsafeBytes { UInt(bitPattern: $0.baseAddress) }
        var buffer = Self.buffer(["A001 "])
        buffer.append(read)
        #expect(buffer.regionCount == 2)
        #expect(Self.address(of: 1, in: buffer) == appendedAt)
        #expect(buffer.byteRegions[1].retainedRegion?.storage.wrappedRegion(as: [UInt8].self) == read)

        buffer.append(Array(" tail".utf8))
        #expect(buffer.regionCount == 3, "a small read after a retained one starts a new tail")
    }

    @Test("A tail's bytes keep their address as it fills")
    func tailNeverMoves() {
        // Writes go past the end into unused capacity; nothing already in the tail is moved.
        var buffer = Self.buffer(["x"])
        let before = Self.address(of: 0, in: buffer)
        for _ in 0..<(IMAPInputBuffer.minimumTailCapacity - 1) { buffer.append(Array("y".utf8)) }
        #expect(buffer.regionCount == 1)
        #expect(Self.address(of: 0, in: buffer) == before)
    }

    @Test("A payload extracted from a tail is unaffected by later appends into it")
    func payloadFromATailSurvivesAppends() throws {
        var buffer = Self.buffer(["A001 ", "LOGIN"])
        let tag = try buffer.parse { try $0.extractBuffer(upTo: 4) }
        buffer.append(Array(" user\r\n".utf8))
        #expect(buffer.regionCount == 1, "the append went into the same tail")
        #expect(tag.copiedBytes() == Array("A001".utf8))
        #expect(Self.text(buffer) == " LOGIN user\r\n")
    }

    @Test("A tail referenced outside the buffer is not written into again")
    func referencedTailIsNotWritten() {
        var buffer = Self.buffer(["abc"])
        let held = buffer.byteRegions[0]
        buffer.append(Array("def".utf8))
        #expect(held.copiedBytes() == Array("abc".utf8))
        #expect(buffer.regionCount == 2, "the held tail is left alone; a new one takes the read")
        #expect(Self.text(buffer) == "abcdef")
    }

    @Test("Copies of a buffer never write into each other's tail")
    func copiesHaveSeparateTails() {
        // The two copies share the tail. Writing into it from either would put bytes behind the other
        // copy's end that it may later write over.
        var original = Self.buffer(["abc"])
        var copy = original
        original.append(Array("def".utf8))
        copy.append(Array("XYZ".utf8))
        #expect(Self.text(original) == "abcdef")
        #expect(Self.text(copy) == "abcXYZ")
    }

    @Test("A partly consumed tail keeps taking reads")
    func partlyConsumedTail() throws {
        var buffer = Self.buffer(["abc", "def"])
        buffer.discardFirst(4)
        buffer.append(Array("gh".utf8))
        #expect(buffer.regionCount == 1)
        #expect(Self.text(buffer) == "efgh")
    }

    @Test("Parsing crosses tail, retained read and tail")
    func parseAcrossTailsAndRetainedReads() throws {
        let literal = Self.large("L") + Self.large("M")
        let pieces = ["* 1 FETCH ", "(BODY[] {\(literal.utf8.count)}\r\n", literal, ")", "\r\n"]
        var buffer = Self.buffer(pieces)
        #expect(buffer.regionCount == 3)
        let all = pieces.joined()
        let parsed = try buffer.parse { try $0.extractBytes(length: all.utf8.count) }
        #expect(String(decoding: parsed, as: UTF8.self) == all)
        #expect(buffer.isEmpty)
    }

    @Test("Parsing crosses from one tail into the next")
    func parseAcrossTails() throws {
        let first = String(repeating: "a", count: IMAPBuffer.copyThreshold - 24)
        let second = String(repeating: "b", count: 100)
        var buffer = Self.buffer([first, second])
        #expect(buffer.regionCount == 2)
        let parsed = try buffer.parse { try $0.extractBytes(length: first.utf8.count + second.utf8.count) }
        #expect(String(decoding: parsed, as: UTF8.self) == first + second)
    }

    @Test("The next small read continues a used-up tail rather than allocating")
    func usedUpTailIsContinued() {
        // A small read parsed in full, then the next one: the common case, which must not cost a new tail
        // per read.
        var buffer = Self.buffer(["abc"])
        let tailStart = Self.address(of: 0, in: buffer)
        buffer.discardFirst(3)
        #expect(buffer.regionCount == 0)
        buffer.append(Array("d".utf8))
        #expect(buffer.regionCount == 1)
        #expect(Self.address(of: 0, in: buffer) == tailStart + 3)
        #expect(Self.text(buffer) == "d")
    }

    @Test("Copies of a drained buffer never continue each other's tail")
    func copiesHaveSeparateSpareTails() {
        var original = Self.buffer(["abc"])
        original.discardFirst(3)
        var copy = original
        original.append(Array("x".utf8))
        copy.append(Array("y".utf8))
        #expect(Self.text(original) == "x")
        #expect(Self.text(copy) == "y")
    }

    @Test("A full used-up tail is not continued")
    func fullUsedUpTail() {
        let capacity = IMAPInputBuffer.minimumTailCapacity
        var buffer = Self.buffer([String(repeating: "a", count: capacity - 1), "a"])
        #expect(buffer.regionCount == 1)
        buffer.discardFirst(capacity)
        buffer.append(Array("z".utf8))
        #expect(buffer.regionCount == 1)
        #expect(Self.text(buffer) == "z")
    }
}

// MARK: - Address stability

extension IMAPInputBufferTests {
    /// Yields a fresh temporary copy on every call: a pointer from it must not outlive the call.
    private struct UnstableRegion: ByteRegion, Sendable {
        let bytes: [UInt8]
        func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
            var temporary = bytes
            return try temporary.withUnsafeMutableBytes { try body(UnsafeRawBufferPointer($0)) }
        }
    }

    /// The storage behind region `index`, which every large read is kept in.
    private static func storage(of index: Int, in buffer: IMAPInputBuffer) throws -> IMAPByteStorage {
        try #require(buffer.byteRegions[index].retainedRegion).storage
    }

    @Test("A large Data is copied: it may flatten into a temporary buffer")
    func largeDataIsCopied() throws {
        let data = Data(repeating: UInt8(ascii: "d"), count: 2 * IMAPBuffer.copyThreshold)
        var buffer = IMAPInputBuffer()
        buffer.append(data)
        let storage = try Self.storage(of: 0, in: buffer)
        #expect(storage.wrappedRegion(as: Data.self) == nil)
        #expect(storage.hasStableAddress)
        #expect(Self.address(of: 0, in: buffer) != data.withUnsafeBytes { UInt(bitPattern: $0.baseAddress) })
        #expect(buffer.byteRegions[0].copiedBytes() == Array(data))
    }

    @Test("A large region that yields temporary bytes is copied")
    func largeUnstableRegionIsCopied() throws {
        let bytes = Array(repeating: UInt8(ascii: "u"), count: IMAPBuffer.copyThreshold)
        var buffer = IMAPInputBuffer()
        buffer.append(UnstableRegion(bytes: bytes))
        let storage = try Self.storage(of: 0, in: buffer)
        #expect(storage.wrappedRegion(as: UnstableRegion.self) == nil)
        #expect(storage.hasStableAddress)
        #expect(buffer.byteRegions[0].copiedBytes() == bytes)
    }

    @Test("Large regions with a fixed address are retained, not copied")
    func largeStableRegionsAreRetained() throws {
        let wrapped = IMAPBuffer(Array(repeating: UInt8(ascii: "b"), count: IMAPBuffer.copyThreshold))

        var buffer = IMAPInputBuffer()
        buffer.append(wrapped)
        #expect(try Self.storage(of: 0, in: buffer).wrappedRegion(as: IMAPBuffer.self) != nil)
        #expect(Self.address(of: 0, in: buffer) == wrapped.withUnsafeBytes { UInt(bitPattern: $0.baseAddress) })
    }

    @Test("An IMAPBuffer over storage with no fixed address is copied")
    func imapBufferOverUnstableStorageIsCopied() throws {
        let bytes = Array(repeating: UInt8(ascii: "s"), count: IMAPBuffer.copyThreshold)
        var buffer = IMAPInputBuffer()
        buffer.append(IMAPBuffer(IMAPByteStorage(UnstableRegion(bytes: bytes))))
        #expect(try Self.storage(of: 0, in: buffer).wrappedRegion(as: IMAPBuffer.self) == nil)
        #expect(buffer.byteRegions[0].copiedBytes() == bytes)
    }

    @Test("A copied Data parses, and a large extraction refers to the copy")
    func parseFromCopiedData() throws {
        let header = "* 1 FETCH (BODY[] {2048}\r\n"
        let literal = Self.large("L") + Self.large("M")
        var buffer = IMAPInputBuffer()
        buffer.append(Data((header + literal).utf8))
        let copy = try Self.storage(of: 0, in: buffer)

        let parsed = try buffer.parse { input in
            (try input.extractBytes(length: header.utf8.count), try input.extractBuffer(upTo: literal.utf8.count))
        }
        #expect(String(decoding: parsed.0, as: UTF8.self) == header)
        #expect(String(decoding: parsed.1.copiedBytes(), as: UTF8.self) == literal)
        #expect(parsed.1.retainedRegion?.storage === copy)
        #expect(buffer.isEmpty)
    }

    @Test("A payload parsed from a DispatchData is donated, and the donation keeps the DispatchData alive")
    func parsedDispatchPayloadIsDonated() throws {
        let header = "* 1 FETCH (BODY[] {1024}\r\n"
        let literal = Array(Self.large("P").utf8)
        let queue = DispatchQueue(label: "IMAPInputBufferTests.deallocator")
        let deallocation = Deallocation()

        let converted: DispatchData
        let leaf: UInt
        do {
            // Header and literal as two regions; only the literal is large enough to be kept.
            // Only the deallocator touches `payload` once `DispatchData` owns it.
            nonisolated(unsafe) let payload = UnsafeMutableRawBufferPointer.allocate(
                byteCount: literal.count,
                alignment: 1
            )
            literal.withUnsafeBytes { payload.copyMemory(from: $0) }
            leaf = UInt(bitPattern: payload.baseAddress)
            var data = Array(header.utf8).withUnsafeBytes { DispatchData(bytes: $0) }
            data.append(
                DispatchData(
                    bytesNoCopy: UnsafeRawBufferPointer(payload),
                    deallocator: .custom(queue) {
                        payload.initializeMemory(as: UInt8.self, repeating: 0)
                        payload.deallocate()
                        deallocation.hasRun = true
                    }
                )
            )
            var buffer = IMAPInputBuffer()
            buffer.append(contentsOf: data)
            let parsed = try buffer.parse { input in
                _ = try input.extractBytes(length: header.utf8.count)
                return try input.extractBuffer(upTo: literal.count)
            }
            #expect(parsed.retainedRegion != nil, "precondition: extracted by reference")
            converted = parsed.makeDispatchData()
        }
        queue.sync {}

        #expect(queue.sync { deallocation.hasRun } == false)
        var addresses: [UInt] = []
        converted.enumerateBytes { bytes, _, _ in addresses.append(UInt(bitPattern: bytes.baseAddress)) }
        #expect(addresses == [leaf], "donated, not copied")
        #expect(Array(converted) == literal)
    }
}
