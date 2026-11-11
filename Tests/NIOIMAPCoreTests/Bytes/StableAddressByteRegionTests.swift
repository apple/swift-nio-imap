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

// Public API only — no `@testable`, no `@_spi`: this file is what a byte-buffer type outside the library
// can do, and must keep compiling as such.
import Dispatch
import NIOIMAPCore
import Testing

/// Memory a third-party buffer type allocated, written once and never moved.
private final class ForeignStorage: @unchecked Sendable {
    let bytes: UnsafeMutableRawBufferPointer

    init(repeating byte: UInt8, count: Int) {
        bytes = .allocate(byteCount: count, alignment: 1)
        bytes.initializeMemory(as: UInt8.self, repeating: byte)
    }

    deinit { bytes.deallocate() }
}

/// A third-party byte-buffer type that opts in to zero-copy hand-off through the public protocol.
private struct ForeignBuffer: StableAddressByteRegion, Sendable {
    let storage: ForeignStorage

    var baseAddress: UnsafeRawPointer? { UnsafeRawPointer(storage.bytes.baseAddress) }

    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try body(UnsafeRawBufferPointer(storage.bytes))
    }
}

/// A third-party region that makes no promise about its address, as one that decodes on demand would.
private struct UnstableBuffer: ByteRegion, Sendable {
    let bytes: [UInt8]

    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try bytes.withUnsafeBytes(body)
    }
}

/// A third-party sink that hands every byte out as a region of its own: the most regions a sink can.
private struct OneRegionPerByteSink: EncoderOutputBuffer {
    private var bytes: [UInt8] = []

    var byteCount: Int { bytes.count }

    mutating func append(_ bytes: UnsafeRawBufferPointer) {
        self.bytes.append(contentsOf: bytes)
    }

    mutating func append(_ region: IMAPBuffer) {
        region.withUnsafeBytes { bytes.append(contentsOf: $0) }
    }

    mutating func takeFirst(_ byteCount: Int) -> IMAPBufferList {
        let taken = bytes.prefix(byteCount).map { IMAPBuffer([$0]) }
        bytes.removeFirst(byteCount)
        return IMAPBufferList(taken)
    }

    func withPendingRegions<R>(_ body: (Span<IMAPBuffer>) -> R) -> R {
        let regions = ContiguousArray(bytes.map { IMAPBuffer([$0]) })
        return body(regions.span)
    }

    mutating func removeAll() {
        bytes = []
    }
}

/// Where `buffer`'s bytes are.
private func address(of buffer: IMAPBuffer) -> UnsafeRawPointer? {
    buffer.withUnsafeBytes { UnsafeRawPointer($0.baseAddress) }
}

/// Where `buffer` hands out its bytes in place, or `nil` if it declines to.
private func donatedAddress(of buffer: IMAPBuffer) -> UnsafeRawPointer? {
    buffer.withUnsafeBytesAndOwner { bytes, _ in UnsafeRawPointer(bytes.baseAddress) } ?? nil
}

/// Wraps `region` from generic code that knows only `ByteRegion`, which takes the init that checks at
/// run time.
private func wrapGenerically(_ region: some ByteRegion & Sendable) -> IMAPBuffer {
    IMAPBuffer(IMAPByteStorage(region))
}

/// Appends `region` from generic code that knows only `ByteRegion`, which takes the overload that checks
/// at run time.
private func appendGenerically(_ region: some ByteRegion & Sendable, to input: inout IMAPInputBuffer) {
    input.append(region)
}

@Suite("A third-party StableAddressByteRegion")
struct StableAddressByteRegionTests {
    /// Large enough to be kept by reference wherever the library has a size cut-off (1 KiB).
    static let byteCount = 4 * 1_024

    @Test("is donated to DispatchData, not copied")
    func dispatchDataDonates() {
        let foreign = ForeignBuffer(storage: ForeignStorage(repeating: UInt8(ascii: "f"), count: Self.byteCount))
        let data = IMAPBuffer(IMAPByteStorage(foreign)).makeDispatchData()
        var leaf: UnsafeRawPointer?
        data.enumerateBytes { bytes, _, _ in leaf = UnsafeRawPointer(bytes.baseAddress) }
        #expect(data.count == Self.byteCount)
        #expect(leaf == foreign.baseAddress)
    }

