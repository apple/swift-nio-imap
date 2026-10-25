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

// MARK: - Test support

/// An external observer of a ``TrackedRegion``'s lifetime, so that a test can assert an owner was —
/// or was not — released. One per test, so tests running in parallel cannot interfere.
final class Liveness: @unchecked Sendable {
    var deinitCount = 0
}

/// A `ByteRegion` that reports its own destruction.
final class TrackedRegion: ByteRegion, @unchecked Sendable {
    private let bytes: [UInt8]
    private let liveness: Liveness

    init(_ bytes: [UInt8], _ liveness: Liveness) {
        self.bytes = bytes
        self.liveness = liveness
    }

    deinit {
        liveness.deinitCount += 1
    }

    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try bytes.withUnsafeBytes(body)
    }
}

func imapBuffer(_ string: String) -> IMAPBuffer {
    IMAPBuffer(Array(string.utf8))
}

func string(_ buffer: IMAPBuffer) -> String {
    String(decoding: buffer.copiedBytes(), as: UTF8.self)
}

// MARK: - IMAPByteStorage

@Suite("IMAPByteStorage")
struct IMAPByteStorageTests {
    @Test("count is taken from the wrapped region")
    func count() {
        #expect(IMAPByteStorage([1, 2, 3, 4, 5] as [UInt8]).count == 5)
        #expect(IMAPByteStorage([] as [UInt8]).count == 0)
    }

    @Test("withUnsafeBytes yields the wrapped bytes")
    func withUnsafeBytes() {
        let storage = IMAPByteStorage([9, 8, 7] as [UInt8])
        #expect(storage.withUnsafeBytes { Array($0) } == [9, 8, 7])
    }

    @Test("wrappedRegion recovers the backing type, and only that type")
    func wrappedRegion() {
        let storage = IMAPByteStorage([1, 2, 3] as [UInt8])
        #expect(storage.wrappedRegion(as: [UInt8].self) == [1, 2, 3])
        #expect(storage.wrappedRegion(as: ContiguousArray<UInt8>.self) == nil)
    }

    @Test("the wrapped region stays alive")
    func retainsTheRegion() {
        let liveness = Liveness()
        func make() -> IMAPByteStorage { IMAPByteStorage(TrackedRegion([1, 2, 3], liveness)) }

        let storage = make()
        #expect(liveness.deinitCount == 0)
        #expect(storage.count == 3)
    }
}

// MARK: - IMAPBuffer

@Suite("IMAPBuffer")
struct IMAPBufferTests {
    @Test("an empty buffer has no bytes")
    func empty() {
        let buffer = IMAPBuffer()
        #expect(buffer.count == 0)
        #expect(buffer.isEmpty)
        #expect(buffer.copiedBytes() == [])
    }

    @Test("a buffer over owned bytes")
    func copiedRepresentation() {
        let buffer = IMAPBuffer([1, 2, 3, 4] as [UInt8])
        #expect(buffer.count == 4)
        #expect(!buffer.isEmpty)
        #expect(buffer.copiedBytes() == [1, 2, 3, 4])
        #expect(buffer.withUnsafeBytes { Array($0) } == [1, 2, 3, 4])
        #expect(buffer.retainedRegion == nil)
    }

    @Test("a buffer over a whole borrowed region")
    func retainedWholeRegion() {
        let storage = IMAPByteStorage([1, 2, 3, 4] as [UInt8])
        let buffer = IMAPBuffer(storage)
        #expect(buffer.count == 4)
        #expect(buffer.copiedBytes() == [1, 2, 3, 4])
        #expect(buffer.retainedRegion?.range == 0..<4)
    }

    @Test("a buffer over a sub-range of a borrowed region exposes only that sub-range")
    func retainedSubRange() {
        let storage = IMAPByteStorage(Array("A003 LOGOUT\r\nHELLOWORLD".utf8))
        let buffer = IMAPBuffer(storage, 13..<23)
        #expect(buffer.count == 10)
        #expect(string(buffer) == "HELLOWORLD")
        #expect(buffer.withUnsafeBytes { Array($0) } == Array("HELLOWORLD".utf8))
    }

    @Test("a borrowed buffer keeps its owner alive")
    func retainsTheOwner() {
        let liveness = Liveness()
        func make() -> IMAPBuffer {
            IMAPBuffer(IMAPByteStorage(TrackedRegion([1, 2, 3, 4], liveness)), 1..<3)
        }

        let buffer = make()
        #expect(liveness.deinitCount == 0)
        #expect(buffer.copiedBytes() == [2, 3])
    }

