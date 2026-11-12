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

// The Foundation half of the input seam, kept in one file so that the rest of `NIOIMAPCore` — the
// parser, the encoder, the model — needs no `import Foundation`. `ByteRegion`'s single requirement is
// spelled the same way as `ContiguousBytes`', so most of what follows is an empty extension.

import Dispatch
import Foundation

extension Data: ByteRegion {}
extension DispatchData.Region: ByteRegion {}

// Not a `StableAddressByteRegion`: a `DispatchData.Region` points into its `DispatchData` without
// keeping it alive, so its bytes are valid only while that `DispatchData` is. `IMAPInputBuffer.append(_:)`
// therefore copies a large one; `append(contentsOf:)` keeps the whole `DispatchData` instead.

// `Data` presents as one region even when the storage behind it is not contiguous: `withUnsafeBytes`
// flattens in that case, and nothing promises the flattened bytes outlive the call. So `Data` is not
// a `StableAddressByteRegion`, and `IMAPInputBuffer` copies a large one rather than keeping it. This
// is the "parse all of this" source, and it is read-only — trimming a `Data` moves its remaining
// bytes down, which is the cost `ConsumableParserInputBuffer` exists to keep out of connection code.
extension Data: ParserInputBuffer {
    public var byteRegions: CollectionOfOne<Data> { CollectionOfOne(self) }
}

// `DispatchData` is the genuinely multi-region source: concatenating two of them copies nothing, so a
// buffer assembled from many reads really does arrive as many regions. It takes the one-pass gather,
// which is why an arbitrary region count costs it no stack.
extension DispatchData: ParserInputBuffer {
    public var byteRegions: [DispatchData.Region] { regions }

    /// The number of regions, counted without materialising them.
    ///
    /// `regions` allocates an array; `enumerateBytes` walks the same regions and allocates nothing.
    /// The gather only ever needs the number, so this is the cheaper way to answer.
    public var regionCount: Int {
        var count = 0
        enumerateBytes { _, _, _ in count += 1 }
        return count
    }

    public func withParseInput<R>(limit: Int, _ body: (inout ParseInput) throws -> R) rethrows -> R {
        try _stableWithParseInput(limit: limit, body)
    }
}

extension DispatchData: ConsumableParserInputBuffer {
    /// Discards the first `k` bytes.
    ///
    /// `subdata(in:)` is `dispatch_data_create_subrange`, which copies nothing.
    ///
    /// - Parameter k: How many bytes to discard.
    public mutating func discardFirst(_ k: Int) {
        self = subdata(in: k..<count)
    }
}

extension DispatchData: StableRegionParserInputBuffer {
    /// Pushes every region in one pass.
    ///
    /// Sound because a `dispatch_data_t` is immutable and `self` is borrowed for as long as the cursor
    /// lives, so the leaf buffers `enumerateBytes` reports stay where they are.
    ///
    /// No owner is passed. Vouching for a region here would mean boxing it for every region on every
    /// parse, whereas ``IMAPInputBuffer`` boxes at most once per *append* — which is why that, and not
    /// this, is the type that makes large payloads copy-free.
    public borrowing func withStableRegions(into sink: inout RegionSink) {
        enumerateBytes { buffer, _, _ in sink.append(buffer, owner: nil, offset: 0) }
    }
}

extension IMAPInputBuffer {
    /// Adds every region of `data` to the end of the buffer, in order.
    ///
    /// A region of at least ``IMAPBuffer/copyThreshold`` bytes is kept where it is, along with `data`,
    /// which keeps it alive; a smaller one is copied into the tail. The regions are walked with
    /// `enumerateBytes`, which allocates nothing, so a read costs one small object per kept region and
    /// nothing else. Prefer this to appending each of `data.regions`: that builds an array, and copies
    /// every large region, since a `DispatchData.Region` does not keep its bytes alive.
    ///
    /// Appending an empty `DispatchData` does nothing.
    ///
    /// - Parameter data: The bytes to add.
    public mutating func append(contentsOf data: DispatchData) {
        data.enumerateBytes { bytes, _, _ in
            let bytes = UnsafeRawBufferPointer(bytes)
            guard bytes.count >= IMAPBuffer.copyThreshold else {
                appendToTail(bytes)
                return
            }
            appendReceived(IMAPByteStorage(DispatchDataRegion(data: data, bytes: bytes)))
        }
    }
}

/// One region of a `DispatchData`, kept alive by holding the whole `DispatchData`.
///
/// A `dispatch_data_t` is immutable and keeps its leaf buffers alive, so `bytes` stays put for as long
/// as `data` does. Holding all of `data` costs a retain rather than the allocation that
/// `subdata(in:)` may make, and pins all of `data` — usually one read — while the region is alive.
private struct DispatchDataRegion: StableAddressByteRegion, @unchecked Sendable {  // @unchecked: `bytes` is in `data`.
    let data: DispatchData
    let bytes: UnsafeRawBufferPointer

    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try body(bytes)
    }
}