    @Test("is kept by IMAPInputBuffer, not copied")
    func inputBufferRetains() {
        let foreign = ForeignBuffer(storage: ForeignStorage(repeating: UInt8(ascii: "f"), count: Self.byteCount))
        var input = IMAPInputBuffer()
        input.append(foreign)
        #expect(input.count == Self.byteCount)
        #expect(input.byteRegions[0].withUnsafeBytes { UnsafeRawPointer($0.baseAddress) } == foreign.baseAddress)
    }

    @Test("is kept by IMAPInputBuffer through the generic append, and through an IMAPBuffer")
    func inputBufferRetainsThroughGenericAppend() {
        let foreign = ForeignBuffer(storage: ForeignStorage(repeating: UInt8(ascii: "f"), count: Self.byteCount))
        var input = IMAPInputBuffer()
        appendGenerically(foreign, to: &input)
        appendGenerically(IMAPBuffer(IMAPByteStorage(foreign)), to: &input)
        input.append(IMAPBuffer(IMAPByteStorage(foreign)))
        #expect(input.regionCount == 3)
        for region in input.byteRegions {
            #expect(address(of: region) == foreign.baseAddress)
        }
    }

    @Test("is kept by IMAPInputBuffer through an IMAPBuffer, where an unstable region is copied")
    func inputBufferAppendsIMAPBuffer() {
        let foreign = ForeignBuffer(storage: ForeignStorage(repeating: UInt8(ascii: "f"), count: Self.byteCount))
        let unstable = UnstableBuffer(bytes: Array(repeating: UInt8(ascii: "u"), count: Self.byteCount))
        var input = IMAPInputBuffer()
        input.append(IMAPBuffer(IMAPByteStorage(foreign)))
        input.append(IMAPBuffer(IMAPByteStorage(unstable)))

        #expect(input.regionCount == 2)
        #expect(address(of: input.byteRegions[0]) == foreign.baseAddress, "kept")
        let copy = input.byteRegions[1]
        #expect(address(of: copy) != unstable.bytes.withUnsafeBytes { UnsafeRawPointer($0.baseAddress) }, "copied")
        #expect(donatedAddress(of: copy) == address(of: copy), "the copy has a fixed address")
        #expect(copy.copiedBytes() == unstable.bytes)
    }

    @Test("carries its fixed address through an IMAPBuffer into IMAPByteStorage")
    func stableThroughWrappedBuffer() {
        let foreign = ForeignBuffer(storage: ForeignStorage(repeating: UInt8(ascii: "f"), count: Self.byteCount))
        let buffer = IMAPBuffer(IMAPByteStorage(foreign))
        #expect(donatedAddress(of: IMAPBuffer(IMAPByteStorage(buffer))) == foreign.baseAddress, "static")
        #expect(donatedAddress(of: wrapGenerically(buffer)) == foreign.baseAddress, "run time")

        let unstable = IMAPBuffer(IMAPByteStorage(UnstableBuffer(bytes: Array(repeating: 0, count: Self.byteCount))))
        #expect(donatedAddress(of: IMAPBuffer(IMAPByteStorage(unstable))) == nil, "static")
        #expect(donatedAddress(of: wrapGenerically(unstable)) == nil, "run time")
    }

    @Test("backingRegion recovers the region and range, without copying")
    func backingRegionRoundTrips() throws {
        let foreign = ForeignBuffer(storage: ForeignStorage(repeating: UInt8(ascii: "f"), count: Self.byteCount))
        let buffer = IMAPBuffer(IMAPByteStorage(foreign))

        let whole = try #require(buffer.backingRegion(as: ForeignBuffer.self))
        #expect(whole.region.storage === foreign.storage)
        #expect(whole.range == 0..<Self.byteCount)

        let slice = try #require(buffer.dropFirst(10).prefix(100).backingRegion(as: ForeignBuffer.self))
        #expect(slice.region.storage === foreign.storage)
        #expect(slice.range == 10..<110)
    }

