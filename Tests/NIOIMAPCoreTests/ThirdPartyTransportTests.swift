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

// Public API only — no `@testable`, no `@_spi`: this file is what a client with its own transport can
// do, and must keep compiling as such.
import NIOIMAPCore
import Testing

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

/// Memory a third-party buffer type allocated, written once and never moved.
private final class ForeignStorage: @unchecked Sendable {
    let bytes: UnsafeMutableRawBufferPointer

    init(repeating byte: UInt8, count: Int) {
        bytes = .allocate(byteCount: count, alignment: 1)
        bytes.initializeMemory(as: UInt8.self, repeating: byte)
    }

    deinit { bytes.deallocate() }
}

/// A third-party byte-buffer type, e.g. a message read from disk, that opts in to zero-copy hand-off.
private struct ForeignBuffer: StableAddressByteRegion, Sendable {
    let storage: ForeignStorage

    var baseAddress: UnsafeRawPointer? { UnsafeRawPointer(storage.bytes.baseAddress) }

    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try body(UnsafeRawBufferPointer(storage.bytes))
    }
}

/// A third-party sink that keeps a region of at least ``IMAPBuffer/copyThreshold`` by reference and
/// copies everything else.
private struct ReferenceKeepingSink: EncoderOutputBuffer {
    private var regions: [IMAPBuffer] = []
    private(set) var byteCount = 0

    mutating func append(_ bytes: UnsafeRawBufferPointer) {
        regions.append(IMAPBuffer(Array(bytes)))
        byteCount += bytes.count
    }

    mutating func append(_ region: IMAPBuffer) {
        guard region.count >= IMAPBuffer.copyThreshold else {
            region.withUnsafeBytes { append($0) }
            return
        }
        regions.append(region)
        byteCount += region.count
    }

    mutating func takeFirst(_ byteCount: Int) -> IMAPBufferList {
        var taken: [IMAPBuffer] = []
        var remaining = byteCount
        while remaining > 0 {
            let first = regions[0]
            guard first.count <= remaining else {
                taken.append(first.prefix(remaining))
                regions[0] = first.dropFirst(remaining)
                break
            }
            taken.append(regions.removeFirst())
            remaining -= first.count
        }
        self.byteCount -= byteCount
        return IMAPBufferList(taken)
    }

    func withPendingRegions<R>(_ body: (Span<IMAPBuffer>) -> R) -> R {
        body(ContiguousArray(regions).span)
    }

    mutating func removeAll() {
        regions = []
        byteCount = 0
    }
}

/// Drains `encoder` the way a client with its own transport does.
private func drain(_ encoder: inout CommandEncodeBuffer) -> [(wire: String, nextStep: CommandEncodeBuffer.NextStep)] {
    var chunks: [(wire: String, nextStep: CommandEncodeBuffer.NextStep)] = []
    while let chunk = encoder.nextChunk() {
        chunks.append((String(decoding: chunk.bytes.copiedBytes(), as: UTF8.self), chunk.nextStep))
    }
    return chunks
}

/// Command chunks for a client that writes to the network itself, e.g. over `Network.framework`.
@Suite("CommandEncodeBuffer chunks for a third-party transport")
struct ThirdPartyTransportTests {
    /// An 8-bit username can't be quoted, so it is a literal.
    static let login = TaggedCommand(tag: "A1", command: .login(username: "å", password: "pass"))

    /// The most regions the encoder hands out in one chunk. Internal to the library, so spelled here.
    static let encoderRegionCap = 64

    @Test("a synchronizing literal ends a chunk that awaits +")
    func synchronizingLiteral() {
        var encoder = CommandEncodeBuffer(options: .rfc3501, loggingMode: false)
        encoder.writeCommand(Self.login)
        let chunks = drain(&encoder)
        #expect(chunks.map(\.wire) == ["A1 LOGIN {2}\r\n", "å \"pass\"\r\n"])
        #expect(chunks.map(\.nextStep) == [.awaitContinuationRequest, .proceed])
        #expect(encoder.nextChunk() == nil)
    }

