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

import Dispatch
import Testing

@testable import NIOIMAPCore

/// A region that says how much it pins, as one sliced out of a larger allocation would.
private struct PinnedRegion: StableAddressByteRegion, Sendable {
    let bytes: [UInt8]
    let pinnedByteCount: Int

    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try bytes.withUnsafeBytes(body)
    }
}

/// Appends `region` from generic code that knows only `ByteRegion`.
private func appendGenerically(_ region: some ByteRegion & Sendable, to input: inout IMAPInputBuffer) {
    input.append(region)
}

/// Wraps `region` from generic code that knows only `ByteRegion`.
private func wrapGenerically(_ region: some ByteRegion & Sendable) -> IMAPByteStorage {
    IMAPByteStorage(region)
}

/// One FETCH response carrying a literal of `byteCount` bytes, padded past its end to at least
/// ``IMAPBuffer/copyThreshold`` bytes, so ``IMAPInputBuffer`` keeps it rather than copying it to the tail.
private func fetchResponse(literalByteCount byteCount: Int) -> [UInt8] {
    var bytes = Array("* 1 FETCH (RFC822.TEXT {\(byteCount)}\r\n".utf8)
    bytes += Array(repeating: UInt8(ascii: "x"), count: byteCount)
    bytes += Array(")\r\n".utf8)
    // Never parsed: the tests stop at the literal.
    bytes += Array(repeating: UInt8(ascii: "z"), count: Swift.max(0, IMAPBuffer.copyThreshold - bytes.count))
    return bytes
}

/// Parses `input` up to the first literal and returns it, in one piece.
private func firstLiteral(in input: inout IMAPInputBuffer) throws -> IMAPBuffer {
    var parser = ResponseParser()
    while true {
        guard case .response(.fetch(.streamingBytes(let bytes))) = try parser.parseResponseStream(buffer: &input)
        else { continue }
        return bytes
    }
}

/// The literal parsed out of a single read that pins `pinnedByteCount` bytes.
private func literal(
    byteCount: Int,
    pinnedByteCount: Int,
    path: LiteralRetentionTests.AppendPath = .stable
) throws -> IMAPBuffer {
    let region = PinnedRegion(bytes: fetchResponse(literalByteCount: byteCount), pinnedByteCount: pinnedByteCount)
    var input = IMAPInputBuffer()
    switch path {
    case .stable: input.append(region)
    case .generic: appendGenerically(region, to: &input)
    }
    let payload = try firstLiteral(in: &input)
    #expect(payload.count == byteCount)
    return payload
}

@Suite("Literal retention")
struct LiteralRetentionTests {
    /// How a test hands a region to ``IMAPInputBuffer``.
    enum AppendPath: Sendable {
        /// The overload for a type known to be a ``StableAddressByteRegion``.
        case stable
        /// The overload for any ``ByteRegion``, which casts at run time.
        case generic
    }

    static let minimum = IMAPBuffer.minimumRetainedLiteralByteCount
    static let factor = IMAPBuffer.retainedLiteralMaximumPinnedFactor

    @Test("the rule: at least the minimum, and at least a third of what is pinned")
    func rule() {
        #expect(!IMAPBuffer.retainsLiteral(byteCount: Self.minimum - 1, pinnedByteCount: Self.minimum - 1))
        #expect(IMAPBuffer.retainsLiteral(byteCount: Self.minimum, pinnedByteCount: Self.minimum))
        #expect(IMAPBuffer.retainsLiteral(byteCount: 1_024, pinnedByteCount: 1_024 * Self.factor))
        #expect(!IMAPBuffer.retainsLiteral(byteCount: 1_024, pinnedByteCount: 1_024 * Self.factor + 1))
        #expect(IMAPBuffer.retainsLiteral(byteCount: .max, pinnedByteCount: .max), "no overflow trap")
    }

    @Test(
        "a literal one byte under the minimum is copied, at the minimum it is kept",
        arguments: [AppendPath.stable, .generic]
    )
    func minimumBoundary(path: AppendPath) throws {
        let pinned = fetchResponse(literalByteCount: Self.minimum).count
        #expect(try literal(byteCount: Self.minimum - 1, pinnedByteCount: pinned, path: path).retainedRegion == nil)
        #expect(try literal(byteCount: Self.minimum, pinnedByteCount: pinned, path: path).retainedRegion != nil)
    }

    @Test(
        "a literal of exactly a third of what is pinned is kept, of just under a third copied",
        arguments: [AppendPath.stable, .generic]
    )
    func shareBoundary(path: AppendPath) throws {
        let byteCount = 1_024
        let kept = try literal(byteCount: byteCount, pinnedByteCount: byteCount * Self.factor, path: path)
        #expect(kept.retainedRegion != nil)
        let copied = try literal(byteCount: byteCount, pinnedByteCount: byteCount * Self.factor + 1, path: path)
        #expect(copied.retainedRegion == nil)
    }

    @Test("IMAPByteStorage takes pinnedByteCount from the region, through either init and an IMAPBuffer")
    func storageCapturesPinnedByteCount() {
        let region = PinnedRegion(bytes: [1, 2, 3], pinnedByteCount: 4_096)
        #expect(IMAPByteStorage(region).pinnedByteCount == 4_096, "static")
        #expect(wrapGenerically(region).pinnedByteCount == 4_096, "run time")
        let wrapped = IMAPBuffer(IMAPByteStorage(region))
        #expect(IMAPByteStorage(wrapped).pinnedByteCount == 4_096, "static")
        #expect(wrapGenerically(wrapped).pinnedByteCount == 4_096, "run time")

        var bytes: [UInt8] = [1, 2, 3]
        bytes.reserveCapacity(4_096)
        #expect(IMAPByteStorage(IMAPBuffer(bytes)).pinnedByteCount == bytes.capacity, "a copied IMAPBuffer")

        // Never less than the bytes themselves, whatever the region claims.
        #expect(IMAPByteStorage(PinnedRegion(bytes: [1, 2, 3], pinnedByteCount: 0)).pinnedByteCount == 3)
    }

    @Test("a DispatchData literal covering most of the data is kept, a small share of it copied")
    func dispatchData() throws {
        /// The literal parsed out of one `DispatchData`: a region holding the response, then
        /// `trailing` more bytes as a second region.
        func literal(byteCount: Int, followedBy trailing: Int) throws -> IMAPBuffer {
            var data = DispatchData.empty
            for part in [fetchResponse(literalByteCount: byteCount), Array(repeating: 0, count: trailing)] {
                part.withUnsafeBytes { data.append(DispatchData(bytes: $0)) }
            }
            var input = IMAPInputBuffer()
            input.append(contentsOf: data)
            return try firstLiteral(in: &input)
        }
        #expect(try literal(byteCount: 4_000, followedBy: 100).retainedRegion != nil)
        // The literal's region is small, but holding it holds all of the data.
        #expect(try literal(byteCount: 1_024, followedBy: 8 * 1_024).retainedRegion == nil)
    }
}