    @Test("backingRegion is nil for bytes the library owns, and for another region type")
    func backingRegionDeclines() {
        let foreign = ForeignBuffer(storage: ForeignStorage(repeating: UInt8(ascii: "f"), count: Self.byteCount))
        let buffer = IMAPBuffer(IMAPByteStorage(foreign))
        #expect(buffer.backingRegion(as: [UInt8].self) == nil, "another type")
        #expect(buffer.copied().backingRegion(as: ForeignBuffer.self) == nil, "copied")
        #expect(IMAPBuffer([1, 2, 3]).backingRegion(as: [UInt8].self) == nil, "copied")

        var sink = IMAPOutputBuffer()
        _ = sink.append("A1 NOOP\r\n")
        let segment = sink.takeFirst(sink.byteCount).regions[0]
        #expect(segment.backingRegion(as: [UInt8].self) == nil, "written by the encoder")
    }

    @Test("withUnsafeBytesAndOwner hands out the bytes in place where their address is fixed")
    func withUnsafeBytesAndOwnerInPlace() {
        var sink = IMAPOutputBuffer()
        _ = sink.append("A1 NOOP\r\n")
        let segment = sink.takeFirst(sink.byteCount).regions[0]
        let donated = segment.withUnsafeBytesAndOwner { bytes, _ in UnsafeRawPointer(bytes.baseAddress) }
        #expect(donated == address(of: segment))

        let foreign = ForeignBuffer(storage: ForeignStorage(repeating: UInt8(ascii: "f"), count: Self.byteCount))
        let retained = IMAPBuffer(IMAPByteStorage(foreign)).dropFirst(10)
        #expect(
            retained.withUnsafeBytesAndOwner { bytes, _ in UnsafeRawPointer(bytes.baseAddress) }
                == foreign.baseAddress?.advanced(by: 10)
        )
    }

    @Test("withUnsafeBytesAndOwner declines a region without a fixed address")
    func withUnsafeBytesAndOwnerDeclines() {
        let unstable = IMAPBuffer(IMAPByteStorage(UnstableBuffer(bytes: Array(repeating: 0, count: Self.byteCount))))
        var called = false
        #expect(unstable.withUnsafeBytesAndOwner { _, _ in called = true } == nil)
        #expect(!called)
    }

    @Test("keeps its fixed address through either IMAPByteStorage init")
    func stableThroughEitherInit() {
        let foreign = ForeignBuffer(storage: ForeignStorage(repeating: UInt8(ascii: "f"), count: Self.byteCount))
        #expect(donatedAddress(of: IMAPBuffer(IMAPByteStorage(foreign))) == foreign.baseAddress, "static")
        #expect(donatedAddress(of: wrapGenerically(foreign)) == foreign.baseAddress, "run time")

        let bytes: [UInt8] = [1, 2, 3]
        let base = bytes.withUnsafeBytes { UnsafeRawPointer($0.baseAddress) }
        #expect(donatedAddress(of: IMAPBuffer(IMAPByteStorage(bytes))) == base, "static")
        #expect(donatedAddress(of: wrapGenerically(bytes)) == base, "run time")
        #expect(donatedAddress(of: IMAPBuffer(IMAPByteStorage(bytes[1...]))) == base?.advanced(by: 1))
        #expect(donatedAddress(of: IMAPBuffer(IMAPByteStorage(ContiguousArray(bytes)))) != nil)

        let unstable = UnstableBuffer(bytes: Array(repeating: 0, count: Self.byteCount))
        #expect(donatedAddress(of: wrapGenerically(unstable)) == nil)
    }

    /// The most regions the encoder hands out in one chunk. Internal to the library, so spelled here.
    static let encoderRegionCap = 64

    @Test("the encoder caps the regions a sink of your own hands it")
    func encoderCapsForeignSink() {
        var encoder = ResponseEncodeBuffer(
            sink: OneRegionPerByteSink(),
            options: ResponseEncodingOptions(),
            loggingMode: false
        )
        let text = String(repeating: "x", count: 1_000)
        encoder.writeContinuationRequest(.responseText(ResponseText(text: text)))
        let bytes = encoder.readBytes()
        #expect(bytes.regionCount == Self.encoderRegionCap)
        #expect(bytes.copiedBytes() == Array("+ \(text)\r\n".utf8))
    }
}