    @Test("a LITERAL+ literal doesn't end a chunk")
    func literalPlus() {
        var encoder = CommandEncodeBuffer(capabilities: [.literalPlus], loggingMode: false)
        encoder.writeCommand(Self.login)
        let chunks = drain(&encoder)
        #expect(chunks.map(\.wire) == ["A1 LOGIN {2+}\r\nå \"pass\"\r\n"])
        #expect(chunks.map(\.nextStep) == [.proceed])
    }

    /// The chunk ends at the last byte written, yet the message bytes, once written, follow the `+`.
    @Test("APPEND's message literal header awaits +")
    func appendBeginMessage() {
        var encoder = CommandEncodeBuffer(options: .rfc3501, loggingMode: false)
        encoder.writeCommandStream(.append(.beginMessage(message: .init(options: .none, data: .init(byteCount: 5)))))
        let chunks = drain(&encoder)
        #expect(chunks.map(\.wire) == [" {5}\r\n"])
        #expect(chunks.map(\.nextStep) == [.awaitContinuationRequest])
    }

    @Test("CATENATE's data literal header awaits + without LITERAL+")
    func catenateDataBegin() {
        var encoder = CommandEncodeBuffer(options: .rfc3501, loggingMode: false)
        encoder.writeCommandStream(.append(.catenateData(.begin(size: 5))))
        let chunks = drain(&encoder)
        #expect(chunks.map(\.wire) == ["TEXT {5}\r\n"])
        #expect(chunks.map(\.nextStep) == [.awaitContinuationRequest])
    }

    @Test("an empty encoder has no chunk")
    func emptyEncoder() {
        var encoder = CommandEncodeBuffer(options: .rfc3501, loggingMode: false)
        #expect(encoder.nextChunk() == nil)
    }

    @Test("a sink of your own keeps a large APPEND payload by reference through the encoder")
    func foreignSinkKeepsPayload() throws {
        let byteCount = IMAPBuffer.copyThreshold
        let foreign = ForeignBuffer(storage: ForeignStorage(repeating: UInt8(ascii: "f"), count: byteCount))
        var encoder = CommandEncodeBuffer(sink: ReferenceKeepingSink(), options: .rfc3501, loggingMode: false)
        encoder.writeCommandStream(.append(.messageBytes(IMAPBuffer(IMAPByteStorage(foreign)))))

        let next = encoder.nextChunk()
        let chunk = try #require(next)
        #expect(chunk.nextStep == .proceed)
        let payload = try #require(chunk.bytes.regions.first)
        #expect(chunk.bytes.regionCount == 1)
        #expect(payload.backingRegion(as: ForeignBuffer.self)?.region.storage === foreign.storage)
        let address = payload.withUnsafeBytesAndOwner { bytes, _ in UnsafeRawPointer(bytes.baseAddress) }
        #expect(address == foreign.baseAddress)
        #expect(encoder.nextChunk() == nil)
    }

    @Test("the encoder caps the regions a sink of your own hands it")
    func encoderCapsForeignSink() throws {
        var encoder = CommandEncodeBuffer(sink: OneRegionPerByteSink(), options: .rfc3501, loggingMode: false)
        let mailbox = String(repeating: "x", count: Self.encoderRegionCap)
        encoder.writeCommand(TaggedCommand(tag: "A1", command: .create(MailboxName(Array(mailbox.utf8)), [])))
        let next = encoder.nextChunk()
        let chunk = try #require(next)
        #expect(chunk.bytes.regionCount == Self.encoderRegionCap)
        #expect(chunk.bytes.copiedBytes() == Array("A1 CREATE \"\(mailbox)\"\r\n".utf8))
        #expect(chunk.nextStep == .proceed)
    }
}