    @Test("copied releases the pin but keeps the bytes")
    func copiedReleasesThePin() {
        let liveness = Liveness()
        func make() -> IMAPBuffer {
            IMAPBuffer(IMAPByteStorage(TrackedRegion([1, 2, 3, 4], liveness)), 1..<3).copied()
        }

        let buffer = make()
        #expect(liveness.deinitCount == 1)
        #expect(buffer.copiedBytes() == [2, 3])
        #expect(buffer.retainedRegion == nil)
    }

    @Test("copied is a no-op for a buffer that already owns exactly its bytes")
    func copiedIsANoOpWhenOwned() {
        let buffer = IMAPBuffer([1, 2, 3] as [UInt8])
        #expect(buffer.copied() == buffer)
        #expect(buffer.copied().retainedRegion == nil)
    }

    @Test("dropFirst is range arithmetic on both representations")
    func dropFirst() {
        let owned = imapBuffer("hello world")
        let borrowed = IMAPBuffer(IMAPByteStorage(Array("hello world".utf8)))

        for buffer in [owned, borrowed] {
            #expect(string(buffer.dropFirst(6)) == "world")
            #expect(string(buffer.dropFirst()) == "ello world")
            #expect(string(buffer.dropFirst(6).dropFirst(2)) == "rld")
            #expect(buffer.dropFirst(6).count == 5)
        }
    }

    @Test("dropFirst clamps rather than trapping")
    func dropFirstClamps() {
        let buffer = imapBuffer("abc")
        #expect(buffer.dropFirst(0) == buffer)
        #expect(buffer.dropFirst(-5) == buffer)
        #expect(buffer.dropFirst(3).isEmpty)
        #expect(buffer.dropFirst(99).isEmpty)
    }

    @Test("dropFirst on a borrowed buffer still borrows")
    func dropFirstKeepsBorrowing() {
        let storage = IMAPByteStorage(Array("hello world".utf8))
        let dropped = IMAPBuffer(storage).dropFirst(6)
        #expect(dropped.retainedRegion?.range == 6..<11)
    }

    @Test("equality and hashing are byte-wise, not representation-wise")
    func crossRepresentationEquality() {
        let owned = imapBuffer("HELLOWORLD")
        // The same bytes, borrowed, and sitting in the middle of a larger region.
        let storage = IMAPByteStorage(Array("A003 LOGOUT\r\nHELLOWORLD".utf8))
        let borrowed = IMAPBuffer(storage, 13..<23)
        // And the same bytes again as a sub-range of an owned array.
        let ownedSubRange = imapBuffer("xxHELLOWORLD").dropFirst(2)

        #expect(owned == borrowed)
        #expect(borrowed == ownedSubRange)
        #expect(owned == ownedSubRange)
        #expect(owned.hashValue == borrowed.hashValue)
        #expect(owned.hashValue == ownedSubRange.hashValue)
        #expect(Set([owned, borrowed, ownedSubRange]).count == 1)
    }

    @Test("buffers of different bytes are not equal")
    func inequality() {
        #expect(imapBuffer("abc") != imapBuffer("abd"))
        #expect(imapBuffer("abc") != imapBuffer("ab"))
        #expect(imapBuffer("") != imapBuffer("a"))
        #expect(imapBuffer("") == IMAPBuffer())
    }

    @Test("string and array literals")
    func literals() {
        let fromString: IMAPBuffer = "hello"
        let fromArray: IMAPBuffer = [0x68, 0x65, 0x6C, 0x6C, 0x6F]
        #expect(fromString == fromArray)
        #expect(string(fromString) == "hello")

        let unicode: IMAPBuffer = "räksmörgås"
        #expect(unicode.copiedBytes() == Array("räksmörgås".utf8))
    }

    @Test("an IMAPBuffer is itself a ByteRegion")
    func isAByteRegion() {
        let region: any ByteRegion = imapBuffer("abc")
        #expect(region.withUnsafeBytes { Array($0) } == Array("abc".utf8))

        // Which means it can be wrapped as storage, without copying the bytes out first.
        let storage = IMAPByteStorage(imapBuffer("abc"))
        #expect(storage.count == 3)
    }

    @Test("debugDescription reports the count and the leading bytes")
    func debugDescriptions() {
        #expect(IMAPBuffer([0x00, 0x0F, 0xFF] as [UInt8]).debugDescription == "IMAPBuffer(3 bytes: 00 0f ff)")
        #expect(IMAPBuffer().debugDescription == "IMAPBuffer(0 bytes: )")
        #expect(IMAPBuffer([UInt8](repeating: 0xAB, count: 20)).debugDescription.hasSuffix("…)"))
    }
}
